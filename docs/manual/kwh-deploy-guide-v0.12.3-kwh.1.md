# Production Deployment Guide — `v0.12.3-kwh.1`

이 가이드는 프로덕션 배포 에이전트가 실행하는 릴리스별 명령 소스다. 정상 상태에서는
`Deploy approved production release` workflow(`.github/workflows/deploy-approved-production-release.yaml`)가
§4~§6을 자동 수행하며, 이 문서는 그 입력값·기대 결과·제한을 규정한다.
공통 절차·수동 fallback 명령은 [`kwh-deploy-guide-v0.11.3-kwh.1.md`](./kwh-deploy-guide-v0.11.3-kwh.1.md)와 같고, 바로 이전 릴리스 가이드 [`kwh-deploy-guide-v0.12.2-kwh.1.md`](./kwh-deploy-guide-v0.12.2-kwh.1.md)의 구조를 따른다. 이 문서는 **이번 릴리스에서 달라지는 점만** 적는다.

> **상태: 최종본.** 최종 태그·GHCR 빌드·최종 게이트 값을 채웠다. 프로덕션 스냅샷 리허설은 소유자 결정 사항이라 미결정으로 남아 있다(§9). 배포 Issue 번호는 Issue 생성 후 dispatch 입력으로 전달한다. 프로덕션 Pipelines 처리(§3.7)는 소유자가 배포 요청 Issue에서 정한다. 승인 시각·Environment 승인은 별도이며 이 문서가 대신하지 않는다.
> **이번 릴리스에는 DB 마이그레이션이 없다.** 프로덕션 revision은 `0bd252b206fb`로 유지된다. 직전 두 릴리스와 달리 기동 로그에 `Running upgrade`가 **나오지 않는 것이 정상**이다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) → [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) → [릴리스 루틴](./kwh-release-routine.md) → 이 가이드. 충돌 시 앞선 문서가 이긴다.

---

## 1. Release identifiers

