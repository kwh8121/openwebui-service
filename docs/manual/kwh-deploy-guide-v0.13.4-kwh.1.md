# Production Deployment Guide — `v0.13.4-kwh.1`

이 문서는 `v0.13.4-kwh.1`의 릴리스별 실행·판정 기준이다. 정상 배포 경로는
[`Deploy approved production release`](../../.github/workflows/deploy-approved-production-release.yaml) workflow다.
수동 fallback의 공통 명령은 [v0.11.3 가이드](./kwh-deploy-guide-v0.11.3-kwh.1.md)를 참조하되,
태그·digest·판정 기준은 이 문서를 적용한다. 운영 상태는 dispatch 직전에 다시 조회한다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) →
[CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) →
[릴리스 루틴](./kwh-release-routine.md) → 이 가이드.

## 1. Release identifiers

| 항목                              | 값                                                                                                      |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Version                           | `v0.13.4-kwh.1`                                                                                         |
| Main tip SHA / annotated tag 대상 | `808f23b6f26bbce801fe293ac07c0ae30cad88fc`                                                              |
| GHCR 배포 이미지                  | `ghcr.io/kwh8121/openwebui-service:v0.13.4-kwh.1`                                                       |
| OCI index digest                  | `sha256:e8f263ef2febc7b2f00fa2d4d0d210fbdb4db3e77865bccddec166da45f93d27`                               |
| linux/amd64 manifest digest       | `sha256:4ae7e4c90d672def6442070f436cd175cafb01fced35d28b7c5af59cddae9e50`                               |
| Git-SHA parity tag                | `ghcr.io/kwh8121/openwebui-service:git-808f23b` (dispatch 전 digest 일치 재확인)                        |
| GH Actions build                  | `https://github.com/kwh8121/openwebui-service/actions/runs/45097636973` (success, head SHA 일치)        |
| RC                                | `v0.13.4-kwh.1-rc.1` PASS, 배포 대상 아님                                                               |
| Base upstream                     | Open WebUI `v0.13.4`                                                                                    |
| Fork carryovers                   | Koreatimes 브랜드, `WEBUI_NAME` 접미사 제거, 추천 프롬프트 기본값, fork workflow, middleware guard 보존 |
| Rollback 후보                     | `v0.13.3-kwh.1` per Issue #74. §3에서 실제 운영 이미지 태그·digest를 재조회해 확정                      |

최종 태그와 parity 태그의 OCI index digest를 로컬에서 대조한다. 프로덕션에서도 dispatch 전에
`RepoDigests`를 확인한다. `main`, `latest`, RC 태그는 배포 대상이 아니다.

## 2. Deployment overview

배포 대상은 공식 upstream `v0.13.4`를 fork에 통합한 이미지다. 변경 상세는
[upstream 변경 참고](../references/openwebui-v0.13.4-release-notes.md)를 따른다.
Tether가 기존 Direct Connections/Integrations를 대체한다. Terminals 서버는 0.4.0 이상이 필요하고,
기존 0.3.x 연결은 수동 마이그레이션 대상이다. 코딩 에이전트 모델 ID가 바뀌며,
첫 기동은 기존 이미지 생성·편집 설정을 image connection으로 전환한다.

**신규 Alembic 마이그레이션은 0건.** 기대 시작·종료 revision은 `9f6c2a8d1b43`이다.
DB 스키마 migration이 없더라도 앱 수준 이미지 설정 전환이 있을 수 있으므로 §4 백업을 생략하지 않는다.
운영 설정·연결의 실효 상태는 로컬에서 확인할 수 없으며 §3과 §7에서 직접 확인한다.

Koreatimes 브랜드 자산, `insertSuggestionPrompt ?? true`, `WEBUI_NAME` 접미사 제거,
fork 전용 Docker·배포 workflow, 완료된 assistant turn 메모리 guard를 통합 diff에서 보존했다.
배포 시 Pipelines 이미지와 OAuth env 구조는 변경하지 않고 `openwebui`만 교체한다.

## 3. Prerequisites verification

workflow의 `Validate deploy environment`와 [v0.11.3 가이드 §3](./kwh-deploy-guide-v0.11.3-kwh.1.md)을 적용한다.
프로덕션 에이전트는 dispatch 전에 다음을 Issue에 기록한다.

