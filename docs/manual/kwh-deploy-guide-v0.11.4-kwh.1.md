# Production Deployment Guide — `v0.11.4-kwh.1`

이 가이드는 프로덕션 배포 에이전트가 실행하는 릴리스별 명령 소스다. 정상 상태에서는
`Deploy approved production release` workflow(`.github/workflows/deploy-approved-production-release.yaml`)가
§4~§6을 자동 수행하며, 이 문서는 그 입력값·기대 결과·제한을 규정한다.
공통 절차·수동 fallback 명령은 [`kwh-deploy-guide-v0.11.3-kwh.1.md`](./kwh-deploy-guide-v0.11.3-kwh.1.md)와 같고, 이 문서는 **이번 릴리스에서 달라지는 점만** 적는다.

> **상태:** 최종 태그·GHCR 빌드·최종 게이트 값이 채워진 최종본이다. 배포 Issue 번호만 Issue 생성 후 dispatch 입력으로 전달한다. 승인 시각·Environment 승인은 별도이며 이 문서가 대신하지 않는다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) → [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) → [릴리스 루틴](./kwh-release-routine.md) → 이 가이드. 충돌 시 앞선 문서가 이긴다. 시작 시 [핸드오프 문서](./kwh-release-handoff-v0.11.4-kwh.1.md)의 재판정 조건을 먼저 읽는다.

---

## 1. Release identifiers

| 항목                            | 값                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------- |
| Version                         | **v0.11.4-kwh.1**                                                               |
| Main tip SHA (태그 대상, 40자)  | `e901f7724f1cd2a6031b7671c83f9c891ece6d6a`                                      |
| GHCR image tag (배포 대상)      | `ghcr.io/kwh8121/openwebui-service:v0.11.4-kwh.1`                               |
| OCI index digest                | `sha256:23de12d4ad185aa77df07efadebd71f181015b9c3b13b9c072d50b2ede8b2639`       |
| linux/amd64 digest              | `sha256:403d48800d472a4ac74147ac7a14b3c2e87e741f0c288c2d73159cc2abafa222`       |
| GHCR short-SHA parity tag       | `ghcr.io/kwh8121/openwebui-service:git-e901f77`                                 |
| GH Actions build Run            | https://github.com/kwh8121/openwebui-service/actions/runs/37579260460           |
| RC (참고용, 배포 대상 아님)     | `v0.11.4-kwh.1-rc.1` @ `5f3ede34c` — build run 37413977492                      |
| Base upstream                   | Open WebUI `v0.11.4` (`8bd8b4fac`, 2026-09-21), `v0.11.3`에서 327 커밋·424 파일 |
| Fork carryovers                 | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `insertSuggestionPrompt=true` |
| Rollback target (현재 프로덕션) | `ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1` (실제 값은 §3.3에서 재확인)   |

`latest`·`main`·RC 태그를 배포하지 않는다. immutable 최종 태그 또는 git-SHA parity 태그만 유효하다.

---

## 2. Deployment overview

**변경 내용:** `v0.11.3-kwh.1` → `v0.11.4-kwh.1`. upstream `v0.11.4` 흡수. 충돌 0건, fork 커스터마이징 8항목 보존 확인 — 상세는 [`docs/plan/v0.11.4-integration.md`](../plan/v0.11.4-integration.md).

### 실행될 Alembic 마이그레이션: **0건 (no-op)**

`git diff v0.11.3 v0.11.4 -- backend/open_webui/migrations/versions/` 출력이 비어 있다. 프로덕션 revision `d4c1a8e37b62`는 이번 이미지의 head와 같다. 기동 로그에 `Running upgrade`가 **나오면 이 가이드의 전제가 깨진 것**이므로 즉시 중단하고 에스컬레이션한다. 스키마 변경이 없으므로 기본 복구 경로는 이미지 롤백이다(§8).

### 브레이킹 변경 — `langchain-community` 제거

upstream이 `langchain-community`를 의존성에서 제거했다. fork 소유 코드에 참조는 0건이다. **프로덕션 워크스페이스의 Tool/Function이 `langchain_community`를 import하면 배포 후 로드 실패할 수 있다.** 로컬 DB에는 Tool·Function이 0개라 로컬 게이트는 이를 검증하지 못했다(`UNKNOWN`).

