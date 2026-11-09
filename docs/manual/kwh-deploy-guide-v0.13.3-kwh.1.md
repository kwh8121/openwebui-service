# Production Deployment Guide — `v0.13.3-kwh.1`

이 문서는 `v0.13.3-kwh.1` 프로덕션 배포의 릴리스별 명령·판정 기준이다.
정상 경로는 [`Deploy approved production release`](../../.github/workflows/deploy-approved-production-release.yaml)
workflow다. 공통 수동 fallback 절차는 [v0.11.3 가이드](./kwh-deploy-guide-v0.11.3-kwh.1.md)를
참조하되, 이 문서의 태그·digest·검증 기준으로 바꿔 적용한다. 프로덕션 상태는 배포 직전에 다시 조회한다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) →
[CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) →
[릴리스 루틴](./kwh-release-routine.md) → 이 가이드.

## 1. Release identifiers

| 항목                              | 값                                                                                                        |
| --------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Version                           | `v0.13.3-kwh.1`                                                                                           |
| Main tip SHA / annotated tag 대상 | `25afc16dc2c4c39ac7271c331fa2aff9ebadcdc1`                                                                |
| GHCR 배포 이미지                  | `ghcr.io/kwh8121/openwebui-service:v0.13.3-kwh.1`                                                         |
| OCI index digest                  | `sha256:f75f101cb58e3186b93115e499c69f571ab23c054d4b6e809c82c9e42ede493c`                                 |
| linux/amd64 manifest digest       | `sha256:b589d1447d596bee9c2f389d26662562aeefe7ea50ec11a4e5e2afb88960fd19`                                 |
| Git-SHA parity tag                | `ghcr.io/kwh8121/openwebui-service:git-25afc16` (dispatch 전에 digest 일치 재확인)                        |
| GH Actions build                  | `https://github.com/kwh8121/openwebui-service/actions/runs/42607439192`, success, head SHA 일치 확인 필요 |
| RC                                | `v0.13.3-kwh.1-rc.1` PASS; `v0.13.3-kwh.1-rc.2` PASS. 둘 다 배포 대상 아님                                |
| Base upstream                     | Open WebUI `v0.13.3` (공식 upstream 기준)                                                                 |
| Fork carryovers                   | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, 추천 프롬프트 자동 전송 방지, fork workflow 보존 확인   |
| Rollback 후보                     | `v0.12.4-kwh.1` per Issue #71. 실제 운영 이미지 태그·digest를 §3에서 재조회해 확정                        |

최종 태그와 `git-25afc16`을 로컬 `docker pull`한 결과 OCI index digest가 §1 값으로 일치했다. 프로덕션에서도 dispatch 전에 `RepoDigests`와 parity 태그 digest를 다시 확인한다. `main`, `latest`, RC 태그를
프로덕션에 배포하지 않는다.

## 2. Deployment overview

`v0.12.4-kwh.1`에서 공식 upstream `v0.13.3`으로 올린다. upstream 변경 참고는
`docs/references/openwebui-v0.13.3-release-notes.md`에 정리했다. 배포 판단은 이 가이드,
Production deployment request Issue, GitHub Actions 증적을 따른다.

**Alembic 신규 마이그레이션: 6건.** 운영 DB가 `0bd252b206fb`에서 시작한다는 전제에서 아래 순서로
`9f6c2a8d1b43`까지 올라간다.

| 순서 | revision       | 파일                            | 내용 및 운영 영향                                                |
| ---- | -------------- | ------------------------------- | ---------------------------------------------------------------- |
| 1    | `c41f8d9e2a10` | `add_resource_comments.py`      | `comment`, `comment_reaction` 테이블과 조회 인덱스 추가          |
| 2    | `6f8c2a91d4e7` | `add_tool_is_active.py`         | `tool.is_active` 컬럼 추가, 기본 `true`                          |
| 3    | `e42c8f710a36` | `add_notification_inbox.py`     | `notification` 테이블, unique/check constraint, 조회 인덱스 추가 |
| 4    | `8bc7e5a902d1` | `add_auth_session.py`           | 재생 가능한 인증 세션용 `auth_session` 테이블과 인덱스 추가      |
| 5    | `6a23bd107e54` | `add_chat_view_state.py`        | 사용자별 채팅 작업 뷰 상태 `chat_view_state` 테이블 추가         |
| 6    | `9f6c2a8d1b43` | `add_channel_lookup_indexes.py` | `message`, `message_reaction` 채널·부모·반응 조회 인덱스 추가    |