1. 현재 컨테이너의 실행 상태, immutable 이미지 태그·digest. Issue #74의 마지막 성공 배포는
   `v0.13.3-kwh.1`이지만 실제 관측값을 롤백 기준으로 삼는다. 다르면 중단해 재평가한다.
2. 실행 중 컨테이너의 `alembic current`가 `9f6c2a8d1b43`인지. 다르면 중단해 migration 기대를 다시 계산한다.
3. 최종 태그와 `git-808f23b`의 OCI index digest가 §1과 같은지.
4. compose project `openwebui`, GHCR 인증, `.env.openwebui.oauth`, 데이터 bind mount,
   `/app/pipelines`와 백업 대상의 존재·읽기 권한, 이미지·백업·설정 전환을 감당할 디스크 여유.
5. `ENABLE_DB_MIGRATIONS`가 미설정 또는 기본 `True`인지. `false`이면 배포 중단.
6. 사용자·채팅·Model·Tool·Function·Skill·Knowledge·Prompt·채널·메시지 개수,
   사용 중인 이미지 연결·Terminals 서버 버전·Tether/코딩 에이전트 설정의 기준 상태.

OAuth credential, API key, cookie, DB 내용은 출력하지 않는다. PersistentConfig 실효값은 env와
다를 수 있으므로 관리자 설정에서 확인한다.

**Pipelines 분기:** dispatch 직전 컨테이너와 `http://127.0.0.1:9099/openapi.json`을 확인한다.
실행 중이고 API가 200이면 `check_pipelines=true`, §7.4·§9에서 PASS/FAIL을 기록한다.
미기동 또는 API 실패면 원인과 의도 여부를 Issue에 기록하고, 의도적으로 제외할 때만
`check_pipelines=false`로 dispatch하며 §7.4·§9를 **SKIPPED**로 기록한다. SKIPPED는 통과가 아니다.
배포 과정에서 Pipelines를 새로 기동하거나 재생성하지 않는다.

## 4. Pre-deployment backup — MANDATORY