| 항목                            | 값                                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Version                         | **v0.12.3-kwh.1**                                                                                     |
| Main tip SHA (태그 대상, 40자)  | `5d83d91cc4da81becfa7c763b5e5f4790264979e` (PR #64 병합 커밋)                                         |
| GHCR image tag (배포 대상)      | `ghcr.io/kwh8121/openwebui-service:v0.12.3-kwh.1`                                                     |
| OCI index digest                | `sha256:b969b7360fd9bcfde23111cfd46f7bbc84f83dc9046472bbd46d42a76b2c72d9`                             |
| linux/amd64 manifest digest     | `sha256:5c2359ca5fd5b043a343ec19719f449e180548702ea2aa6357b2eca3621d9afb`                             |
| GHCR short-SHA parity tag       | `ghcr.io/kwh8121/openwebui-service:git-5d83d91` (최종 태그와 같은 이미지 확인)                        |
| GH Actions build Run            | [39195302512](https://github.com/kwh8121/openwebui-service/actions/runs/39195302512) (success)        |
| RC (참고용, 배포 대상 아님)     | `v0.12.3-kwh.1-rc.1` @ `03936421c093bfc9c8e875548175d3370cd14899` — build run 39188491140             |
| Base upstream                   | Open WebUI `v0.12.3` (2026-10-16). `v0.12.2`에서 91 커밋·209 파일                                     |
| Fork carryovers                 | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `insertSuggestionPrompt=true`, `BUILD_CHANNEL=main` |
| Rollback target (현재 프로덕션) | `ghcr.io/kwh8121/openwebui-service:v0.12.2-kwh.1` (실제 값은 §3.3에서 재확인)                         |

`latest`·`main`·RC 태그를 배포하지 않는다. immutable 최종 태그 또는 git-SHA parity 태그만 유효하다.

digest 확인 방법(개발 측): 개발 머신에는 `docker buildx`가 없어 `docker manifest inspect ghcr.io/kwh8121/openwebui-service:v0.12.3-kwh.1`로 index와 amd64 항목을 읽는다(`unknown/unknown` 항목은 플랫폼 이미지가 아니다). 최종 태그와 parity 태그를 각각 `docker pull`한 뒤 `RepoDigests`가 같음을 확인했고, 그 값이 위 OCI index digest다. 이 digest가 §3.5-1 대조의 기준이다.

---

## 2. Deployment overview

**변경 내용:** `v0.12.2-kwh.1` → `v0.12.3-kwh.1`. upstream `v0.12.3` 흡수. 병합은 **텍스트 충돌 0건**이다. 병합 후 fork carryover 3건(`insertSuggestionPrompt ?? true`, `WEBUI_NAME` 접미사 제거, Dockerfile `NODE_OPTIONS`)이 그대로 있음을 확인했다.

### 실행될 Alembic 마이그레이션: **0건** (`0bd252b206fb` 유지)

- `v0.12.2..v0.12.3` 사이에 `backend/open_webui/migrations/`의 변경은 없다.
- 프로덕션 revision이 `0bd252b206fb`인지 §3에서 확인한다. 다르면 배포하지 않는다.
- 기동 로그에 `Running upgrade`가 **나오면 전제가 깨진 것**이므로 중단하고 에스컬레이션한다.
- 기동 중 `Seeded N new config defaults` 로그가 나올 수 있다(로컬 게이트에서 `Seeded 3 new config defaults`). 새 설정 기본값 행이 `config` 테이블에 추가되는 것으로, 마이그레이션이 아니다.
- 스키마가 바뀌지 않으므로 이미지 롤백의 부담이 직전 두 릴리스보다 작다. 다만 새 이미지가 기동 중 쓴 `config` 행 등으로 이전 이미지가 정상 기동하는지는 **시험하지 않았다**(§8).

### 신규 기능·설정 (환경 변수 추가 불필요)

- **종단 간 암호화 채팅** — DM·비공개 그룹 채널의 임시 암호화 채팅. 관리자 설정 또는 `ENABLE_ENCRYPTED_CHANNELS`와 새 권한으로 켜야 하며 **기본 꺼짐**이다. 켜려면 websocket과 프로덕션 HTTPS가 필요하다. 이번 배포에서 켜지 않는다.
- **워크스페이스 검색**(채팅·채널·노트 통합 검색), **공유 채팅 협업자 아바타**, **폴더 Access 버튼**, **문서 미리보기 댓글**, **Compare 보기 옵션·Undo**, **Clear Input Selections 단축키**. 모두 기본 설정으로 쓸 수 있는 UI 기능이다.
- **Redis 스트리밍 경량화·Redis 권한 변경** — Redis를 쓰지 않으면 해당 없음. 이 fork의 프로덕션 Redis 사용 여부는 이 문서에서 확인하지 않았다. 사용 중이면 `WEBSOCKET_REDIS_ROOM_CHANNELS`가 켜져 있을 때만 Redis 사용자 권한(PUBLISH·SUBSCRIBE·UNSUBSCRIBE·PING)이 영향을 받는다.
- **`.env.openwebui.oauth`를 변경하지 않는다.** 설정이 필요한 새 변수는 없다.
- 의존성: 프런트엔드 `package.json`에 빌드 전 `crypto:verify` 스크립트가 추가됐고 `docx-preview`가 `0.4.0`으로 고정됐다. 이미지 빌드는 이를 포함해 성공했다. `pyproject.toml`은 변경이 없다.

### 이번 릴리스에서 프로덕션에 영향이 있을 수 있는 upstream 변경

- **스킬 동작 변경 (Changed).** 스킬 builtin 도구를 켠 상태에서 **모델에 연결된 스킬과 입력창 메뉴로 고른 스킬이 전체 지침을 매 메시지에 보낸다.** 이전에는 이름·설명만 나열됐다. 프로덕션에 스킬이 5개 있다(직전 보고값). 모델에 스킬을 연결해 둔 경우 프롬프트가 길어져 토큰 사용이 늘 수 있다. upstream은 "모델에 연결만 해 둔" 스킬은 제거하라고 안내한다. 이 판단은 소유자 몫이며 배포 전에 모델별 연결 현황을 확인해 기록한다(§3.6-2).
- **OAuth 토큰 갱신 수정.** `OAUTH_TOKEN_ENDPOINT_AUTH_METHOD=client_secret_basic`일 때만 해당한다. 프로덕션이 이 값을 쓰는지는 env 내용을 출력하지 않고 확인해야 하며, 이 문서 작성 시 확인하지 않았다.
- **Google Drive 선택기 범위 축소.** 선택한 파일만 접근한다. 이 fork는 Google을 로그인(OAuth)에 쓰며 Drive 연동 사용 여부는 확인하지 않았다.
- 공유 지식·프롬프트·도구를 쓰기 권한 협업자가 저장해도 공유가 풀리지 않는 수정, 채널 IME 입력 수정, 긴 노트 PDF 내보내기 수정 등.

**변경하지 않는 것:** `docker-compose.deploy.yaml`, `.env.openwebui.oauth` 구조, pipelines 이미지, deploy workflow(마지막 변경 `44c3db7ac`, 2026-10-08).

**배포 전략:** `openwebui` 서비스만 `--no-deps`로 교체한다.

---

## 3. Prerequisites verification (§4 이전)

workflow의 검증 스텝이 자동 수행한다. 이번 릴리스에서 특히 확인할 항목:

- 3.1 경로·파일과 3.2 compose project name `openwebui`는 v0.11.3 가이드 §3.1~3.2와 같다.
- **3.3 현재 실행 이미지**를 기록한다. 기대값 `v0.12.2-kwh.1`. 다르면 실제 값이 rollback target이다. workflow는 컨테이너를 조회할 수 없거나 없으면 **서비스 정지 전에** 중단한다.
- **3.4 GHCR digest**: 최종 태그와 parity 태그가 같은 digest로 해석되고 §1 값과 일치해야 한다. 불일치 시 중단.
- **3.4-1 현재 DB revision = `0bd252b206fb`.** 운영 DB를 직접 열지 말고 실행 중 컨테이너의 `alembic current`로 읽는다.
- 3.5 `.env.openwebui.oauth`의 `WEBUI_NAME=Koreatimes`, `ENABLE_DB_MIGRATIONS` 미설정 여부는 v0.11.3 가이드 §3.5와 같다. 이번에는 마이그레이션이 없어 `ENABLE_DB_MIGRATIONS=false`여도 스키마 불일치는 생기지 않지만, 이 조합은 시험하지 않았으므로 설정돼 있으면 소유자에게 확인한다.
- 3.5-1 digest 대조는 dispatch 전 배포 에이전트가 수행한다(workflow는 기록만 한다).
- 3.5-2 `/app/pipelines` 존재·읽기 가능 확인(백업 tar 포함 대상, 부재 시 정지 후 tar 실패).
- **3.6 디스크**: 새 이미지(약 5~6 GB) + 백업 tar(이전 배포 실측 2.66 GB, 데이터 약 3.9 GB) + env 사본. 이전 배포 백업과 이전 이미지가 호스트에 남아 있을 수 있으므로 배포 시점 여유를 다시 확인한다.
- **3.6-1 배포 전 개수 기록.** Model(사용자 정의)·Tool·Function·Skill·Knowledge·Prompt 개수를 관리자 화면에서 기록한다(직전 보고값: 9·8·29·5·2·8). 이번 릴리스는 이들을 갱신하지 않지만 §7.2 대조의 기준이 된다. 채널·채널 멤버·채널 메시지 개수도 함께 기록한다.
- **3.6-2 모델별 스킬 연결 현황 기록.** 위 "스킬 동작 변경"의 영향 범위를 가늠하기 위해, 스킬이 연결된 모델 수와 스킬 수를 기록한다.

### 3.7 Pipelines — 소유자 결정 필요

`check_pipelines` 값은 **배포 요청 Issue에서 소유자가 배포 직전 컨테이너 상태를 보고 결정**한다. `running`이고 9099가 200이면 `true`, 정지·미사용이면 `false`(`SKIPPED`, `PASS`로 기록하지 않음)이다. 배포 중 Pipelines를 기동·재생성하지 않는다. [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34)는 열려 있다.

---

## 4. Pre-deployment backup — 남은 한계

workflow의 `Stop openwebui and back up data` 스텝은 변경되지 않았다(마지막 변경 `44c3db7ac`).

**이전 배포 실측(`v0.12.0-kwh.1`, run 38376927749):** 이미지 pull 2분 39초(정지 전), 백업 단계 4분 28초, 기존 컨테이너 종료→`/health` 완료 약 5분 11초(관측 상한), 전체 job 8분 12초(승인 대기 제외). 백업 tar 2,660,671,162 bytes. 이번 DB는 더 클 수 있으며 **시간을 약속하지 않는다.** `v0.12.2-kwh.1` 배포 실측은 이 문서에서 확인하지 않았다.

**남은 한계 — 승인자가 알고 승인해야 한다:**

- 정지 후 압축 순서는 그대로다. 압축 시간만큼 서비스가 중단된다. **중단 시간 단축(#49 2단계)은 미구현이다.**
- **실제 배포 백업 tar의 복원은 증명되지 않았다.** `tar -tzf` 목록 검사만 통과했다.
- 실패 경로(작업 중 실패·중단 시 남는 파일의 권한·복구)는 운영에서 시험되지 않았다.

---

## 5. Deployment execution

### 5.1 Workflow dispatch

| 입력              | 값                                                                          |
| ----------------- | --------------------------------------------------------------------------- |
| `tag`             | `v0.12.3-kwh.1`                                                             |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 (Issue 생성 후 확정) |
| `guide_commit`    | 이 가이드의 최종본을 담은 `main` 커밋 전체 SHA                              |
| `check_pipelines` | §3.7에서 결정. **기본값은 체크(`true`)이므로 정지 상태면 반드시 해제**      |

`production` Environment 보호 규칙에 따라 `kwh8121`의 실행별 승인 이후에만 실행된다. Issue 승인과 Environment 승인은 별개다. dispatch 입력은 소유자가 GitHub UI에서 직접 넣는다(개발 에이전트의 `gh workflow run`은 권한 검사에서 프로덕션 배포로 차단된다).

### 5.2 수동 fallback

v0.11.3 가이드 §5.2의 명령을 `OPENWEBUI_IMAGE_TAG=v0.12.3-kwh.1`로 바꿔 쓴다. `--no-deps` 없이 `up`을 실행하지 않는다.

---

## 6. Migration monitoring

기대 로그: alembic 2줄(`Context impl SQLiteImpl.`, `Will assume non-transactional DDL.`) 뒤에 **`Running upgrade`가 없다.** `alembic current`는 `0bd252b206fb` 그대로다.

다음이 나오면 §8: `Running upgrade`(1줄이라도), `Generating new WEBUI_SECRET_KEY`, `Traceback`, `sqlalchemy.exc`, `ModuleNotFoundError`, `Can't locate revision`, `CHECK constraint failed`.

- 로컬 게이트 부팅은 138초(RC)·198초(최종 태그)였다. 부팅 시간은 PyTorch 적재와 호스트 상태에 좌우되며 프로덕션 시간은 약속하지 않는다.
- `/health`는 workflow가 300초까지 폴링한다. 300초를 넘기면 이미지 문제로 단정하거나 컨테이너를 재시작하지 말고, 먼저 `docker logs`와 `free -m`을 본다. 로컬 게이트 최종 태그 부팅이 198초였으므로 느린 호스트에서는 300초에 근접할 수 있다.

---

## 7. Post-deployment smoke checklist

새 시크릿 창 또는 하드 리프레시로 수행한다.

### 7.1 Authentication

- [ ] 기존 Google 계정 OAuth 로그인 성공, 새로고침 후 세션 유지, 로그아웃 정상
- [ ] 2단계 인증이 켜지지 않았는지(`ENABLE_MFA` 기본 `False`) 확인

### 7.2 Data integrity

- [ ] 배포 전 채팅 이력·사용자 설정·Knowledge 목록 유지
- [ ] alembic revision = `0bd252b206fb`(변화 없음), SQLite `PRAGMA integrity_check` = `ok`
- [ ] **Model/Tool/Function/Skill/Knowledge/Prompt 개수가 §3.6-1 기록과 같다**
- [ ] 채널·채널 멤버·채널 메시지 개수가 §3.6-1 기록과 같다

### 7.3 Fork carryovers

- [ ] 사이드바 로고·탭 제목·인스턴스명 = `Koreatimes`(`(Open WebUI)` 접미사 없음), `/manifest.json` `name`·`short_name` = `Koreatimes`
- [ ] 스플래시(라이트·다크) = Koreatimes
- [ ] 제안 카드 클릭 → 입력란만 채워지고 자동 전송되지 않음
- [ ] **버전 표시가 `v0.12.3`이고 `(build · …)` 접미사가 없다** (`BUILD_CHANNEL=main`)

### 7.4 Functional smoke

- [ ] 기본 모델에 메시지 전송 → 응답 수신
- [ ] 저장되는 새 채팅에서 제목 자동 생성 후 로그에 `KeyError`·`Traceback` 없음 (#47). 배포 직후 로그를 `> file 2>&1`로 수집해 스캔한다.
- [ ] 소형 텍스트 문서 업로드 후 질의 → 인용 포함 응답(RAG)
- [ ] Workspace → Models/Tools/Functions/Skills 목록 로드 시 오류 없음
- [ ] **스킬이 연결된 모델로 메시지를 보내 응답을 받는다.** 응답 지연·토큰 사용 증가가 허용 범위인지 소유자가 판단한다(§2 스킬 동작 변경).
- [ ] 채널 화면: 채널이 있으면 기존 멤버·메시지가 보이고 메시지 전송 후 새로고침해도 유지된다.
- [ ] 사이드바 검색(Workspace search)이 열리고 결과가 나온다.
- [ ] 관리자 설정에서 **Encrypted channels가 꺼진 상태**이고 Apps가 꺼진 상태다.
- [ ] Pipelines 연결 상태는 §3.7 결정에 따른다

---

## 8. Rollback procedure

**트리거:** §6 금지 로그 출현, `/health`가 자원 병목으로 설명되지 않는 이유로 비정상, §7.1이 전 사용자 로그인을 막음, §7.2 무결성 실패 또는 항목 개수 손실, §7.4 제목 생성 `KeyError` 재발.

workflow는 컨테이너 기동 **이전** 실패에만 이전 서비스를 자동 복구한다. 기동 이후 실패는 **자동 롤백하지 않고** 컨테이너·로그·DB·백업을 보존한 채 관리자 판단을 기다린다. 판단 전에 아무것도 삭제·덮어쓰지 않는다.

### 8.1 이미지 롤백 (이번 릴리스의 1차 경로, 미시험)

이번 릴리스는 스키마를 바꾸지 않으므로 `v0.12.2-kwh.1` 이미지는 현재 revision(`0bd252b206fb`)을 알고 있다. 따라서 이미지만 되돌리는 것이 가능할 것으로 예상하나 **이 동작을 실제로 시험하지 않았다.** 새 이미지가 기동 중 `config` 테이블에 추가한 기본값 행이 이전 이미지에 영향을 주는지도 확인하지 않았다.

1. 컨테이너를 정지하고 현 상태(DB·로그)를 별도로 보존한다.
2. `OPENWEBUI_IMAGE_TAG`를 §3.3에서 기록한 이전 태그(기대 `v0.12.2-kwh.1`)로 두고 `up -d --no-deps openwebui` → 로그·`/health`.
3. 기동에 실패하거나 §7.2가 깨지면 8.2로 간다.

### 8.2 Full 롤백 (이미지 + 백업 복원)

1. 컨테이너를 정지하고 현 상태(DB·로그)를 별도로 보존한다.
2. §4 백업 아카이브(`prod-backup-preupgrade-…-v0.12.2-kwh.1.tar.gz`)로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`는 아카이브에 없다. 변경하지 않았다면 그대로 두고, 의심되면 §4의 `0600` 사본과 대조한다(내용을 출력하지 않는다).
4. 이전 태그로 `up -d --no-deps openwebui` → 로그·`/health`.
5. 복원 후 §7.2로 데이터 개수를 확인한다.

**한계:** 실제 배포 백업 tar의 복원은 증명되지 않았다. 백업 시점 이후의 채팅·설정은 사라진다. 승인자에게 이를 알린 뒤 진행한다.

동일 태그를 재빌드·덮어쓰지 않는다. 수정은 `v0.12.3-kwh.2`로 발행한다.

---

## 9. Evidence summary (개발 측)

| 항목                           | 결과               | 비고                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------ | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 병합                           | PASS               | 텍스트 충돌 0건. `insertSuggestionPrompt ?? true`·`WEBUI_NAME` 접미사 제거·Dockerfile `NODE_OPTIONS` 유지를 병합 직후 확인. 마이그레이션 변경 0건                                                                                                                                                                                                                                                   |
| PR #64 CI                      | PASS               | 2026-10-19 Format & Build, Unit Tests, Ruff Format(3.11·3.12), Result 등 6건 통과, `mergeStateStatus` `CLEAN`. 이번 사이클에 개발 머신에서 `npm ci`·vitest·`svelte-check`·ruff를 **별도로 실행하지 않았다**                                                                                                                                                                                         |
| RC 자동 게이트                 | PASS               | 2026-10-19 `./scripts/local-test.sh v0.12.3-kwh.1-rc.1 --allow-rc`. 부팅 138초, `/health` 200, upgrade 0건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, pipelines 응답. ERROR 2건은 #48과 동일                                                                                                                                                                                      |
| RC 브라우저 검증               | PASS (사용자 확인) | 2026-10-19 소유자가 로컬 RC 게이트 인스턴스에서 프로덕션 미러 체크리스트를 수행하고 "확인 끝났다"고 보고했다. 항목별 결과는 기록되지 않았으며 자동화 증거가 아닌 사용자 보고다                                                                                                                                                                                                                      |
| 최종 태그 이미지 게이트        | PASS (자동)        | 2026-10-19 `./scripts/local-test.sh v0.12.3-kwh.1`. 부팅 198초, upgrade 0건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, pipelines 응답. 기동 후 `/api/config` `Koreatimes 0.12.3`, `/_app/version.json` = `5d83d91cc…`, `/manifest.json` `name`·`short_name` = `Koreatimes`, 로그 `Traceback`·`KeyError`·`IntegrityError` 0건. 최종 이미지로 브라우저 체크리스트는 수행하지 않았다 |
| 마이그레이션 데이터 보존       | 해당 없음          | 마이그레이션이 없다. 합성 데이터 시험을 하지 않았다                                                                                                                                                                                                                                                                                                                                                 |
| 프로덕션 스냅샷 리허설         | 미수행             | 소유자 결정(배포 요청 Issue 전에 확정). 스키마 변경이 없어 위험은 작지만 수행하지 않았다                                                                                                                                                                                                                                                                                                            |
| 이미지 롤백·백업 복원          | 미시험             | §4, §8. 실제 배포 백업 tar의 복원은 증명되지 않았다                                                                                                                                                                                                                                                                                                                                                 |
| 프로덕션 Pipelines             | 소유자 결정        | §3.7. 배포 요청 Issue에서 `check_pipelines` 값을 확정한다                                                                                                                                                                                                                                                                                                                                           |
| 스킬 동작 변경의 프로덕션 영향 | 미검증             | §2, §3.6-2. 프로덕션 모델·스킬 연결 현황을 확인하지 않았다                                                                                                                                                                                                                                                                                                                                          |

RC 결과를 최종 태그 이미지의 PASS로 대체하지 않는다. 최종 게이트는 최종 이미지에 대해 별도로 수행했다.

### 게이트 로그의 ERROR (관측)

- `get_tool_server_data` / `get_tool_servers_data` 2건: 도구 서버 `fastapi-tools-v2:8000` DNS 실패. [Issue #48](https://github.com/kwh8121/openwebui-service/issues/48)과 동일하며 릴리스 무관(수용·무변경 결정). 최종 태그 게이트 로그에서 ERROR 2건 모두 이 내용임을 확인했다.

---

## Appendix. workflow 대조 결과

deploy workflow(`.github/workflows/deploy-approved-production-release.yaml`)의 마지막 변경 커밋은 `44c3db7ac`(2026-10-08)이며 이번 릴리스에서 바뀌지 않았다. `v0.12.0-kwh.1` 가이드의 대조 표가 그대로 유효하다. 배포 에이전트는 dispatch 전에 `guide_commit` 시점의 workflow와 그 표를 한 번 더 대조한다.
