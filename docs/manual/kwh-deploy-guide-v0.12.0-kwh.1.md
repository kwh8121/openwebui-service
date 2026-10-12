# Production Deployment Guide — `v0.12.0-kwh.1`

이 가이드는 프로덕션 배포 에이전트가 실행하는 릴리스별 명령 소스다. 정상 상태에서는
`Deploy approved production release` workflow(`.github/workflows/deploy-approved-production-release.yaml`)가
§4~§6을 자동 수행하며, 이 문서는 그 입력값·기대 결과·제한을 규정한다.
공통 절차·수동 fallback 명령은 [`kwh-deploy-guide-v0.11.3-kwh.1.md`](./kwh-deploy-guide-v0.11.3-kwh.1.md)와 같고, 이 문서는 **이번 릴리스에서 달라지는 점만** 적는다.

> **상태: 초안.** `<TBD>` 표시는 최종 태그·GHCR 빌드·최종 게이트 이후 채운다. 초안으로는 배포 요청을 제출하지 않는다.
> **이전 릴리스(`v0.11.4-kwh.1`)와 근본적으로 다른 점: 스키마 마이그레이션 6건이 실행되며, 이미지 롤백만으로는 복구되지 않는다(§8).**

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) → [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) → [릴리스 루틴](./kwh-release-routine.md) → 이 가이드. 충돌 시 앞선 문서가 이긴다.

---

## 1. Release identifiers

| 항목                            | 값                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------- |
| Version                         | **v0.12.0-kwh.1**                                                               |
| Main tip SHA (태그 대상, 40자)  | `<TBD>`                                                                         |
| GHCR image tag (배포 대상)      | `ghcr.io/kwh8121/openwebui-service:v0.12.0-kwh.1`                               |
| OCI index digest                | `<TBD>`                                                                         |
| linux/amd64 digest              | `<TBD>`                                                                         |
| GHCR short-SHA parity tag       | `ghcr.io/kwh8121/openwebui-service:git-<TBD>`                                   |
| GH Actions build Run            | `<TBD>`                                                                         |
| RC (참고용, 배포 대상 아님)     | `v0.12.0-kwh.1-rc.1` @ `68baf382c` — build run 38230963520                      |
| Base upstream                   | Open WebUI `v0.12.0` (`15818d88f`, 2026-10-10), `v0.11.4`에서 584 커밋·542 파일 |
| Fork carryovers                 | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `insertSuggestionPrompt=true` |
| Rollback target (현재 프로덕션) | `ghcr.io/kwh8121/openwebui-service:v0.11.4-kwh.1` (실제 값은 §3.3에서 재확인)   |

`latest`·`main`·RC 태그를 배포하지 않는다. immutable 최종 태그 또는 git-SHA parity 태그만 유효하다.

---

## 2. Deployment overview

**변경 내용:** `v0.11.4-kwh.1` → `v0.12.0-kwh.1`. upstream `v0.12.0` 흡수. 텍스트 충돌 1건(`docker.yaml`), 의미 충돌 1건(`middleware.py`) 해소.

### 실행될 Alembic 마이그레이션: **6건** (`d4c1a8e37b62` → `b8f2c6d91a04`)

| revision       | 내용                                                   | 기존 데이터 영향                                  |
| -------------- | ------------------------------------------------------ | ------------------------------------------------- |
| `a7d3e9f2b641` | `auth`에 `mfa`·`session_stamp` 컬럼 추가               | 컬럼 추가만                                       |
| `b8e4f0a3c752` | `group`에 `parent_group_id`(계층)·인덱스·FK 추가       | 컬럼 추가만                                       |
| `d6a8c3f912ab` | `skill_history` 테이블, `skill.version_id`·`data` 추가 | **기존 `skill` 행마다 history 행 생성 + 행 갱신** |
| `e7b9d4a023bc` | `model_history` 테이블, `model.version_id` 추가        | **기존 `model` 행마다 history 행 생성 + 행 갱신** |
| `f8c0e5b134cd` | `tool`·`function` history 테이블, `version_id` 추가    | **기존 행마다 history 행 생성 + 행 갱신**         |
| `b8f2c6d91a04` | PostgreSQL 전용 인덱스                                 | SQLite(프로덕션)에서는 no-op                      |