신규 Alembic revision은 없지만 이미지 설정의 앱 수준 전환이 있으므로 이번 배포 직전 백업이 필요하다.
workflow는 이미지 pull 뒤 `openwebui`를 정지하고 SQLite WAL이 닫힌 상태에서 데이터와
`/app/pipelines`를 tar로 백업한다. env 파일은 owner-only 사본으로 따로 보존한다.
백업 경로·크기·mode와 `tar -tzf` 검사 결과를 Issue에 기록한다. 실패하면 새 이미지를 기동하지 않는다.
수동 fallback에서는 [v0.11.3 가이드 §4](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 WAL-safe 순서를 따른다.

## 5. Deployment execution

배포 요청 Issue와 GitHub `production` Environment가 승인된 뒤 프로덕션 에이전트가 workflow를 dispatch한다.

| 입력              | 값                                                   |
| ----------------- | ---------------------------------------------------- |
| `tag`             | `v0.13.4-kwh.1`                                      |
| `issue_number`    | 이 릴리스의 Production deployment request Issue 번호 |
| `guide_commit`    | Issue가 참조한 이 가이드 포함 `main` 전체 SHA        |
| `check_pipelines` | §3의 실제 관측 결과에 따른 `true` 또는 `false`       |

수동 fallback이 필요한 경우에만 [v0.11.3 가이드 §5.2](./kwh-deploy-guide-v0.11.3-kwh.1.md)의
env export → `compose config` dry-run → pull → `up -d --no-deps openwebui` 순서를 적용한다.
`OPENWEBUI_IMAGE_TAG=v0.13.4-kwh.1`이며 다른 서비스는 교체하지 않는다.

## 6. Migration monitoring

예상 `Running upgrade`는 **0건**이다. 기동 로그의 Alembic SQLite context 뒤
`Application startup complete`, `/health` 200, `/_app/version.json` = §1 SHA,
`alembic current = 9f6c2a8d1b43`을 확인한다. 이미지 연결 전환 관련 오류도 확인한다.
다른 revision, 예상 밖의 upgrade, `Can't locate revision`, `Generating new WEBUI_SECRET_KEY`,
`Traceback`, `sqlalchemy.exc`, `IntegrityError`, `OperationalError`, `ModuleNotFoundError`가 나오면
중단하고 §8을 따른다. workflow의 `/health` 제한은 300초다. 시간이 초과되면 로그,
CPU·메모리·디스크 I/O, 저장된 Function 의존성 설치 진행을 확인하고 임의로 재시작하지 않는다.

## 7. Post-deployment smoke checklist

아래 브라우저 검수는 요청 시점에 **pending**이다. 기술 배포 PASS와 관리자 acceptance를 구분한다.

### 7.1 Authentication

- [ ] Google OAuth 로그인, 새로고침 후 세션 지속, 로그아웃
- [ ] 기존 세션과 로그인 폼·관리자 설정의 실효 상태

### 7.2 Data integrity

- [ ] `alembic current = 9f6c2a8d1b43`, SQLite integrity check = `ok`
- [ ] §3의 사용자·채팅·리소스·채널 개수와 기존 자료 유지 여부 비교
- [ ] 기존 이미지 생성·편집 설정이 image connection으로 전환됐는지, 권한·실제 생성 동작 확인

### 7.3 Fork carryovers

- [ ] 로고·스플래시·favicon·manifest와 인스턴스명 `Koreatimes`, `(Open WebUI)` 접미사 없음
- [ ] 추천 프롬프트 카드는 입력란만 채우고 자동 전송하지 않음
- [ ] UI 버전 `v0.13.4`, `/_app/version.json` = §1 SHA
- [ ] fork Docker·배포·local-test workflow가 upstream 변경으로 대체되지 않았는지 확인

### 7.4 Functional smoke

- [ ] 기본 모델 대화·제목 생성, 기존 채팅, 새 채팅·탭·사이드 채팅·큐 메시지
- [ ] 작은 문서 업로드 후 RAG 응답과 인용
- [ ] Workspace Model/Tool/Function/Skill/Knowledge/Prompt 목록, 기존 채널 메시지·멤버
- [ ] 기존 Pipe와 도구 연결, HTTP 접속에서 댓글·Markdown 편집
- [ ] Pipelines: §3에서 `true`면 API·연결 PASS/FAIL, `false`면 SKIPPED와 사유

### 7.5 v0.13.4 version-specific spot check

- [ ] 기존 Direct Connections/Integrations를 쓰던 사용자의 Tether 재연결·권한 확인
- [ ] Terminals 서버가 구성돼 있으면 0.4.0 이상 및 기존 모델·폴더·자동화·채팅 연결 확인
- [ ] 코딩 에이전트 모델 ID와 기존 채팅의 첫 후속 메시지 처리 확인
- [ ] 이미지 connection 전환, 기존 생성·편집 설정과 동작 확인
- [ ] 대형 채팅에서 터미널 패널을 쓰면 응답 시간과 DB 연결 상태 확인 (upstream #34646)

구성되지 않은 기능은 SKIPPED, 관찰하지 못한 항목은 UNVERIFIED로 남긴다.

## 8. Rollback procedure

인증 장애, 데이터 손실, 건강 상태 불량, 핵심 스모크 실패 시 변경을 멈추고 Issue에 기록한다.
workflow는 새 컨테이너 기동 **전** 실패만 이전 서비스를 자동 복구한다. 기동 후에는 데이터를
보존하고 관리자 판단을 기다린다.

### 8.1 이미지 롤백 — 데이터 전환 전까지만 가능

새 이미지가 기동되지 않았거나 이미지 설정 전환과 DB 쓰기가 없었다는 증거가 있을 때만
§3의 실제 이전 태그·digest로 이미지 롤백을 검토한다. 예상 후보는 `v0.13.3-kwh.1`이다.
`openwebui`만 이전 이미지로 올리고 §7.1~§7.3을 다시 확인한다.

### 8.2 Full 롤백 — 데이터 전환 후 기본 복구 경로

Alembic revision이 같아도 이미지 설정 데이터가 전환된 뒤에는 이미지 교체만으로 이전 동작이
복구된다고 가정하지 않는다. 관리자 명시 승인 후 검증된 §4 백업으로 복구한다.

1. 컨테이너를 정지하고 실패 상태의 DB·로그·업로드·pipelines를 별도 위치에 보존한다.
2. §4 아카이브로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`를 owner-only 사본과 대조하되 내용을 출력하지 않는다.
4. §3의 실제 이전 태그로 `OPENWEBUI_IMAGE_TAG`를 설정하고 `up -d --no-deps openwebui`를 실행한다.
5. `/health`, `alembic current`, SQLite integrity, §7.2의 데이터 개수를 확인한다.

백업 시점 이후 데이터는 사라진다.

### 8.3 Failed-upgrade 디렉터리 보존

실패한 새 이미지의 데이터와 로그를 보존하고 기존 백업을 덮어쓰지 않는다. 같은 immutable 태그를
재빌드하지 않는다. 수정 릴리스는 새 `-kwh.2` 태그를 쓴다.

## 9. Success markers to record

프로덕션 에이전트는 Issue에 시작·종료 UTC, 이전 이미지 태그·digest·상태, 새 이미지 digest,
백업 경로·크기·권한·`tar -tzf` 검사, `Running upgrade` 0건과 최종 revision,
`/health` 200 도달 시각, version SHA, 브랜드, §7 항목별 PASS/FAIL/SKIPPED/UNVERIFIED,
Pipelines 분기와 workflow URL을 기록한다. 관리자 브라우저 acceptance는 별도 코멘트까지 pending이다.

개발 측 증적: PR #76 CI PASS; RC.1 로컬 게이트 PASS (105초, upgrade 0건,
Alembic current=heads `9f6c2a8d1b43`, SQLite integrity `ok`, Pipelines API 200);
새 RC 이미지의 백엔드 pytest 4건 PASS. 최종 GHCR [build run 45097636973](https://github.com/kwh8121/openwebui-service/actions/runs/45097636973) PASS,
최종 태그 로컬 게이트 PASS (자동 백업, `/health` 200까지 55초, 이번 부팅 upgrade 0건,
Alembic current=heads `9f6c2a8d1b43`, SQLite integrity `ok`, Pipelines API 200).
RC에서 미인증 브라우저 로그인 화면·Koreatimes title과 console error 0건을 확인했다.
OAuth 로그인, 모델 대화, RAG, Tether, Terminals, 이미지 생성은 로컬에서 미검증이다.
로컬 미러의 기존 `fastapi-tools-v2:8000` DNS 오류 2건은 운영 Tool 서버 상태의 증거가 아니다.

## Appendix A. Environment variable reference

| 변수                                                                         | 값 또는 판정                                                    |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `OPENWEBUI_IMAGE_TAG`                                                        | 배포 `v0.13.4-kwh.1`; 롤백은 §3의 실제 이전 태그                |
| `OPENWEBUI_LOCAL_DATA`                                                       | `/home/ubuntu/openwebui/openwebui` (운영에서 재확인)            |
| `OPENWEBUI_DEPLOY_ENV_FILE`                                                  | `/home/ubuntu/openwebui/.env.openwebui.oauth` (운영에서 재확인) |
| `PIPELINES_LOCAL_DATA`                                                       | `/app/pipelines` (운영에서 재확인)                              |
| `WEBUI_NAME`                                                                 | `Koreatimes` 예상; PersistentConfig 실효값 확인                 |
| `ENABLE_OAUTH_SIGNUP`, `ENABLE_OAUTH_PERSISTENT_CONFIG`, `ENABLE_LOGIN_FORM` | 운영 env와 실효값 확인; 비밀값 출력 금지                        |
| `ENABLE_DB_MIGRATIONS`                                                       | 미설정/기본 `True` 필요; `false`이면 중단                       |
| `ENABLE_TOOLS`, `ENABLE_FUNCTIONS`, `ENABLE_TOOL_SERVERS`                    | 운영의 실효 설정과 기존 연결 확인                               |
| `ENABLE_PERSISTENT_CONFIG`                                                   | image connection 전환 후 이미지 관련 env 무시 여부 확인         |
| `ENABLE_MFA`, `ENABLE_SKILL_LAZY_LOADING`, `UI_VISIBILITY`                   | 기존 운영 설정 유지 확인                                        |

compose project는 `openwebui`로 명시한다. OAuth credential과 API key를 문서·Issue에 적지 않는다.

## Appendix B. External references

1. [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md)
2. [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md)
3. [릴리스 루틴](./kwh-release-routine.md)
4. [이전 릴리스 가이드](./kwh-deploy-guide-v0.13.3-kwh.1.md)
5. [upstream v0.13.4 변경 참고](../references/openwebui-v0.13.4-release-notes.md)
6. Issue #74 — 마지막 완료된 production 배포 증적
7. PR #76 — `integration/v0.13.4` to `main` 통합 증적
