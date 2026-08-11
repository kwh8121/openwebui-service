# Open WebUI Jobs Log — 2026-07-29

## 요약

- `docs/plan/local-test-workflow.md` v2 → v3 개정: 2차 검토 3건 반영 (데이터 dir empty 강제, immutable 최종 태그 실패 처리 규칙, RC 태그 정규식 엄격화).
- v3 계획대로 로컬 사전 배포 검증 워크플로 도구 신설: `docker-compose.local-test.yaml`, `.env.local-test.template`, `scripts/local-test.sh`, `.gitignore` 예외 규칙, `docs/manual/kwh-release-routine.md` §3.9-b 삽입. `feature/local-test-workflow` 브랜치로 커밋 `05e336b2e`.
- 기존 `feature/koreatimes-loading-splash`의 커밋 `edde6e35b` (splash 라이트/다크 자산 업데이트)도 다음 릴리스 대상. 계획 문서 브라우저 체크리스트에 splash 확인 항목 추가.
- `integration/v0.10.2`를 `main` 기준으로 fast-forward한 뒤 `feature/koreatimes-loading-splash`와 `feature/local-test-workflow`를 `--no-ff` 순차 머지 → `origin/integration/v0.10.2` 푸시. 다음 RC 태그 대기 상태.

## 작업 흐름

1. **세션 재개 + v3 개정**
   - 이전 세션의 v2 계획 상태 확인 (승인 대기).
   - 2차 검토 결과 3건의 타당성 검토:
     1. 데이터 디렉터리 empty 강제 → 강력 채택 (false-positive 방지)
     2. immutable 최종 태그 재빌드 금지 → 강력 채택 (`da9ccba8` 메모리와 일치)
     3. RC 태그 정규식 분리 → 엄격+opt-in (a) 채택 (스테이징 게이트 톤 일관)
   - `docs/plan/local-test-workflow.md` v3 개정: 상단 검토 반영 섹션, §3 스크립트 명세 개편(플래그·정규식·데이터 dir 검증 3분기), §5 kwh-release-routine 삽입 내용, §구현 완료 후 검증 절차, 개정 이력에 v3 항목 추가.

2. **feature/local-test-workflow 브랜치 및 파일 구현**
   - 현재 `feature/koreatimes-loading-splash` HEAD에서 `main` 으로 이동 후 `feature/local-test-workflow` 생성.
   - `docker-compose.local-test.yaml`: 포트 8082, `restart: 'no'`, `openwebui_local_test_network` 격리, `ENABLE_OAUTH_PERSISTENT_CONFIG=true` 유지 (staging/prod compose와 diff 최소화).
   - `.env.local-test.template`: `WEBUI_NAME=Koreatimes`, OAuth off, 로컬 로그인/가입 on, `DEFAULT_USER_ROLE=admin`.
   - `.gitignore`: `!.env.example` 아래에 `!.env.local-test.template` 예외 규칙 추가. `git check-ignore -v`로 template 무시 안 됨 · 실제 env 파일 무시됨 검증 완료.
   - `scripts/local-test.sh`: `set -euo pipefail`. 순서: 인수 파싱 → 태그 정규식 검증(엄격 기본 + `--allow-rc`) → `--down` 단축 → ghcr 인증 검사 → 데이터 dir 상태 검증(없음 자동 생성 / 비어있음 통과 / 비어있지 않음 `--reuse-data` 없으면 abort) → env 파일 검사 → 이미지 pull → compose up → 3중 확인(compose ps state, logs 100줄 오류 키워드 스캔, `/health` 60초 폴링) → 실패 시 최종 태그면 immutable 규칙 리마인더.
   - `docs/manual/kwh-release-routine.md` §3.9와 §3.10 사이에 §3.9-b 삽입: 도입, immutable 태그 실패 처리 규칙, 검증 범위/한계, 최초 설정, 실행, 옵션 플래그, 종료, 경고.

3. **사전 검증**
   - `bash -n` syntax OK.
   - 태그 정규식 테스트: `invalid-tag`, `0.10.2-kwh.2`, `v0.10.2-kwh.2-rc.1` 모두 exit 2 (에러 메시지 명확). `v0.10.2-kwh.2-rc.1 --allow-rc`와 `v0.10.2-kwh.2`는 다음 단계로 진행.
   - `usage()` 버그 수정: `sed -n '3,25p'`가 `set -euo pipefail` 라인까지 포함해 출력되던 문제를 `awk`로 대체하여 주석 블록 종료 지점까지만 출력.
   - `docker compose config` dry-run: env·포트·bind-mount·network 모두 정확 해석.