- 사전조건: 배포 전 프로덕션 관리자 UI(Workspace → Tools/Functions)에서 `langchain_community` import 사용 여부를 확인하고 Issue에 결과를 남긴다. 운영 DB를 읽는 방식으로 하지 않는다.
- 사용하는 Tool/Function이 있으면 배포하지 않고 소유자 결정을 받는다.
- 배포 후 §7.4에서 Tool/Function 로드 오류가 없는지 확인한다.

### 그 밖의 upstream 변경 요지

- 폰트 11개·`pdf-style.css` 삭제: upstream이 "아무도 로드하지 않았다"고 밝힌 자산. 영향 없음.
- 새 `Dockerfile`(`USE_SLIM`, `uv`): fork 빌드는 `USE_SLIM` 기본값 `false`를 쓰며 CI의 `NODE_OPTIONS` 주입이 그대로 동작함을 확인했다.

**변경하지 않는 것:** `docker-compose.deploy.yaml`, `.env.openwebui.oauth` 구조, pipelines 이미지.

**배포 전략:** `openwebui` 서비스만 `--no-deps`로 교체한다.

---

## 3. Prerequisites verification (§4 이전)

workflow의 검증 스텝이 자동 수행한다. 아래는 이번 릴리스에서 특히 확인할 항목이다.

- 3.1 경로·파일(`docker-compose.deploy.yaml`, `.env.openwebui.oauth`, `openwebui/webui.db`)과 3.2 compose project name `openwebui`는 v0.11.3 가이드 §3.1~3.2와 같다.
- **3.3 현재 실행 이미지**를 기록한다. 기대값 `v0.11.3-kwh.1`. 다르면 실제 값이 rollback target이다.
- **3.4 GHCR digest**: 최종 태그와 parity 태그가 같은 digest로 해석되고 §1 값과 일치해야 한다. 불일치 시 중단.
- 3.5 `.env.openwebui.oauth`의 `WEBUI_NAME=Koreatimes`, `ENABLE_DB_MIGRATIONS` 미설정 여부는 v0.11.3 가이드 §3.5와 같다.
- **3.6 디스크**: 새 이미지(약 5~6 GB) + 백업 tar(데이터 약 3.7 GB) 동시 점유를 계산한다. 2026-10-07 관측 여유 약 24 GB는 배포 시점에 다시 확인한다.

### 3.7 Pipelines — **이번 배포에서 제외 (`SKIPPED`)**

소유자 결정(2026-10-07): Pipelines는 이번 배포에서 제외하고 `stopped`로 둔다.

- dispatch 입력은 **`check_pipelines=false`**.
- 관측 상태: `openwebui-pipelines-1`은 `Exited (137)`이고 별도의 오래된 checkout에서 생성됐다. [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34)는 열려 있다.
- 이 workflow가 직접 중지한 것이 아니므로 **Pipelines를 기동하지 않는다.**
- 결과는 `SKIPPED`로 기록한다. `PASS`로 기록하지 않는다. Pipelines 경유 대화는 이 릴리스의 프로덕션 검증 범위가 아니다.
- 로컬 게이트에서는 pipelines 6개 로드와 pipelines 모델 채팅을 확인했다(§9). 이는 프로덕션 Pipelines 상태를 증명하지 않는다.

---

## 4. Pre-deployment backup — 알려진 결함

workflow의 `Stop openwebui and back up data` 스텝이 수행한다. **현행 절차를 그대로 쓰며 이번 릴리스에서 개선하지 않았다.** 아래 한계를 승인자가 알고 승인해야 한다.

| 결함                        | 내용                                                        | 영향                                                                |
| --------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------- |
| 정지 후 압축                | Open WebUI를 멈춘 뒤 `openwebui/` 전체를 tar로 압축한다     | 압축 시간만큼 서비스가 중단된다. **"120초 중단"을 주장하지 않는다** |
| `.env.openwebui.oauth` 누락 | 아카이브에 env 파일이 포함되지 않는다                       | 백업만으로 **완전 복구를 주장할 수 없다.** env는 호스트 파일로 보존 |
| `compose pull` 반복         | 백업 뒤 `pull`이 다시 실행된다                              | 중단 시간이 늘 수 있다                                              |
| 복원 미시험                 | 기존 2026-08/09 백업의 무결성·복원 가능성을 확인하지 않았다 | 복원은 최후 수단으로만 취급                                         |