- 프로덕션 revision이 `d4c1a8e37b62`인지 §3에서 확인한다. 다르면 배포하지 않는다.
- 기동 로그에 `Running upgrade` 6줄이 나오는 것이 **정상**이다. 6줄이 아니면(0줄 포함) 전제가 깨진 것이므로 중단하고 에스컬레이션한다.
- 모든 마이그레이션에 `downgrade()`가 구현돼 있으나 **이전 이미지(`v0.11.4-kwh.1`)는 자동으로 downgrade하지 않으며**, DB의 revision을 알지 못해 기동에 실패할 가능성이 높다(§8).
- 로컬 게이트(축적 데이터 891 MB)에서 6건 모두 오류 없이 적용됐다. 프로덕션 데이터 규모(약 3.7 GB)에서의 소요 시간은 **검증하지 못했다.**

### 신규 기능·설정 (모두 기본 비활성, 환경 변수 추가 불필요)

- 2단계 인증(`ENABLE_MFA` 기본 `False`), 실시간 음성(`AUDIO_REALTIME_ENABLED`), `ENABLE_TOOLS`/`ENABLE_FUNCTIONS`/`ENABLE_TOOL_SERVERS` 기본 `True`.
- **`.env.openwebui.oauth`를 변경하지 않는다.** 설정이 필요한 새 변수는 없다.
- 의존성: 제거된 패키지 없음. `pyotp`·`qrcode` 추가, `aiohttp` 3.14.3 등 상향.

### 이번 릴리스에 포함된 fork 수정