기동 로그에 `Running upgrade` 6줄이 나오는 것이 정상이다. 0줄, 6줄 미만, 다른 revision, 또는
`Can't locate revision`은 전제가 깨진 상태다. 모든 migration에 `downgrade()`는 있으나 운영에서
검증된 롤백 경로가 아니며, 이전 이미지가 새 revision을 이해한다고 가정하지 않는다.

이번 릴리스의 운영 점검 초점:

- 탭형 작업공간, 사이드 채팅, 관리자 분석, Responses API 경로.
- native function calling 첨부 파일 처리 변화. 도구를 쓸 수 없는 모델은 `Preload files` 설정 확인.
- 메모리·스킬·첨부 지식 목록이 숨겨진 tool result로 전달되는 흐름. 커스텀 Pipe는 마지막 메시지가
  tool 메시지일 수 있음을 고려한다.
- 일반 HTTP 주소에서 채팅·댓글·Markdown 편집 동작.
- Open Terminal coding agent 자동화, 채팅 중 터미널·폴더 전환, 터미널 전환 뒤 파일 탭·agent 목록 갱신.

배포 시 `.env.openwebui.oauth` 구조와 Pipelines 이미지는 변경하지 않는다. `openwebui`만
`--no-deps`로 교체한다.

## 3. Prerequisites verification