- 이번 릴리스는 스키마 변경이 없어 **이미지 롤백만으로 복구**되는 것이 기본 경로다(§8.1). 백업 복원(§8.2)에 의존하지 않는다.
- 배포 호스트는 작업 전에 `.env.openwebui.oauth`를 호스트 안전한 위치에 별도 복사하되 **내용을 열람·출력·복사 로그에 남기지 않는다.**
- 개선(사전 복사·정지 후 최종 동기화·복원 시험·3회 시간 리허설)은 별도 릴리스에서 다룬다.

---

## 5. Deployment execution

### 5.1 Workflow dispatch

| 입력              | 값                                                                                        |
| ----------------- | ----------------------------------------------------------------------------------------- |
| `tag`             | `v0.11.4-kwh.1`                                                                           |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 (Issue 생성 후 번호 확정)          |
| `guide_commit`    | 이 가이드의 최종본을 담은 `main` 커밋 전체 SHA (이 가이드를 최종 반영한 `main` 병합 커밋) |
| `check_pipelines` | **`false`** (§3.7)                                                                        |

`production` Environment 보호 규칙에 따라 `kwh8121`의 실행별 승인 이후에만 실행된다. Issue 승인과 Environment 승인은 별개다.

### 5.2 수동 fallback

필요하면 v0.11.3 가이드 §5.2의 명령을 `OPENWEBUI_IMAGE_TAG=v0.11.4-kwh.1`로 바꿔 쓴다. `--no-deps` 없이 `up`을 실행하지 않는다.

---

## 6. Migration monitoring

기대 로그는 alembic 2줄(`Context impl SQLiteImpl.`, `Will assume non-transactional DDL.`)뿐이다. `Generating new WEBUI_SECRET_KEY`, `Running upgrade`, `Traceback`, `sqlalchemy.exc`, `ModuleNotFoundError`, `langchain`이 나오면 §8.

`/health`는 workflow가 300초까지 5초 간격으로 폴링한다. 로컬 게이트 부팅은 98~163초(7 GB 호스트)였다. 300초를 넘기면 이미지 문제로 단정하지 말고 `docker inspect --format '{{.State.Health}}'`와 `free -m`을 먼저 본다.

---

## 7. Post-deployment smoke checklist

새 시크릿 창 또는 하드 리프레시로 수행한다.

### 7.1 Authentication

- [ ] 기존 Google 계정 OAuth 로그인 성공, 새로고침 후 세션 유지, 로그아웃 정상
- [ ] 로그인 화면 상태(OAuth-only / OAuth+password) 기록

### 7.2 Data integrity

- [ ] 배포 전 채팅 이력·사용자 설정·Knowledge 목록 유지
- [ ] alembic revision이 `d4c1a8e37b62`, SQLite `PRAGMA integrity_check` = `ok`

### 7.3 Fork carryovers

- [ ] 사이드바 로고·탭 제목·인스턴스명 = `Koreatimes`(`(Open WebUI)` 접미사 없음), `/manifest.json` `name`·`short_name` = `Koreatimes`
- [ ] 스플래시(라이트·다크) = Koreatimes
- [ ] 제안 카드 클릭 → 입력란만 채워지고 자동 전송되지 않음

### 7.4 Functional smoke

- [ ] 기본 모델에 메시지 전송 → 응답 수신
- [ ] 소형 텍스트 문서 업로드 후 질의 → 인용 포함 응답(RAG)
- [ ] Workspace → Tools/Functions 목록 로드 시 오류 없음(`langchain_community` 영향 확인)
- [ ] Pipelines 연결 상태는 **확인 대상 아님**(§3.7, `SKIPPED`)

---

## 8. Rollback procedure

**트리거:** §6 금지 로그 출현, `/health`가 자원 병목으로 설명되지 않는 이유로 비정상, §7.1이 전 사용자 로그인을 막음, §7.2 무결성 실패, Tool/Function 로드 실패가 운영에 지장.

