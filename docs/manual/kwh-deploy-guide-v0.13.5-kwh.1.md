# Production Deployment Guide — `v0.13.5-kwh.1`

이 문서는 `v0.13.5-kwh.1`의 릴리스별 실행·판정 기준이다. 정상 배포 경로는
[`Deploy approved production release`](../../.github/workflows/deploy-approved-production-release.yaml) workflow다.
수동 fallback의 공통 명령은 [v0.11.3 가이드](./kwh-deploy-guide-v0.11.3-kwh.1.md)를 참조하되,
태그·digest·판정 기준은 이 문서를 적용한다. 운영 상태는 dispatch 직전에 다시 조회한다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) →
[CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) →
[릴리스 루틴](./kwh-release-routine.md) → 이 가이드.

> **이번 릴리스의 핵심 위험**: 첫 기동 때 모든 채팅의 대화 기록을 `chat_message` 테이블로 옮긴다.
> 구·신 형식이 호환되지 않으므로 **데이터 변환 뒤에는 이미지 롤백만으로 되돌릴 수 없고 §4 백업 복원이 필요하다.**
> 변환 시간은 운영 채팅 양에 비례하므로 `health_timeout_seconds=1800`으로 dispatch한다(§5).

## 1. Release identifiers

| 항목                              | 값                                                                                                         |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Version                           | `v0.13.5-kwh.1`                                                                                            |
| Main tip SHA / annotated tag 대상 | `57306ccec5673b601f22449e29442c32425027ea` (PR #83 merge commit)                                           |
| GHCR 배포 이미지                  | `ghcr.io/kwh8121/openwebui-service:v0.13.5-kwh.1`                                                          |
| OCI index digest                  | `sha256:b06d11747a37b6ddd114cdc214873a106db74aabbf7b22b63057d01a15720d1a`                                  |
| linux/amd64 manifest digest       | `sha256:2de40499a13788ed46ad59a8e21453f8c4a41a6510d8845d0a9d4f556a592f12`                                  |
| Git-SHA parity tag                | `ghcr.io/kwh8121/openwebui-service:git-57306cc` (dispatch 전 digest 일치 재확인)                           |
| GH Actions build                  | `https://github.com/kwh8121/openwebui-service/actions/runs/45738277963` (success, head SHA 일치)           |
| RC                                | `v0.13.5-kwh.1-rc.2` PASS. `rc.1`은 fork guard 실패로 폐기. 둘 다 배포 대상 아님                           |
| Base upstream                     | Open WebUI `v0.13.5`                                                                                       |
| Fork carryovers                   | Koreatimes 브랜드, `WEBUI_NAME` 접미사 제거, 추천 프롬프트 기본값, fork workflow, middleware guard, KOR-71 |
| Rollback 후보                     | `v0.13.3-kwh.1` per Issue #74 (+ §4 백업 복원). §3에서 실제 운영 태그·digest를 재조회해 확정               |

`v0.13.4-kwh.1`(Issue #78)은 배포되지 않았고 이 릴리스로 대체된다. `v0.13.4-kwh.2`는 `main` 병합만 했고 태그·배포가 없다.
최종 태그와 parity 태그의 OCI index digest를 로컬에서 대조했다. 프로덕션에서도 dispatch 전에
`RepoDigests`를 확인한다. `main`, `latest`, RC 태그는 배포 대상이 아니다.

## 2. Deployment overview

배포 대상은 공식 upstream `v0.13.5`를 fork에 통합한 이미지다. 마지막 운영 릴리스 `v0.13.3-kwh.1` 이후의
`v0.13.4` 변경도 함께 들어간다. 상세는 [v0.13.5 변경 참고](../references/openwebui-v0.13.5-release-notes.md)와
[v0.13.4 변경 참고](../references/openwebui-v0.13.4-release-notes.md)를 따른다.

- **v0.13.4 누적분**: Tether가 Direct Connections/Integrations를 대체, Terminals 0.4.0 이상 필요,
  코딩 에이전트 모델 ID 변경, 첫 기동 시 이미지 생성·편집 설정의 image connection 전환.
- **v0.13.5**: 채팅 메시지 저장 방식 변환, Terminals → Machines 이름 변경(권한 유지, 기존 env 이름도 동작),
  Arena → 무작위 router 전환, Docling job 방식, OpenAI 연결의 Responses API 기본값, 채널 자동화 답글 스레드화,
  RAG 인용 프롬프트 변경.
- **fork 수정 KOR-71 (GitHub #81)**: Pyodide 브라우저 파일(`sandbox:`, `/mnt/`)을 채팅에서 표시하려 할 때
  로고 대신 Files 탭 안내를 보여주고, `display_file`이 실패 이유를 돌려준다.

**신규 Alembic revision 4개.** 기대 시작 revision은 `9f6c2a8d1b43`, 종료 revision은 `5e7a2c9d4b13`이다.

| 순서 | revision       | 내용                                                          |
| ---- | -------------- | ------------------------------------------------------------- |
| 1    | `c4e1a7d93b20` | access grant 타입 `terminal` → `machine`                      |
| 2    | `b7d4f1a2c960` | `resource_tag` 테이블 신설, `note.folder_id`                  |
| 3    | `d2f86c0b41ae` | 사용자별 폴더 보기 상태                                       |
| 4    | `5e7a2c9d4b13` | 채팅 대화 기록을 `chat_message` 행으로 이동 (배치, 재개 가능) |

배포 시 Pipelines 이미지와 OAuth env 구조는 변경하지 않고 `openwebui`만 교체한다.

## 3. Prerequisites verification

workflow의 `Validate deploy environment`와 [v0.11.3 가이드 §3](./kwh-deploy-guide-v0.11.3-kwh.1.md)을 적용한다.
프로덕션 에이전트는 dispatch 전에 다음을 Issue에 기록한다.

1. 현재 컨테이너의 실행 상태, immutable 이미지 태그·digest. 예상값은 `v0.13.3-kwh.1`(Issue #74)이며,
   실제 관측값을 롤백 기준으로 삼는다. 다르면 중단해 재평가한다.
2. 실행 중 컨테이너의 `alembic current`가 `9f6c2a8d1b43`인지. 다르면 중단해 migration 기대를 다시 계산한다.
3. 최종 태그와 `git-57306cc`의 OCI index digest가 §1과 같은지.
4. compose project `openwebui`, GHCR 인증, `.env.openwebui.oauth`, 데이터 bind mount,
   `/app/pipelines`와 백업 대상의 존재·읽기 권한. **디스크 여유는 `webui.db` 크기의 3배 이상**
   (백업 + 변환 중 `chat_message` 증가분 + 이미지).
5. `ENABLE_DB_MIGRATIONS`가 미설정 또는 기본 `True`인지. `false`이면 배포 중단.
6. 사용자·채팅·Model·Tool·Function·Skill·Knowledge·Prompt·채널·메시지 개수와 `webui.db` 크기.
   **채팅 수와 채팅 메시지 총수**(`chat.chat` JSON의 `history.messages` 합)를 반드시 기록한다. §7.2의 변환 검증 기준이다.
7. 사용 중인 이미지 연결, Terminals 서버 버전, Arena 모델, Docling, OpenAI 연결의 API 종류, 채널 자동화의 기준 상태.
8. 실행 중인 Open WebUI가 **한 개**인지(worker·replica 포함). upstream은 구·신 버전 혼재를 금지한다.

OAuth credential, API key, cookie, DB 내용은 출력하지 않는다. PersistentConfig 실효값은 env와
다를 수 있으므로 관리자 설정에서 확인한다.

**Pipelines 분기:** dispatch 직전 컨테이너와 `http://127.0.0.1:9099/openapi.json`을 확인한다.
실행 중이고 API가 200이면 `check_pipelines=true`, §7.4·§9에서 PASS/FAIL을 기록한다.
미기동 또는 API 실패면 원인과 의도 여부를 Issue에 기록하고, 의도적으로 제외할 때만
`check_pipelines=false`로 dispatch하며 §7.4·§9를 **SKIPPED**로 기록한다. SKIPPED는 통과가 아니다.
배포 과정에서 Pipelines를 새로 기동하거나 재생성하지 않는다.

## 4. Pre-deployment backup — MANDATORY

이번 릴리스는 대화 기록 저장 형식을 바꾸는 **비가역 데이터 변환**이 있으므로 백업 없이는 진행하지 않는다.
workflow는 이미지 pull 뒤 `openwebui`를 정지하고 SQLite WAL이 닫힌 상태에서 데이터와
`/app/pipelines`를 tar로 백업한다. env 파일은 owner-only 사본으로 따로 보존한다.
백업 경로·크기·mode와 `tar -tzf` 검사 결과를 Issue에 기록한다. 실패하면 새 이미지를 기동하지 않는다.
수동 fallback에서는 [v0.11.3 가이드 §4](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 WAL-safe 순서를 따른다.
배포가 종료·승인될 때까지 이 백업을 삭제하거나 덮어쓰지 않는다.

## 5. Deployment execution

배포 요청 Issue와 GitHub `production` Environment가 승인된 뒤 프로덕션 에이전트가 workflow를 dispatch한다.

| 입력                     | 값                                                   |
| ------------------------ | ---------------------------------------------------- |
| `tag`                    | `v0.13.5-kwh.1`                                      |
| `issue_number`           | 이 릴리스의 Production deployment request Issue 번호 |
| `guide_commit`           | Issue가 참조한 이 가이드 포함 `main` 전체 SHA        |
| `check_pipelines`        | §3의 실제 관측 결과에 따른 `true` 또는 `false`       |
| `health_timeout_seconds` | **`1800`**                                           |

`health_timeout_seconds`는 2026-11-26에 추가된 입력이다(기본 300, 60~3600). 로컬 미러에서 채팅 10개 변환은 2초였으나,
기동에는 Function 의존성 설치도 포함되므로 여유를 둔다. §3의 채팅 메시지 총수가 매우 크면(예: 수십만 건)
3600으로 올리고 근거를 Issue에 적는다.

수동 fallback이 필요한 경우에만 [v0.11.3 가이드 §5.2](./kwh-deploy-guide-v0.11.3-kwh.1.md)의
env export → `compose config` dry-run → pull → `up -d --no-deps openwebui` 순서를 적용한다.
`OPENWEBUI_IMAGE_TAG=v0.13.5-kwh.1`이며 다른 서비스는 교체하지 않는다.

## 6. Migration monitoring

예상 `Running upgrade`는 **4건**(§2 순서)이며 마지막은 `d2f86c0b41ae -> 5e7a2c9d4b13`이다.
변환 중에는 `Migration progress: moved the messages of N chats into chat_message` 로그가 배치 단위로 나온다.
이 로그의 N이 늘어나는 동안은 정상 진행으로 본다.

이후 `Application startup complete`, `/health` 200, `/_app/version.json` = §1 SHA,
`alembic current = 5e7a2c9d4b13`을 확인한다.
다른 revision, 예상 밖의 upgrade, `Can't locate revision`, `Generating new WEBUI_SECRET_KEY`,
`Traceback`, `sqlalchemy.exc`, `IntegrityError`, `OperationalError`, `ModuleNotFoundError`가 나오면
중단하고 §8을 따른다.

**`/health` 시간 초과 시**: workflow는 실패로 끝나지만 컨테이너는 정지하지 않는다. **재시작하지 않는다.**
변환은 배치로 실행되고 중단 뒤 재개할 수 있지만, 재시작은 진행을 늦출 뿐이다. 로그의 진행 메시지,
CPU·메모리·디스크 I/O, Function 의존성(`pip install`) 진행을 확인하고 Issue에 기록한 뒤 관리자 판단을 기다린다.
변환이 끝나고 `/health` 200이 되면 §7을 수동으로 수행해 기술 PASS 여부를 판정한다.

## 7. Post-deployment smoke checklist

아래 브라우저 검수는 요청 시점에 **pending**이다. 기술 배포 PASS와 관리자 acceptance를 구분한다.

### 7.1 Authentication

- [ ] Google OAuth 로그인, 새로고침 후 세션 지속, 로그아웃
- [ ] 기존 세션과 로그인 폼·관리자 설정의 실효 상태

### 7.2 Data integrity

- [ ] `alembic current = 5e7a2c9d4b13`, SQLite integrity check = `ok`
- [ ] **`chat` 수가 §3과 같고, `chat_message` 행 수가 §3의 채팅 메시지 총수와 같음**
- [ ] 오래된 채팅과 긴 채팅을 열어 메시지·분기·첨부가 유지되는지, 이어서 답할 수 있는지
- [ ] §3의 사용자·리소스·채널 개수와 기존 자료 유지 여부
- [ ] 기존 이미지 생성·편집 설정의 image connection 전환과 권한(v0.13.4 누적분)

### 7.3 Fork carryovers

- [ ] 로고·스플래시·favicon·manifest와 인스턴스명 `Koreatimes`, `(Open WebUI)` 접미사 없음
- [ ] 추천 프롬프트 카드는 입력란만 채우고 자동 전송하지 않음
- [ ] UI 버전 `v0.13.5`, `/_app/version.json` = §1 SHA
- [ ] KOR-71: 코드 인터프리터(Pyodide)로 SVG를 `/mnt/uploads`에 만들게 하면 로고 대신
      "브라우저 코드 실행 환경에만 있어…" 안내가 보이고, 모델이 표시에 성공했다고 말하지 않는지(모델 의존, 관찰 기록)
- [ ] fork Docker·배포·local-test·fork guard workflow가 upstream 변경으로 대체되지 않았는지

### 7.4 Functional smoke

- [ ] 기본 모델 대화·제목 생성, 기존 채팅 이어쓰기, 새 채팅·탭·사이드 채팅·큐 메시지
- [ ] 작은 문서 업로드 후 RAG 응답과 인용(새 기본 프롬프트는 주장마다 출처 번호)
- [ ] Workspace Model/Tool/Function/Skill/Knowledge/Prompt 목록, 기존 채널 메시지·멤버
- [ ] 기존 Pipe와 도구 연결
- [ ] Pipelines: §3에서 `true`면 API·연결 PASS/FAIL, `false`면 SKIPPED와 사유

### 7.5 Version-specific spot check

- [ ] Terminals를 쓰던 경우 Machines 화면에서 연결·권한 유지 (v0.13.5)
- [ ] Arena 모델을 쓰던 경우 router 전환 결과 (v0.13.5)
- [ ] Docling을 쓰는 경우 문서 업로드 변환 (v0.13.5, job 방식)
- [ ] OpenAI 연결의 API 종류가 의도대로인지 (v0.13.5, 새 연결 기본 Responses API)
- [ ] 채널에 글을 올리는 자동화가 있으면 스레드 답글 여부 (v0.13.5)
- [ ] Tether 재연결, Terminals 0.4.0 이상, 코딩 에이전트 모델 ID (v0.13.4 누적분)

구성되지 않은 기능은 SKIPPED, 관찰하지 못한 항목은 UNVERIFIED로 남긴다.

## 8. Rollback procedure

인증 장애, 데이터 손실, 건강 상태 불량, 핵심 스모크 실패 시 변경을 멈추고 Issue에 기록한다.
workflow는 새 컨테이너 기동 **전** 실패만 이전 서비스를 자동 복구한다. 기동 후에는 데이터를
보존하고 관리자 판단을 기다린다.

### 8.1 이미지 롤백 — 새 컨테이너가 DB를 건드리기 전까지만

새 이미지가 기동되지 않았거나, 로그에 `Running upgrade`가 한 줄도 없다는 증거가 있을 때만
§3의 실제 이전 태그·digest로 이미지 롤백을 검토한다. **`Running upgrade`가 하나라도 실행됐다면
이 경로를 쓰지 않는다.** 이전 버전은 `chat_message` 형식을 읽지 못한다.

### 8.2 Full 롤백 — 마이그레이션 시작 후 유일한 복구 경로

관리자 명시 승인 후 검증된 §4 백업으로 복구한다.

1. 컨테이너를 정지하고 실패 상태의 DB·로그·업로드·pipelines를 별도 위치에 보존한다.
2. §4 아카이브로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`를 owner-only 사본과 대조하되 내용을 출력하지 않는다.
4. §3의 실제 이전 태그로 `OPENWEBUI_IMAGE_TAG`를 설정하고 `up -d --no-deps openwebui`를 실행한다.
5. `/health`, `alembic current = 9f6c2a8d1b43`, SQLite integrity, §3의 데이터 개수를 확인한다.

백업 시점 이후 데이터는 사라진다.

### 8.3 Failed-upgrade 디렉터리 보존

실패한 새 이미지의 데이터와 로그를 보존하고 기존 백업을 덮어쓰지 않는다. 같은 immutable 태그를
재빌드하지 않는다. 수정 릴리스는 새 `-kwh.2` 태그를 쓴다.

## 9. Success markers to record

프로덕션 에이전트는 Issue에 다음을 기록한다.

- 시작·종료 UTC, 이전 이미지 태그·digest·상태, 새 이미지 digest
- 백업 경로·크기·권한·`tar -tzf` 검사
- `Running upgrade` 4건과 최종 revision, **변환 시작·종료 시각과 소요 시간**, `health_timeout_seconds` 값
- `/health` 200 도달 시각, version SHA, 브랜드
- §3 대비 §7.2 채팅·메시지 수
- §7 항목별 PASS/FAIL/SKIPPED/UNVERIFIED, Pipelines 분기, workflow URL

관리자 브라우저 acceptance는 별도 코멘트까지 pending이다.

개발 측 증적:

- **CI**: PR #83의 체크 10건 모두 PASS(fork guard 2종 포함).
- **RC.2 로컬 게이트 PASS** (축적 데이터, 자동 백업):
  - upgrade 4건, 최종 head `5e7a2c9d4b13`
  - 채팅 10건 변환 2초, 변환 전 메시지 26건 = 변환 후 `chat_message` 26행
  - SQLite `ok`, Pipelines 200, 오류 로그 0건
  - 스크립트는 `/health` 1200초 초과로 `[FAIL]`을 표시했다. 원인은 개발 호스트 메모리 부족(swap 가득 참)으로 Function 의존성 설치가 디스크 대기에 걸린 것이다. 같은 컨테이너가 직후 healthy가 됐고 이미지 결함은 아니다.
- **RC.2 이미지 백엔드 pytest**: 4건 PASS.
- **최종 GHCR build**: [run 45738277963](https://github.com/kwh8121/openwebui-service/actions/runs/45738277963) PASS. 최종 태그와 `git-57306cc`의 OCI index digest가 로컬 `docker pull`에서 일치했다.
- **최종 태그 로컬 게이트 PASS** (RC.2로 이미 변환된 축적 데이터, 자동 백업): `/health` 200까지 815초, 이번 부팅 upgrade 0건, Alembic current=heads `5e7a2c9d4b13`, SQLite `ok`, `version.json` = §1 SHA, 브랜드 `Koreatimes`, Pipelines API 200. 로컬 미러의 `fastapi-tools-v2:8000` DNS 오류 2건은 기존과 같은 격리 환경 현상이다.
- **로컬 미검증**: OAuth 로그인, 모델 대화, RAG, Machines, Arena, Docling, 이미지 생성, 운영 규모 변환 시간.

## Appendix A. Environment variable reference

| 변수                                                                                                   | 값 또는 판정                                                    |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| `OPENWEBUI_IMAGE_TAG`                                                                                  | 배포 `v0.13.5-kwh.1`; 롤백은 §3의 실제 이전 태그 + §8.2 복원    |
| `OPENWEBUI_LOCAL_DATA`                                                                                 | `/home/ubuntu/openwebui/openwebui` (운영에서 재확인)            |
| `OPENWEBUI_DEPLOY_ENV_FILE`                                                                            | `/home/ubuntu/openwebui/.env.openwebui.oauth` (운영에서 재확인) |
| `PIPELINES_LOCAL_DATA`                                                                                 | `/app/pipelines` (운영에서 재확인)                              |
| `WEBUI_NAME`                                                                                           | `Koreatimes` 예상; PersistentConfig 실효값 확인                 |
| `ENABLE_OAUTH_SIGNUP`, `ENABLE_OAUTH_PERSISTENT_CONFIG`, `ENABLE_LOGIN_FORM`                           | 운영 env와 실효값 확인; 비밀값 출력 금지                        |
| `ENABLE_DB_MIGRATIONS`                                                                                 | 미설정/기본 `True` 필요; `false`이면 중단                       |
| `TERMINAL_*` → `MACHINE_*`                                                                             | 기존 이름도 동작. 이번 배포에서 바꾸지 않음                     |
| `ROUTER_MODELS`                                                                                        | env로만 Arena를 정의했다면 이전 필요 여부 확인                  |
| `TOOL_OUTPUT_MAX_CHARS`, `RAG_FULL_TEXT_THRESHOLD`, `AUTOMATION_MAX_CONCURRENT`, `SUBAGENTS_MAX_ASYNC` | v0.13.5 신규. 미설정이면 upstream 기본값                        |

compose project는 `openwebui`로 명시한다. OAuth credential과 API key를 문서·Issue에 적지 않는다.

## Appendix B. External references

1. [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md)
2. [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md)
3. [릴리스 루틴](./kwh-release-routine.md)
4. [이전 릴리스 가이드](./kwh-deploy-guide-v0.13.4-kwh.1.md) (미배포)
5. [upstream v0.13.5 변경 참고](../references/openwebui-v0.13.5-release-notes.md)
6. [KOR-71 승인 계획](../plan/2026-11-25-kor71-pyodide-display-guard.md), GitHub #81
7. Issue #74 — 마지막 완료된 production 배포 증적
8. Issue #78 — 이 릴리스로 대체되는 미실행 요청
9. PR #82, PR #83 — `main` 통합 증적
