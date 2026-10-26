# Production Deployment Guide — `v0.12.4-kwh.1`

이 문서는 `v0.12.4-kwh.1` 프로덕션 배포의 릴리스별 명령·판정 기준이다. 정상 경로는
[`Deploy approved production release`](../../.github/workflows/deploy-approved-production-release.yaml)
workflow다. 공통 수동 fallback 절차는 [v0.11.3 가이드](./kwh-deploy-guide-v0.11.3-kwh.1.md)를
참조하되, 이 문서의 태그·digest·검증 기준으로 바꿔 적용한다. 프로덕션 상태는 배포 직전에 다시 조회한다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) →
[CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) →
[릴리스 루틴](./kwh-release-routine.md) → 이 가이드.

## 1. Release identifiers

| 항목                              | 값                                                                                                               |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Version                           | `v0.12.4-kwh.1`                                                                                                  |
| Main tip SHA / annotated tag 대상 | `1016dfb9f5a47e56318e8f3912852291d388ef2e` (PR #69 병합 커밋)                                                    |
| GHCR 배포 이미지                  | `ghcr.io/kwh8121/openwebui-service:v0.12.4-kwh.1`                                                                |
| OCI index digest                  | `sha256:e0dc03d44be0e119fab56e13826c660fd7d7404c631f687097d7f350e6cf7156`                                        |
| linux/amd64 manifest digest       | `sha256:4b50bacd3c2da67af95024008aa6867166020ca9891285963b4be07609037c5c`                                        |
| Git-SHA parity tag                | `ghcr.io/kwh8121/openwebui-service:git-1016dfb` (dispatch 전에 digest 일치 재확인)                               |
| GH Actions build                  | [run 40285816825](https://github.com/kwh8121/openwebui-service/actions/runs/40285816825), success, head SHA 일치 |
| RC                                | `v0.12.4-kwh.1-rc.1` @ `bd982e79beaf2094b42b1aacd74045fc94cacae5` (배포 대상 아님)                               |
| Base upstream                     | Open WebUI `v0.12.4`                                                                                             |
| Rollback 후보                     | `v0.12.3-kwh.1`. 실제 운영 이미지 태그·digest를 §3에서 조회해 확정                                               |

최종 이미지의 `RepoDigests`가 위 OCI index digest와 일치했다. parity 태그와의 digest 대조는
배포 전 필수다. `main`, `latest`, RC 태그를 프로덕션에 배포하지 않는다.

## 2. Deployment overview

`v0.12.3-kwh.1`에서 upstream `v0.12.4`로 올린다. 충돌 해소는 `Chat.svelte`의
`setTextHandler` rename을 받아들이면서 fork의 `insertSuggestionPrompt ?? true`를 보존한 한 곳이다.
Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `BUILD_CHANNEL=main`도 유지됐다.

**Alembic 신규 마이그레이션: 0건.** `v0.12.3..v0.12.4`에서 migration 파일 변경이 없고
revision `0bd252b206fb`를 유지한다. 로컬 RC에서 기본 config 3개
(`skills.lazy_loading.enable`, `ui.visibility`, `ldap.server.default_email_domain`)가 seed됐다.
이 행은 스키마 마이그레이션은 아니지만, 이전 이미지로 롤백할 때의 영향은 시험하지 않았다.

이번 버전의 주요 점검 대상:

- `ENABLE_SKILL_LAZY_LOADING` 기본 `False`. 켜면 선택·연결된 스킬을 필요할 때 로드한다.
  내장 Skills 도구가 필요하며, 운영 적용은 관리자 판단이다. 배포 자체가 이 기능 활성화를 요구하지 않는다.
- `ui.visibility` 기본 `{}`는 항목을 숨기지 않는다. 관리자가 항목 ID를 `false`로 설정하면
  비관리자 화면에서 숨긴다. 별도로 기능·권한 가용성에 따른 UI 숨김도 확인한다.
- 컨텍스트 압축 위치와 요약이 채팅 안에 표시된다. OAuth 사용 연결의 API key·bearer 요청에도
  사용자 OAuth 토큰이 전달되므로 연결별 동작을 배포 후 확인한다.
- 채널 대량 멤버 조회 성능과 스레드 답글 삭제 동작이 바뀌었다. 삭제 확인은 별도 테스트 채널에서만 한다.

배포 시 `.env.openwebui.oauth` 구조와 pipelines 이미지는 변경하지 않는다. `openwebui`만
`--no-deps`로 교체한다.

## 3. Prerequisites verification

workflow의 `Validate deploy environment`가 기본 검사를 수행한다. 프로덕션 에이전트는
dispatch 전에 [v0.11.3 가이드 §3](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 경로,
compose project `openwebui`, GHCR 인증, env, 디스크 검사를 적용하고 다음을 기록한다.

1. 현재 실행 이미지 태그·digest와 컨테이너 상태. 예상은 `v0.12.3-kwh.1`이지만 실제 값이
   rollback target이다. 없거나 다르면 이유를 확인하기 전 배포하지 않는다.
2. 현재 `alembic current`가 `0bd252b206fb`인지. 운영 DB 파일을 직접 열지 않는다.
3. 최종 tag와 `git-1016dfb`의 OCI index digest가 §1 값과 같은지.
4. `.env.openwebui.oauth`, 데이터·pipelines bind mount, 백업 대상의 존재와 읽기 권한.
   비밀값은 출력하지 않는다. PersistentConfig 실효값은 env와 다를 수 있으므로 화면에서 확인한다.
5. 새 이미지와 WAL-safe 백업을 둘 디스크 여유. 배포 전 Model/Tool/Function/Skill/Knowledge/Prompt,
   채널·멤버·메시지 개수를 기록해 §7과 비교한다.

**Pipelines 분기:** 배포 직전 컨테이너 상태와 `http://127.0.0.1:9099/openapi.json`을 확인한다.
실행 중이고 API가 200이면 `check_pipelines=true`로 dispatch하고 §7.4·§9에 PASS/FAIL을 기록한다.
정지·미사용 또는 API 실패라면 원인을 Issue에 기록하고, 의도적으로 제외하는 경우에만
`check_pipelines=false`로 dispatch해 §7.4·§9를 **SKIPPED**로 기록한다.
검증 없이 `false`를 선택하지 않는다. 배포 과정에서 Pipelines를 새로 기동하지 않는다([#34](https://github.com/kwh8121/openwebui-service/issues/34)).

## 4. Pre-deployment backup — MANDATORY

workflow는 이미지 pull 뒤 `openwebui`를 정지하고 SQLite WAL이 닫힌 상태에서 데이터와
`/app/pipelines`를 tar로 백업한다. env 파일은 owner-only 사본으로 별도 보존한다.
백업 경로·크기·권한과 `tar -tzf` 전수 검사를 Issue에 기록한다. 이전 백업을 재사용하지 않는다.
실패 시 새 이미지로 넘어가지 않고 이전 서비스를 복구한다.

정지 후 압축하는 동안 서비스가 중단된다. 백업 복원과 이미지 롤백은 운영에서 검증되지 않았으며,
중단 시간 단축은 [#49](https://github.com/kwh8121/openwebui-service/issues/49)의 남은 작업이다.
수동 fallback은 [v0.11.3 가이드 §4](./kwh-deploy-guide-v0.11.3-kwh.1.md)의 WAL-safe 순서를
따르되 현재 운영 태그를 백업명에 쓰고, 현행 workflow와 같이 pipelines·env 사본도 포함한다.

## 5. Deployment execution

배포 요청 Issue가 승인된 뒤 프로덕션 에이전트가 아래 입력으로 workflow를 dispatch한다.
GitHub `production` Environment의 실행별 승인은 별도이며 건너뛰지 않는다.

| 입력              | 값                                                     |
| ----------------- | ------------------------------------------------------ |
| `tag`             | `v0.12.4-kwh.1`                                        |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 |
| `guide_commit`    | 이 가이드가 포함된 `main` 커밋의 전체 SHA              |
| `check_pipelines` | §3의 관측 결과에 따라 `true` 또는 `false`              |

수동 fallback이 필요한 경우에만 [v0.11.3 가이드 §5.2](./kwh-deploy-guide-v0.11.3-kwh.1.md)의
`compose config` → pull → `up -d --no-deps openwebui` 순서를 쓰고,
`OPENWEBUI_IMAGE_TAG=v0.12.4-kwh.1`로 바꾼다. 배포 에이전트 외에는 프로덕션 명령을 실행하지 않는다.

## 6. Migration monitoring

기대 로그는 Alembic의 SQLite context 두 줄 뒤 **`Running upgrade` 0건**이다.
`alembic current`는 `0bd252b206fb`여야 한다. `Application startup complete`와
`/health` 200을 확인하고 `/_app/version.json`이 §1 SHA인지 대조한다.

`Running upgrade`, `Generating new WEBUI_SECRET_KEY`, `Traceback`, `IntegrityError`,
`OperationalError`, `Can't locate revision`이 보이면 중단하고 §8에 따른다.
`/health` 폴링이 workflow의 300초 제한을 넘으면 로그·메모리·컨테이너 상태를 먼저 확인한다.
로컬 RC는 228초에 건강 상태에 도달했다. 프로덕션 시간은 보장하지 않는다.

## 7. Post-deployment smoke checklist

### 7.1 Authentication

- [ ] Google OAuth 로그인, 새로고침 뒤 세션 유지, 로그아웃 확인. 로그인 폼 실효 상태도 기록
- [ ] OAuth 연동 도구의 토큰 전달 변경을 운영에서 확인. 로컬에서는 도구 서버 DNS 문제로 미검증

### 7.2 Data integrity

- [ ] 채팅·설정·Knowledge 유지. §3에 기록한 항목 개수와 비교
- [ ] `alembic current = 0bd252b206fb`, SQLite integrity check = `ok`

### 7.3 Fork carryovers

- [ ] 로고·스플래시·manifest·인스턴스명 `Koreatimes`, `(Open WebUI)` 접미사 없음
- [ ] 추천 프롬프트 카드 클릭 시 입력란만 채워지고 자동 전송되지 않음
- [ ] UI 버전 `v0.12.4`, `/_app/version.json` = §1 SHA

### 7.4 Functional smoke

- [ ] 기본 모델 대화와 제목 자동 생성, 작은 문서 업로드·RAG 인용
- [ ] Workspace의 Model/Tool/Function/Skill/Knowledge/Prompt 목록
- [ ] 채널의 기존 메시지와 멤버 유지, 메시지 전송 후 새로고침해도 유지
- [ ] Pipelines: §3에서 `true`면 API와 연결 PASS/FAIL; `false`면 SKIPPED

### 7.5 v0.12.4 version-specific spot check

- [ ] 관리자가 `ui.visibility` 설정 화면을 확인. 기본 `{}`에서 숨김이 없는지 확인
- [ ] 권한·기능이 꺼진 항목의 가용성 기반 UI 숨김을 확인
- [ ] 스킬 연결 모델의 응답과 토큰 사용량을 관찰. lazy loading 적용 여부는 별도 결정 후 기록
- [ ] 컨텍스트 압축이 발생하는 대화에서 위치·요약 표시 확인(발생하지 않으면 미검증으로 기록)

## 8. Rollback procedure

금지 로그, 인증 장애, 데이터 손실, 건강 상태 불량 또는 핵심 스모크 실패 시 추가 변경을 멈추고
Issue에 상태를 기록한다. workflow는 새 컨테이너 기동 **전** 실패에만 이전 서비스를 자동 복구한다.
기동 후에는 데이터·로그·백업을 보존하고 관리자 판단을 기다린다.

### 8.1 이미지 롤백

운영에서 기록한 실제 이전 태그·digest를 사용한다(예상 `v0.12.3-kwh.1`). 현재 DB와 로그를
별도 보존하고 `openwebui`만 중지한 뒤 이전 이미지를 `--no-deps`로 올려 §7.1~§7.3을 재검증한다.
스키마 변경은 없지만 새 config 기본값 행과 이전 이미지의 호환성은 미시험이다.

### 8.2 Full 롤백

이미지 롤백이 실패하거나 데이터 무결성이 깨졌다면 §4의 검증된 백업과 env 사본을 사용한다.
현재 데이터를 먼저 보존하고 관리자의 명시적 승인 후 [v0.11.3 가이드 §8.2](./kwh-deploy-guide-v0.11.3-kwh.1.md)의
복원 절차를 현행 백업 경로·운영 태그에 맞춰 수행한다. 백업 시점 이후의 데이터는 사라진다.

### 8.3 Failed-upgrade 디렉터리 보존

실패한 새 이미지의 데이터 디렉터리와 로그를 별도 이름으로 보존하고 기존 백업을 덮어쓰지 않는다.
같은 immutable 태그를 재빌드하지 않는다. 수정 릴리스에는 새 `-kwh.2` 태그를 쓴다.

## 9. Success markers to record

프로덕션 에이전트는 Issue에 시작·종료 UTC, 이전·새 이미지 태그와 digest, 백업 경로·크기·검사,
`Running upgrade` 건수, Alembic revision, `/health` 결과·시간, version SHA, manifest 이름,
§7 항목별 PASS/FAIL/미검증, Pipelines PASS 또는 SKIPPED와 근거를 기록한다.

개발 측 증적: PR #69 병합; RC 빌드 [run 40272564940](https://github.com/kwh8121/openwebui-service/actions/runs/40272564940)
및 자동 게이트 PASS(부팅 228초, upgrade 0건); 최종 빌드 §1 success.
최종 이미지에서는 `/health` 200, `/_app/version.json` §1 SHA, manifest `Koreatimes`,
Pipelines API 200, `alembic current == heads` (`0bd252b206fb`), SQLite integrity `ok`를 재확인했다.
브라우저 전체 인수 항목은 별도 결과가 없으므로 PASS로 간주하지 않는다.
로컬 로그의 `fastapi-tools-v2:8000` DNS 오류는 기존 [#48](https://github.com/kwh8121/openwebui-service/issues/48)과 같다.
브라우저에서 오래된 OAuth 세션 토큰 복호화 오류도 관측됐다. 이후 폼 로그인 HTTP 200은
로그에 기록됐지만 Google OAuth 로그인은 미검증이다.

## Appendix A. Environment variable reference

| 변수                                                                         | 값 또는 판정                                                    |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------- |
| `OPENWEBUI_IMAGE_TAG`                                                        | 배포 `v0.12.4-kwh.1`; 롤백 시 §3의 실제 이전 태그               |
| `OPENWEBUI_LOCAL_DATA`                                                       | `/home/ubuntu/openwebui/openwebui` (운영에서 재확인)            |
| `OPENWEBUI_DEPLOY_ENV_FILE`                                                  | `/home/ubuntu/openwebui/.env.openwebui.oauth` (운영에서 재확인) |
| `PIPELINES_LOCAL_DATA`                                                       | `/app/pipelines` (운영에서 재확인)                              |
| `WEBUI_NAME`                                                                 | `Koreatimes` 예상; 실효값 확인                                  |
| `ENABLE_OAUTH_SIGNUP`, `ENABLE_OAUTH_PERSISTENT_CONFIG`, `ENABLE_LOGIN_FORM` | 운영 env와 PersistentConfig 확인; 비밀값 출력 금지              |
| `ENABLE_DB_MIGRATIONS`                                                       | 미설정/기본 `True` 예상; 다르면 배포 전 확인                    |
| `ENABLE_SKILL_LAZY_LOADING`                                                  | 기본 `False`; 운영 적용 여부는 관리자 결정                      |
| `UI_VISIBILITY`                                                              | 기본 `{}`; 운영 변경 여부 확인                                  |
| `LDAP_DEFAULT_EMAIL_DOMAIN`                                                  | 기본 빈 문자열; LDAP 사용 시 확인                               |

compose 호출은 project `openwebui`를 명시한다. OAuth credential·API key는 문서·Issue에 적지 않는다.

## Appendix B. External references

1. [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md)
2. [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md)
3. [릴리스 루틴](./kwh-release-routine.md)
4. [이전 릴리스 가이드](./kwh-deploy-guide-v0.12.3-kwh.1.md)
5. [로컬 테스트 절차](../plan/local-test-workflow.md)