workflow는 컨테이너 기동 **이전** 실패에만 이전 서비스를 자동 복구한다. 기동 이후 실패는 **자동 롤백하지 않고** 컨테이너·로그·DB·백업을 보존한 채 관리자 판단을 기다린다.

### 8.1 이미지 롤백 (데이터 유지) — 기본 복구 경로

스키마 변경이 0건이므로 이미지만 되돌리면 된다. `OPENWEBUI_IMAGE_TAG`를 §3.3에서 기록한 이전 태그(기대 `v0.11.3-kwh.1`)로 두고 v0.11.3 가이드 §8.1 명령(`pull` → `up -d --no-deps openwebui` → 로그·`/health`)을 실행한다.

### 8.2 Full 롤백 (이미지 + 백업 복원) — 최후 수단

§8.1로 복구되지 않을 때만 쓴다. 백업에 `.env.openwebui.oauth`가 없다는 점(§4)과 복원 미시험을 승인자에게 알린 뒤 v0.11.3 가이드 §8.2 절차로 진행한다. 동일 태그를 재빌드·덮어쓰지 않는다. 수정은 `v0.11.4-kwh.2`로 발행한다.

---

## 9. Evidence summary (개발 측)

| 항목                                | 결과    | 비고                                                                                                                                                                                                                                                                                                                                |
| ----------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RC 자동 게이트                      | PASS    | 2026-10-06 부팅 98초 / 2026-10-07 재기동 163초, `/health` 200, upgrade 0건, `alembic current == heads`                                                                                                                                                                                                                              |
| RC 수동: OAuth 로그인               | PASS    | 2026-10-07 사용자 확인 (RC 이미지, 로컬 누적 데이터)                                                                                                                                                                                                                                                                                |
| RC 수동: pipelines 채팅             | PASS    | 로컬 게이트의 pipelines 경유. 프로덕션 Pipelines와 무관                                                                                                                                                                                                                                                                             |
| RC 수동: RAG 업로드·인용            | PASS    | 2026-10-07 사용자 확인                                                                                                                                                                                                                                                                                                              |
| 최종 태그 이미지 게이트             | PASS    | 2026-10-07 `./scripts/local-test.sh v0.11.4-kwh.1`(`--no-backup`, 축적 데이터). 부팅 98초, `/health` 200, upgrade 0건, `alembic current == heads`(`d4c1a8e37b62`), integrity `ok`, `/api/config` `Koreatimes 0.11.4`, `/_app/version.json` = tag SHA, manifest `Koreatimes`. 로그 `Traceback`·`ModuleNotFoundError`·`langchain` 0건 |
| 프로덕션 `langchain_community` 사용 | UNKNOWN | §2 사전조건. 로컬 DB에 Tool/Function 0개였다                                                                                                                                                                                                                                                                                        |
| 프로덕션 Pipelines                  | SKIPPED | §3.7                                                                                                                                                                                                                                                                                                                                |
| 백업·복원 개선                      | 미구현  | §4                                                                                                                                                                                                                                                                                                                                  |

RC 결과를 최종 태그 이미지의 PASS로 대체하지 않는다.

### 최종 게이트 로그의 ERROR 4건 (관측)

- `get_tool_servers_data` / `get_tool_server_data` 2건: 로컬에 없는 프로덕션 도구 서버(`fastapi-tools-v2`) 미접속. 10-06 RC 게이트와 동일하며 비치명.
- `oauth_sessions._decrypt_token` `InvalidToken` 및 `get_session_by_id` 각 2건: 로컬 브라우저에 남아 있던 이전(RC) 세션 쿠키 요청 직후 발생했고 곧바로 `/api/v1/auths/signout` 200으로 정리됐다. 새 컨테이너가 이전 세션의 저장 토큰을 복호화하지 못한 것으로 **추정**하나 원인은 확정하지 못했다. 프로덕션은 `WEBUI_SECRET_KEY`가 데이터 디렉터리에서 유지되므로(§6 `Generating new WEBUI_SECRET_KEY` 금지) 재현되지 않아야 하며, 배포 후 §7.1에서 기존 세션·로그인이 정상인지 확인한다. 기존 세션 사용자가 한 번 재로그인하는 정도는 롤백 사유가 아니다.