4. **커밋 및 통합**
   - `feature/local-test-workflow`에 단일 커밋 `05e336b2e feat(local-test): add WSL2 local pre-deploy verification workflow` (6 파일, +616 라인, docs/plan/local-test-workflow.md 포함).
   - 두 feature 브랜치 push (`origin/feature/local-test-workflow`, `origin/feature/koreatimes-loading-splash` 신규).
   - `integration/v0.10.2`가 `main`의 strict ancestor임을 `git merge-base --is-ancestor`로 확인 → fast-forward로 main tip(`18e754ed1`)까지 반영 (kwh.2 이후 doc-only PR #4-#6이 통합에 없었음).
   - `feature/koreatimes-loading-splash` → `--no-ff` 머지 `773b52667`.
   - `feature/local-test-workflow` → `--no-ff` 머지 `702ad5bd5`.
   - `origin/integration/v0.10.2` push 완료.

## 커밋 / PR

**신규 커밋:**
- `05e336b2e` feat(local-test): add WSL2 local pre-deploy verification workflow (feature/local-test-workflow)
- `773b52667` merge: feature/koreatimes-loading-splash into integration/v0.10.2
- `702ad5bd5` merge: feature/local-test-workflow into integration/v0.10.2

**참조 (이전 세션):**
- `edde6e35b` assets: update Koreatimes loading splash images (feature/koreatimes-loading-splash)

**PR:** 이 세션에서는 생성 안 함. 다음 단계는 RC 태그 → GH Actions RC 빌드 → 스테이징 검증 → PR `integration/v0.10.2` → `main`.

## 브랜치 이동

`feature/koreatimes-loading-splash` → `main` → `feature/local-test-workflow` → `integration/v0.10.2` (최종)

## 학습 사항

- **integration/v0.10.2가 main의 strict ancestor일 수 있음**: kwh.2 릴리스 후 main에 doc-only PR(#4-#6)이 들어가면서 integration이 main보다 뒤처짐. 다음 kwh.N 시작 전에 integration을 main으로 fast-forward하지 않으면 이후 PR 시 doc 삭제 diff가 생김. 표준 절차로 편입 필요.
- **compose `env_file`은 상대 경로 기준을 compose 파일 위치로 삼음**: `${OPENWEBUI_LOCAL_TEST_ENV_FILE:-./.env.local-test}` 형태에서 shell에서 지정한 상대 경로도 그대로 사용됨. dry-run 시 template 파일 이름을 명시 전달해서 config 검증 가능.
- **bash `sed -n '3,25p'` 절대 라인 범위 usage 출력은 취약**: 소스 편집 시 라인 shift로 인해 코드 라인이 포함될 수 있음. `awk`로 주석 블록 종료(빈 줄 or 비주석)까지 자동 잘라내는 방식이 더 견고.
- **`.env.*` glob과 `!` 예외의 순서**: 예외 규칙은 반드시 매치 규칙 뒤에 있어야 작동. `git check-ignore -v <path>`로 어느 규칙이 매치되는지 파일:라인:패턴 형식으로 확인 가능.
- **bind-mount 데이터 디렉터리는 `docker compose down`으로 삭제되지 않음**: `-v` 플래그도 마찬가지. 스크립트가 별도로 empty 확인 로직을 가져야 fresh-DB 검증 목표가 유지됨.
- **`docker compose ps --format '{{.State}}'`**: 컨테이너 상태를 스크립트에서 파싱하기 좋은 형태. `restart: 'no'`인 서비스에서도 정상 기동 시 `running`.

## 다음 후보 작업

- **RC 태그 커팅** (사용자 승인 필요, GH Actions 빌드 트리거):
  ```bash
  git tag -a v0.10.2-kwh.3-rc.1 702ad5bd5 -m "kwh.3 RC1: koreatimes loading splash + local-test workflow"
  git push origin v0.10.2-kwh.3-rc.1
  ```
- **스테이징 검증**: `OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.3-rc.1`로 스테이징 서버에서 `docker-compose.staging.yaml` up → 스모크(로그인, splash, 로고, 인스턴스명, 제안 카드, RAG, pipelines).
- **PR `integration/v0.10.2` → `main`** (스테이징 통과 후) → `--merge` 머지 → main 동기화.
- **최종 태그** `v0.10.2-kwh.3` 및 GH Actions 프로덕션 빌드.
- **로컬 사전 검증 실제 시연** (선택): `docker login ghcr.io -u kwh8121` 후 `./scripts/local-test.sh v0.10.2-kwh.3`로 신규 도구를 실제 릴리스에서 최초 사용.
- **프로덕션 배포**: SSH → WAL-safe backup → `OPENWEBUI_IMAGE_TAG=v0.10.2-kwh.3` 반영 → `docker-compose.deploy.yaml` pull + up.

## 미커밋 상태

- 이 로그 파일(`docs/jobs/2026-07-29-openwebui-jobs.md`)은 로컬만 저장. 커밋은 하지 않음 (이전 관례와 동일).
- `docs/jobs/` 디렉터리 전체가 여전히 untracked. 필요 시:
  ```bash
  git add docs/jobs/2026-07-29-openwebui-jobs.md
  git commit -m "docs: add 2026-07-29 openwebui jobs log"
  ```