- **#47** 채팅 제목 백그라운드 태스크 `KeyError: 'model'` — 완료된 턴이 있는 컨텍스트에서만 메모리 리뷰 실행. upstream이 같은 지점을 `ctx.get('model')`로 독립 수정했으나 fork는 `ctx['model']` 엄격 접근을 유지한다(`build_chat_response_context`는 항상 `model`을 설정하며 title-only 경로만 가드로 막는다).
- **`BUILD_CHANNEL=main`** 을 GHCR 빌드 인자로 고정. 없으면 UI 버전 표시에 `(build · hash)`가 붙고 업데이트 확인이 꺼진다.
- **deploy workflow 변경 (#49 1단계, #55):** 이 workflow의 백업 단계가 이전 배포(`v0.11.4-kwh.1`) 이후 바뀌었다. **이번이 새 단계의 첫 실제 실행이다.** §4 참조.

**변경하지 않는 것:** `docker-compose.deploy.yaml`, `.env.openwebui.oauth` 구조, pipelines 이미지.

**배포 전략:** `openwebui` 서비스만 `--no-deps`로 교체한다.

---

## 3. Prerequisites verification (§4 이전)

workflow의 검증 스텝이 자동 수행한다. 이번 릴리스에서 특히 확인할 항목:

- 3.1 경로·파일과 3.2 compose project name `openwebui`는 v0.11.3 가이드 §3.1~3.2와 같다.
- **3.3 현재 실행 이미지**를 기록한다. 기대값 `v0.11.4-kwh.1`. 다르면 실제 값이 rollback target이다. workflow는 컨테이너를 조회할 수 없거나 없으면 **서비스 정지 전에** 중단한다.
- **3.4 GHCR digest**: 최종 태그와 parity 태그가 같은 digest로 해석되고 §1 값과 일치해야 한다. 불일치 시 중단.
- **3.4-1 현재 DB revision = `d4c1a8e37b62`.** 운영 DB를 직접 열지 말고 실행 중 컨테이너의 `alembic current`로 읽는다.
- 3.5 `.env.openwebui.oauth`의 `WEBUI_NAME=Koreatimes`, `ENABLE_DB_MIGRATIONS` 미설정 여부는 v0.11.3 가이드 §3.5와 같다. `ENABLE_DB_MIGRATIONS=false`이면 마이그레이션이 실행되지 않아 스키마가 코드보다 뒤처진다. 이 조합은 시험하지 않았으므로 설정돼 있으면 배포하지 않고 소유자에게 확인한다.
- 3.5-1 digest 대조는 dispatch 전 배포 에이전트가 수행한다(workflow는 기록만 한다).
- 3.5-2 `/app/pipelines` 존재·읽기 가능 확인(백업 tar 포함 대상, 부재 시 정지 후 tar 실패).
- **3.6 디스크**: 새 이미지(약 5~6 GB) + 백업 tar(데이터 약 3.7 GB) + env 사본. 마이그레이션이 history 행을 추가하므로 DB가 늘 수 있다. 배포 시점 여유를 다시 확인한다.

### 3.7 Pipelines — 소유자 결정 필요

`v0.11.4-kwh.1` 배포에서는 Pipelines가 `SKIPPED`였고 [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34)는 열려 있다. 이번 릴리스에서의 `check_pipelines` 값은 **배포 요청 Issue에서 소유자가 결정**한다. 기본 가정은 `false`(`SKIPPED`)이며, `PASS`로 기록하지 않는다.

---

## 4. Pre-deployment backup — 개선 반영 + 남은 한계

workflow의 `Stop openwebui and back up data` 스텝은 이전 배포 이후 바뀌었다(#49 1단계, #55). **현재 workflow를 직접 읽어 대조했다** (부록).

| 항목                   | 이전 (`v0.11.4-kwh.1`)            | 이번                                                                            |
| ---------------------- | --------------------------------- | ------------------------------------------------------------------------------- |
| 아카이브 권한          | `0644`                            | `umask 077`로 생성, 생성 직후 모드 `600` 검사                                   |
| `.env.openwebui.oauth` | 아카이브에 미포함, 별도 보존 없음 | **서비스 정지 전에** `0600` 사본(`….env`)으로 보존. 실패 시 서비스 실행 중 중단 |
| 롤백 기준점            | 불확실                            | 현재 컨테이너 조회 불가/부재 시 정지 전 중단                                    |
| 재기동                 | `compose pull` 재실행             | `up --pull never` (백업 전에 pull한 이미지를 재사용)                            |

**남은 한계 — 승인자가 알고 승인해야 한다:**

- 정지 후 압축 순서는 그대로다. 압축 시간만큼 서비스가 중단된다. **중단 시간 단축은 2단계(미구현).** 이전 배포 실측 중단 약 6분(서비스 정지+백업 283초)이며, 이번 DB는 더 클 수 있다. 시간을 약속하지 않는다.
- **새 단계는 운영 러너에서 이번이 첫 실행이다.** 모의 테스트(`backup-regression`, 13건)는 통과했으나 실제 환경 검증이 아니다. 기동 이전 실패 시 기존 "자동 복구" 단계가 이전 서비스를 재기동한다.
- **백업 복원은 한 번도 시험하지 않았다.** 이번에는 복원이 유일한 롤백 경로가 될 수 있어(§8) 위험이 이전보다 크다.

---

## 5. Deployment execution

### 5.1 Workflow dispatch

| 입력              | 값                                                                          |
| ----------------- | --------------------------------------------------------------------------- |
| `tag`             | `v0.12.0-kwh.1`                                                             |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 (Issue 생성 후 확정) |
| `guide_commit`    | 이 가이드의 최종본을 담은 `main` 커밋 전체 SHA                              |
| `check_pipelines` | §3.7에서 결정 (기본 가정 `false`)                                           |

`production` Environment 보호 규칙에 따라 `kwh8121`의 실행별 승인 이후에만 실행된다. Issue 승인과 Environment 승인은 별개다. dispatch 입력은 소유자가 GitHub UI에서 직접 넣는다.

### 5.2 수동 fallback

v0.11.3 가이드 §5.2의 명령을 `OPENWEBUI_IMAGE_TAG=v0.12.0-kwh.1`로 바꿔 쓴다. `--no-deps` 없이 `up`을 실행하지 않는다.

---

## 6. Migration monitoring

기대 로그: alembic 2줄(`Context impl SQLiteImpl.`, `Will assume non-transactional DDL.`) 뒤에 **`Running upgrade` 6줄**(§2 표의 순서). 마지막 revision은 `b8f2c6d91a04`.

다음이 나오면 §8: `Generating new WEBUI_SECRET_KEY`, `Traceback`, `sqlalchemy.exc`, `ModuleNotFoundError`, `Can't locate revision`, 6줄 미만에서 멈춘 `Running upgrade`.

- 마이그레이션은 **기동 중 `/health` 이전에** 실행된다. history 행 생성 때문에 이전 릴리스보다 부팅이 길어질 수 있다. 로컬 게이트 부팅은 103초(891 MB 데이터)였다.
- `/health`는 workflow가 300초까지 폴링한다. 300초를 넘겨도 **마이그레이션 진행 중일 수 있으므로** 이미지 문제로 단정하거나 컨테이너를 재시작하지 않는다. 중간에 재시작하면 일부만 적용된 DB가 남을 수 있다. 먼저 `docker logs`로 `Running upgrade` 진행과 `free -m`을 본다.

---

## 7. Post-deployment smoke checklist

새 시크릿 창 또는 하드 리프레시로 수행한다.

### 7.1 Authentication

- [ ] 기존 Google 계정 OAuth 로그인 성공, 새로고침 후 세션 유지, 로그아웃 정상
- [ ] 2단계 인증이 켜지지 않았는지(`ENABLE_MFA` 기본 `False`) 확인 — 로그인 중 TOTP 설정 화면이 나오면 비정상

### 7.2 Data integrity

- [ ] 배포 전 채팅 이력·사용자 설정·Knowledge 목록 유지
- [ ] alembic revision = `b8f2c6d91a04`, SQLite `PRAGMA integrity_check` = `ok`
- [ ] **기존 Model/Tool/Function/Skill 개수가 배포 전과 같다** (마이그레이션이 이들 행을 갱신한다). 워크스페이스의 커스텀 모델·도구 목록을 배포 전에 기록해 둔다.

### 7.3 Fork carryovers

- [ ] 사이드바 로고·탭 제목·인스턴스명 = `Koreatimes`(`(Open WebUI)` 접미사 없음), `/manifest.json` `name`·`short_name` = `Koreatimes`
- [ ] 스플래시(라이트·다크) = Koreatimes
- [ ] 제안 카드 클릭 → 입력란만 채워지고 자동 전송되지 않음
- [ ] **버전 표시가 `v0.12.0`이고 `(build · …)` 접미사가 없다** (`BUILD_CHANNEL=main`)

### 7.4 Functional smoke

- [ ] 기본 모델에 메시지 전송 → 응답 수신
- [ ] **저장되는 새 채팅에서 제목 자동 생성** 후 로그에 `KeyError`·`Traceback` 없음 (#47). 배포 직후 로그를 `> file 2>&1`로 수집해 스캔한다.
- [ ] 소형 텍스트 문서 업로드 후 질의 → 인용 포함 응답(RAG)
- [ ] Workspace → Models/Tools/Functions/Skills 목록 로드 시 오류 없음
- [ ] Pipelines 연결 상태는 §3.7 결정에 따른다

---

## 8. Rollback procedure

**트리거:** §6 금지 로그 출현, `/health`가 자원 병목으로 설명되지 않는 이유로 비정상, §7.1이 전 사용자 로그인을 막음, §7.2 무결성 실패 또는 Model/Tool/Function/Skill 손실, §7.4 제목 생성 `KeyError` 재발.

workflow는 컨테이너 기동 **이전** 실패에만 이전 서비스를 자동 복구한다. 기동 이후 실패는 **자동 롤백하지 않고** 컨테이너·로그·DB·백업을 보존한 채 관리자 판단을 기다린다. 판단 전에 아무것도 삭제·덮어쓰지 않는다.

### ⚠ 이미지 롤백만으로는 복구되지 않는다

이전 릴리스와 달리 스키마가 바뀐다. DB가 `b8f2c6d91a04`로 올라간 뒤 `v0.11.4-kwh.1` 이미지로 되돌리면, 해당 이미지는 그 revision을 알지 못하므로 기동에 실패할 가능성이 높다. **이 동작을 실제로 시험하지 않았다.** 이미지만 되돌리는 것을 기본 복구 경로로 쓰지 않는다.

### 8.1 Full 롤백 (이미지 + 백업 복원) — 기본 복구 경로

1. 컨테이너를 정지하고 현 상태(DB·로그)를 별도로 보존한다.
2. §4 백업 아카이브(`prod-backup-preupgrade-…-v0.11.4-kwh.1.tar.gz`)로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`는 아카이브에 없다. 변경하지 않았다면 그대로 두고, 의심되면 §4의 `0600` 사본과 대조한다(내용을 출력하지 않는다).
4. `OPENWEBUI_IMAGE_TAG`를 §3.3에서 기록한 이전 태그(기대 `v0.11.4-kwh.1`)로 두고 `up -d --no-deps openwebui` → 로그·`/health`.
5. 복원 후 §7.2로 데이터 개수를 확인한다.

**한계:** 복원은 시험된 적이 없다. 백업 시점 이후의 채팅·설정은 사라진다. 승인자에게 이를 알린 뒤 진행한다.

### 8.2 DB downgrade (대안, 미시험)

새 이미지로 `alembic downgrade d4c1a8e37b62`를 실행하면 6건이 역순으로 되돌려진다(각 `downgrade()` 구현 확인). 그러나 history 테이블과 `version_id` 컬럼이 삭제되며 **운영 DB에서 시험된 적이 없다.** 8.1이 실패했을 때만 소유자 승인으로 검토한다.

동일 태그를 재빌드·덮어쓰지 않는다. 수정은 `v0.12.0-kwh.2`로 발행한다.

---

## 9. Evidence summary (개발 측)

| 항목                                          | 결과    | 비고                                                                                                                                                                                                         |
| --------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 정적 검사 (병합 브랜치)                       | PASS    | `npm ci`(Node 22), `i18n:parse` 변경 0건, prettier(존재 파일) 통과, vitest 4/4, ruff 추적 파일 363개 통과, `svelte-check` 6,040건(기준선 약 7,800) 중 수정 파일 신규 오류 0건                                |
| RC 자동 게이트                                | PASS    | 2026-10-12 `./scripts/local-test.sh v0.12.0-kwh.1-rc.1 --allow-rc`. 부팅 103초, `/health` 200, upgrade 6건, `alembic current == heads`(`b8f2c6d91a04`), integrity `ok`, pipelines 응답, 로그 `Traceback` 0건 |
| RC 수동: OAuth·pipelines·RAG·브랜드·버전 표시 | PASS    | 2026-10-12 사용자 확인 (RC 이미지, 로컬 누적 데이터)                                                                                                                                                         |
| RC 수동: 제목 생성 (#47)                      | PASS    | 저장 채팅 생성 후 사용자 확인, 컨테이너 로그 331줄(`/usr/bin/docker logs`) `Traceback`·`KeyError` 0건. 제목의 UI 표시는 개발 측이 직접 보지 못했다                                                           |
| #47 회귀 테스트                               | PASS    | RC 이미지 안 3/3 통과                                                                                                                                                                                        |
| 최종 태그 이미지 게이트                       | `<TBD>` | 최종 태그 빌드 후 수행                                                                                                                                                                                       |
| 프로덕션 규모 마이그레이션 시간               | 미검증  | 로컬 891 MB 기준만 측정                                                                                                                                                                                      |
| 백업 복원·DB downgrade                        | 미시험  | §4, §8                                                                                                                                                                                                       |
| 프로덕션 Pipelines                            | `<TBD>` | §3.7                                                                                                                                                                                                         |

RC 결과를 최종 태그 이미지의 PASS로 대체하지 않는다.

### RC 게이트 로그의 ERROR (관측)

- `get_tool_server_data` / `get_tool_servers_data` 2건: 도구 서버 `fastapi-tools-v2:8000` DNS 실패. [Issue #48](https://github.com/kwh8121/openwebui-service/issues/48)과 동일하며 릴리스 무관.
- `oauth_sessions._decrypt_token` `InvalidToken` 3건 및 `get_session_by_id` 1건: 로컬 브라우저에 남은 이전 세션 쿠키 + 로컬 컨테이너의 `Generating new WEBUI_SECRET_KEY`. 직후 `signout` 200으로 정리됐다. 프로덕션은 키가 데이터 디렉터리에 유지되므로 재현되지 않아야 한다(§6).

---

## Appendix. workflow 대조 결과 (2026-10-12, 개발 측)

현재 `deploy-approved-production-release.yaml`을 읽어 이 가이드의 서술과 대조했다.

| 가이드 서술                                    | workflow 실제                                                              | 일치 |
| ---------------------------------------------- | -------------------------------------------------------------------------- | ---- |
| 백업 `umask 077` + 모드 `600` 검사             | `umask 077`, `stat -c '%a'`로 아카이브·env 사본 검사                       | 일치 |
| env 사본을 서비스 정지 전에 보존               | `install -m 600 "${ENV_FILE}" "${env_copy_path}"`                          | 일치 |
| 아카이브 대상은 `openwebui`와 `/app/pipelines` | `tar -czf … -C ${DEPLOY_DIR} openwebui -C /app pipelines`, `tar -tzf` 검증 | 일치 |
| 재기동은 pull 없이                             | `up -d --no-deps --pull never openwebui`                                   | 일치 |
| 롤백 기준점 선캡처                             | `Capture current running image (rollback anchor)` 단계                     | 일치 |

> 이 표는 초안 작성 시점의 대조이다. 최종본 작성 직전 workflow를 다시 읽고 `guide_commit`을 확정한다.