workflow의 `Validate deploy environment`가 기본 파일 검사를 수행한다. 프로덕션 에이전트는 dispatch 전에
[v0.11.3 가이드 §3](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 경로, compose project `openwebui`,
GHCR 인증, env, 디스크 검사를 적용하고 다음을 기록한다.

1. 현재 실행 이미지 태그·digest와 컨테이너 상태. Issue #71 기준 기대값은 `v0.12.4-kwh.1`이지만,
   실제 조회값이 rollback target이다. 컨테이너를 조회할 수 없거나 상태가 기대와 다르면 서비스 정지 전에 중단한다.
2. 현재 `alembic current`가 `0bd252b206fb`인지. 운영 DB 파일을 직접 열지 않고 실행 중 컨테이너에서 읽는다.
3. 최종 tag와 `git-25afc16`의 OCI index digest가 §1 값과 같은지.
4. `.env.openwebui.oauth`, 데이터 bind mount, `/app/pipelines`, 백업 대상의 존재와 읽기 권한.
   OAuth credential, API key, cookie, DB 내용은 출력하지 않는다.
5. 새 이미지와 WAL-safe 백업, 마이그레이션 중 DB 증가분을 감당할 디스크 여유.
6. 배포 전 사용자, 채팅, Model, Tool, Function, Skill, Knowledge, Prompt, 채널·멤버·메시지 개수를 기록해 §7과 비교한다.
7. `ENABLE_DB_MIGRATIONS`가 미설정 또는 기본 `True`인지 확인한다. `false`이면 스키마가 코드보다 뒤처지므로 배포하지 않는다.

**Pipelines 분기:** 배포 직전 컨테이너 상태와 `http://127.0.0.1:9099/openapi.json`을 확인한다.
실행 중이고 API가 200이면 `check_pipelines=true`로 dispatch하고 §7.4·§9에 PASS/FAIL을 기록한다.
정지·미사용 또는 API 실패라면 원인을 Issue에 기록하고, 의도적으로 제외하는 경우에만
`check_pipelines=false`로 dispatch해 §7.4·§9를 **SKIPPED**로 기록한다. `SKIPPED`는 통과가 아니다.
배포 과정에서 Pipelines를 새로 기동하거나 재생성하지 않는다.

## 4. Pre-deployment backup — MANDATORY

이번 릴리스는 스키마 변경이 있으므로 검증된 pre-deploy backup이 롤백의 기준점이다. 이전 백업을 재사용하지 않는다.

workflow는 이미지 pull 뒤 `openwebui`를 정지하고 SQLite WAL이 닫힌 상태에서 데이터와 `/app/pipelines`를
tar로 백업한다. env 파일은 owner-only 사본으로 별도 보존한다. 백업 경로·크기·권한과 `tar -tzf`
검사 결과를 Issue에 기록한다. 백업 실패 시 새 이미지로 넘어가지 않고 이전 서비스를 복구한다.

정지 후 압축하는 동안 서비스가 중단된다. RC.1 로컬 게이트는 첫 실행에서 1200초 제한을 넘겼는데,
원인은 호스트 디스크 I/O 지연과 누적 데이터의 persisted Function dependency 설치
(`yfinance`, `curl_cffi`, `peewee`)였다. 같은 증상이 프로덕션에서 발생할 수 있으므로 시간만 보고
즉시 재시작하지 말고, 로그·디스크 I/O·dependency 설치 진행을 확인한다.

수동 fallback은 [v0.11.3 가이드 §4](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 WAL-safe 순서를 따르되
현재 운영 태그를 백업명에 쓰고, 현행 workflow와 같이 pipelines·env 사본도 포함한다.

## 5. Deployment execution

배포 요청 Issue가 승인된 뒤 프로덕션 에이전트가 아래 입력으로 workflow를 dispatch한다.
GitHub `production` Environment의 실행별 승인은 별도이며 건너뛰지 않는다.

| 입력              | 값                                                     |
| ----------------- | ------------------------------------------------------ |
| `tag`             | `v0.13.3-kwh.1`                                        |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 |
| `guide_commit`    | 배포 Issue가 참조한 이 가이드 포함 `main` 전체 SHA     |
| `check_pipelines` | §3의 관측 결과에 따라 `true` 또는 `false`              |

수동 fallback이 필요한 경우에만 [v0.11.3 가이드 §5.2](./kwh-deploy-guide-v0.11.3-kwh.1.md)의
`compose config` → pull → `up -d --no-deps openwebui` 순서를 쓰고,
`OPENWEBUI_IMAGE_TAG=v0.13.3-kwh.1`로 바꾼다. 배포 에이전트 외에는 프로덕션 명령을 실행하지 않는다.

## 6. Migration monitoring

기대 로그는 Alembic의 SQLite context 두 줄 뒤 **`Running upgrade` 6건**이다.

```text
0bd252b206fb -> c41f8d9e2a10
c41f8d9e2a10 -> 6f8c2a91d4e7
6f8c2a91d4e7 -> e42c8f710a36
e42c8f710a36 -> 8bc7e5a902d1
8bc7e5a902d1 -> 6a23bd107e54
6a23bd107e54 -> 9f6c2a8d1b43
```

`Application startup complete`, `/health` 200, `/_app/version.json`의 SHA가 §1 값과 일치하는지 확인한다.
`alembic current`는 `9f6c2a8d1b43`이어야 한다.

다음이 나오면 중단하고 §8을 따른다: `Generating new WEBUI_SECRET_KEY`, `Traceback`, `sqlalchemy.exc`,
`IntegrityError`, `OperationalError`, `ModuleNotFoundError`, `Can't locate revision`, 6건 미만에서 멈춘
`Running upgrade`.

workflow의 `/health` 제한은 300초다. RC.1은 누적 데이터 환경에서 dependency 설치와 디스크 I/O 때문에
1200초도 넘긴 뒤 재실행에서 PASS했다. RC.2는 같은 축적 데이터에서 227초에, 최종 태그는 백업 직후 439초에 `/health` 200으로 DB head·무결성·Pipelines 검사를 통과했다. 최종 로컬 부팅은 workflow 제한을 넘었으므로 프로덕션에서 300초를 넘기면 컨테이너를
즉시 재시작하지 말고 logs, CPU, memory, disk I/O, dependency install 진행을 먼저 기록한다.

## 7. Post-deployment smoke checklist

아래 브라우저 검수는 배포 요청 시점에 **pending**이다. 기술 배포 PASS와 브라우저 acceptance를 구분해
Issue에 기록한다.

### 7.1 Authentication

- [ ] Google OAuth 로그인, 새로고침 뒤 세션 유지, 로그아웃 확인
- [ ] 기존 세션이 renewable auth session 변경 뒤에도 정상 유지되는지 확인
- [ ] 로그인 폼 실효 상태와 관리자 설정이 기대와 같은지 기록

### 7.2 Data integrity

- [ ] `alembic current = 9f6c2a8d1b43`, SQLite integrity check = `ok`
- [ ] 배포 전 기록한 사용자, 채팅, Model, Tool, Function, Skill, Knowledge, Prompt, 채널·멤버·메시지 개수와 비교
- [ ] Tool 목록에서 기존 도구가 유지되고 `is_active` 기본값으로 의도치 않게 비활성화되지 않았는지 확인
- [ ] 기존 채팅·설정·Knowledge·파일 업로드 자료가 유지되는지 확인

### 7.3 Fork carryovers

- [ ] 로고·스플래시·favicon·manifest·인스턴스명 `Koreatimes`, `(Open WebUI)` 접미사 없음
- [ ] 추천 프롬프트 카드 클릭 시 입력란만 채워지고 자동 전송되지 않음
- [ ] UI 버전 `v0.13.3`, `/_app/version.json` = §1 SHA
- [ ] fork 전용 GHCR workflow, deploy workflow, local-test workflow가 upstream 변경으로 대체되지 않았는지 최종 diff 확인

### 7.4 Functional smoke

- [ ] 기본 모델 대화와 제목 자동 생성
- [ ] 작은 문서 업로드 후 RAG 응답과 인용 확인
- [ ] Workspace의 Model/Tool/Function/Skill/Knowledge/Prompt 목록
- [ ] 채널의 기존 메시지와 멤버 유지, 메시지 전송 후 새로고침해도 유지
- [ ] 댓글·Markdown 편집이 HTTP 접속에서 정상 동작
- [ ] Pipelines: §3에서 `true`면 API와 연결 PASS/FAIL; `false`면 SKIPPED

### 7.5 v0.13.3 version-specific spot check

- [ ] 탭형 작업공간과 사이드 채팅 전환
- [ ] 관리자 분석 화면 로드와 기본 지표 표시
- [ ] Responses API 경로를 쓰는 모델 또는 연결의 기본 대화
- [ ] native function calling + 첨부 파일. 도구 미지원 모델은 `Preload files` 설정 필요 여부 기록
- [ ] 커스텀 Pipe에서 마지막 메시지가 tool 메시지일 수 있는 흐름 확인
- [ ] Open Terminal coding agent 자동화, 터미널·폴더 전환, 전환 뒤 파일 탭·agent 목록 갱신

## 8. Rollback procedure

금지 로그, 인증 장애, 데이터 손실, 건강 상태 불량 또는 핵심 스모크 실패 시 추가 변경을 멈추고
Issue에 상태를 기록한다. workflow는 새 컨테이너 기동 **전** 실패에만 이전 서비스를 자동 복구한다.
기동 후에는 데이터·로그·백업을 보존하고 관리자 판단을 기다린다.

### 8.1 이미지 롤백 — migration 전까지만 가능

새 이미지가 기동되기 전 실패하거나 Alembic이 실행되지 않았다는 증거가 명확할 때만 이미지 롤백을 검토한다.
운영에서 기록한 실제 이전 태그·digest를 사용한다(예상 `v0.12.4-kwh.1`). `openwebui`만 중지한 뒤
이전 이미지를 `--no-deps`로 올려 §7.1~§7.3을 재검증한다.

### 8.2 Full 롤백 — migration 후 기본 복구 경로

DB가 `9f6c2a8d1b43`으로 올라간 뒤에는 이미지 롤백만으로 복구된다고 가정하지 않는다. 이전 이미지
`v0.12.4-kwh.1`은 새 revision을 알지 못할 수 있다. 이 경우 full rollback은 검증된 §4 백업과 env 사본을
사용하는 경로다.

1. 컨테이너를 정지하고 현 상태(DB·로그·업로드·pipelines)를 별도 위치에 보존한다.
2. §4 백업 아카이브로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`는 §4의 owner-only 사본과 대조하되 내용을 출력하지 않는다.
4. `OPENWEBUI_IMAGE_TAG`를 §3에서 기록한 이전 태그로 두고 `up -d --no-deps openwebui`를 실행한다.
5. `/health`, `alembic current`, SQLite integrity, §7.2 데이터 개수를 확인한다.

백업 시점 이후의 데이터는 사라진다. full rollback은 관리자 명시 승인 없이는 진행하지 않는다.

### 8.3 Failed-upgrade 디렉터리 보존

실패한 새 이미지의 데이터 디렉터리와 로그를 별도 이름으로 보존하고 기존 백업을 덮어쓰지 않는다.
같은 immutable 태그를 재빌드하지 않는다. 수정 릴리스에는 새 `-kwh.2` 태그를 쓴다.

## 9. Success markers to record

프로덕션 에이전트는 Issue에 아래 값을 기록한다.

| 항목               | 기록값                                                                |
| ------------------ | --------------------------------------------------------------------- |
| 시작·종료 UTC      | 배포 시작·종료 UTC                                                    |
| 이전 이미지        | 태그, digest, 컨테이너 상태. 기대값은 `v0.12.4-kwh.1`, 실제 조회 우선 |
| 새 이미지          | `v0.13.3-kwh.1`, OCI index digest, linux/amd64 digest                 |
| 백업               | tar 경로, env 사본 경로, 크기, mode `600`, `tar -tzf` 검사 결과       |
| 마이그레이션       | `Running upgrade` 6건, 최종 `9f6c2a8d1b43`                            |
| Health             | `/health` 200 도달 시각, workflow run URL                             |
| Version            | `/_app/version.json` = `25afc16dc2c4c39ac7271c331fa2aff9ebadcdc1`     |
| Branding           | manifest 이름 `Koreatimes`, `(Open WebUI)` 접미사 없음                |
| Technical smoke    | §7.1~§7.5 PASS/FAIL/SKIPPED/미검증                                    |
| Pipelines          | `check_pipelines=true`이면 PASS/FAIL; `false`이면 SKIPPED와 사유      |
| Browser acceptance | **pending** until owner comment                                       |

개발 측 증적:

- PR #72 CI: PASS (all reported checks pass).
- RC.1: PASS after initial 1200s timeout. Initial timeout attributed to host disk I/O and startup installation of
  persisted Function dependencies. Re-run reached `/health` 200, Alembic head `9f6c2a8d1b43`, SQLite integrity `ok`,
  fork carryovers preserved.
- RC.2: PASS (`/health` 200 in 227s; Alembic current=heads `9f6c2a8d1b43`; SQLite integrity `ok`; Pipelines API 200; 이번 부팅 upgrade 0건).
- Final tag gate: PASS (`/health` 200 in 439s; Alembic current=heads `9f6c2a8d1b43`; SQLite integrity `ok`; Pipelines API 200; 이번 부팅 upgrade 0건)..
- Final GHCR build: `https://github.com/kwh8121/openwebui-service/actions/runs/42607439192`.
- Browser checks: pending, not counted as PASS.

## Appendix A. Environment variable reference

| 변수                                                                         | 값 또는 판정                                                    |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `OPENWEBUI_IMAGE_TAG`                                                        | 배포 `v0.13.3-kwh.1`; 롤백 시 §3의 실제 이전 태그               |
| `OPENWEBUI_LOCAL_DATA`                                                       | `/home/ubuntu/openwebui/openwebui` (운영에서 재확인)            |
| `OPENWEBUI_DEPLOY_ENV_FILE`                                                  | `/home/ubuntu/openwebui/.env.openwebui.oauth` (운영에서 재확인) |
| `PIPELINES_LOCAL_DATA`                                                       | `/app/pipelines` (운영에서 재확인)                              |
| `WEBUI_NAME`                                                                 | `Koreatimes` 예상; PersistentConfig 실효값 확인                 |
| `ENABLE_OAUTH_SIGNUP`, `ENABLE_OAUTH_PERSISTENT_CONFIG`, `ENABLE_LOGIN_FORM` | 운영 env와 PersistentConfig 확인; 비밀값 출력 금지              |
| `ENABLE_DB_MIGRATIONS`                                                       | 미설정/기본 `True` 필요; `false`이면 배포 중단                  |
| `ENABLE_TOOLS`, `ENABLE_FUNCTIONS`, `ENABLE_TOOL_SERVERS`                    | 운영 설정 확인. Tool `is_active` migration 뒤 목록 점검         |
| `ENABLE_MFA`                                                                 | 기존 설정 확인. 의도치 않은 MFA 요구가 생기면 incident          |
| `ENABLE_SKILL_LAZY_LOADING`                                                  | 운영 적용 여부 확인                                             |
| `UI_VISIBILITY`                                                              | 운영 변경 여부 확인                                             |

compose 호출은 project `openwebui`를 명시한다. OAuth credential·API key는 문서·Issue에 적지 않는다.

## Appendix B. External references

1. [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md)
2. [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md)
3. [릴리스 루틴](./kwh-release-routine.md)
4. [이전 릴리스 가이드](./kwh-deploy-guide-v0.12.4-kwh.1.md)
5. [upstream v0.13.3 변경 참고](../references/openwebui-v0.13.3-release-notes.md)
6. Production deployment request Issue #71 — current production baseline evidence for `v0.12.4-kwh.1`
7. PR #72 — `integration/v0.13.3` to `main` release integration evidence
