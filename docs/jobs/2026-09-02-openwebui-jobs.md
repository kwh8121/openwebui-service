# Open WebUI Jobs Log — 2026-09-02

> 이 세션은 2026-09-01에 시작해 09-02로 이어졌습니다. 09-01 구간(omc 플러그인 업데이트, v0.11.3 Stage 1~2)도 함께 기록합니다.

## 요약

upstream v0.11.3 통합 사이클을 5-stage 워크플로로 **Stage 1~4 완료 + Stage 5 준비 완료**. 계획 수립 → 계획 검증(1라운드 REVISION-REQUESTED → 2라운드 PLAN-APPROVED) → 로컬 병합(충돌 2건 해소) → 정적 검증 → RC 태그·게이트 PASS → PR #29 main 병합 → 최종 태그 `v0.11.3-kwh.1` 빌드·게이트 PASS → 배포 가이드 작성. `main` @ `af4f111d1`, package.json `0.11.3`. **프로덕션 배포 성공** (run 33615303045, Issue #31 CLOSED). 세션 하네스도 고정했다 — 게이트 오판정과 도구 함정을 상시 컨텍스트로 승격(152→184줄)하고 병합 완료 브랜치 29개를 정리했다.

진행 중 **세션마다 같은 문제를 재발견하는 근본 원인**이 "이 개발 박스의 환경 계약 부재"임을 확인하고, 권위 문서 4종을 한글화하면서 현행 워크플로와 모순되는 내용을 정리해 하네스로 고정했다.

## 작업 흐름

### 1. oh-my-claudecode 플러그인 업데이트 (09-01)

- `/plugin` 메뉴가 "already at latest 5.0.2"를 반환하는 원인 규명: omc 마켓플레이스가 로컬 **디렉터리 소스**(`~/.local/share/claude-marketplaces/omc`, shallow detached-HEAD git 체크아웃)로 등록돼 있어, 메뉴가 그 클론의 `marketplace.json` 버전만 비교. 클론이 v5.0.2 태그에 고정돼 있어 항상 "최신"으로 표시.
- 해소: 클론을 `git fetch --tags` + `git checkout v5.1.0` → `claude plugin marketplace update omc` → `claude plugin update oh-my-claudecode` (CLI 비대화형). **5.0.2 → 5.1.0** (user scope).
- 스모크: MCP 브리지 서버 정상 기동, `keyword-detector` 훅 정상 실행, skills 36 / agents 19.
- 별도 project-scope 설치(`/mnt/c/Users/D4002408.addongwha`)는 5.0.2 유지 — 다른 프로젝트라 미변경.

### 2. v0.11.3 Stage 1 — 계획

- 로컬 체크아웃이 **494 커밋 뒤처져** 있었음을 발견(08-28 킥오프 시점 상태). `main` fast-forward 동기화.
- **v0.11.1 사이클은 이미 완료·배포됨**을 확인: 프로덕션은 `v0.11.1-kwh.2` (`main` @ `3234ff6f5`). 08-28 jobs log의 "다음 후보 작업"은 이미 소화된 상태였음.
- upstream이 2026-08-31에 v0.11.2, v0.11.3을 연속 릴리스. **v0.11.3 직행 결정** — v0.11.3의 `#29280`이 "0.11.0/0.11.1/0.11.2에서 올라올 때의 half-applied 업그레이드 실패"를 수정하고, v0.11.1→v0.11.3 신규 마이그레이션이 0건이라 v0.11.2 경유 실익 없음.
- Linear 프로젝트 `openwebui v0.11.3` + KOR-14(parent) + KOR-15~21(sub, `blockedBy` 체인) 생성.
- `docs/plan/v0.11.3-integration.md` 작성 (`98083c5c3`).

### 3. v0.11.3 Stage 2 — 계획 검증

- **1라운드 REVISION-REQUESTED** (CRITICAL 1 + MEDIUM 8). 전 항목 저장소에서 재확인 — 전부 타당.
  - **CRITICAL**: v1이 `backend/open_webui/internal/` 트리가 upstream과 동일하다고 기술했으나 거짓. `internal/db.py`에 **+40줄** — SQLite 내장 `LIKE`를 Python UDF로 대체(upstream `26f37426b`, v0.11.2 비영문 대소문자 무시 검색 수정). 프로덕션이 SQLite이므로 14개 모델 파일의 모든 `LIKE`/`ILIKE`에 직접 영향.
  - MEDIUM: `release*.yml` 재활성화 절차가 존재하지 않는 문제를 다룸 · `#29280`을 순수 이득으로만 서술(실제로는 startup crash 실패 모드 변경) · §7.4에 `npm run format`/`i18n:parse`/clean-tree 누락 · 존재하지 않는 태그 참조 · 위험 등급 역전(env.py↑ 실제로는 upstream 미변경 / InterfaceSettings.svelte↓ 실제로는 +110줄 churn) · 인벤토리 오분류 · `check_pipelines` 유보 · stage-4 산출물 모순.
- v2 개정(`212659d0b`) 후 **2라운드 PLAN-APPROVED**. MINOR 5건은 v2.1(`01654946d`)로 인라인 반영.
- 계획서가 미포맷 상태로 3회 커밋되는 사고 — `rtk` 프록시가 `prettier --check` 결과를 stale 캐시로 반환했기 때문. `./node_modules/.bin/prettier` 직접 호출로 발견·정정(`7233168a1`).

### 4. v0.11.3 Stage 3 — 로컬 병합

- `feature/upstream-merge-v0.11.3` @ `af25ef36f` — `git merge upstream/v0.11.3` (111 커밋). package.json `0.11.3`. 177 files changed.
- 충돌 **정확히 2건**, 계획대로 해소:
  - `.github/workflows/docker.yaml` → `--ours` (fork 전용 최소 GHCR 워크플로 유지). `main`과 바이트 동일 확인.
  - `backend/open_webui/models/users.py` → upstream `17cc5667` 채택. **`v0.11.1-kwh.2` OAuth 서브젝트 핫픽스가 upstream으로 졸업** (동일 `2**63-1` 바운드 + `str(sub_int) == sub` 가드 추가로 upstream이 더 강함).
- 커스터마이징 보존 검증 전부 통과: `WEBUI_NAME` 접미사 미재발 · `insertSuggestionPrompt ?? true` 3곳 유지(InterfaceSettings.svelte에 upstream +110줄 churn이 있었음에도) · `NODE_OPTIONS=6144` · `release*.yml` `.disabled` 유지 · 브랜드 자산 무변경.
- **정적 검증 결과** (계획서 §7.4 v3):

  | 항목                    | 결과                                           |
  | ----------------------- | ---------------------------------------------- |
  | `npm run i18n:parse`    | 재생성 diff 0 (upstream 최신)                  |
  | `ruff format --check .` | 325 files already formatted                    |
  | `npx prettier --check`  | 병합 변경 65개 파일 통과                       |
  | `svelte-check`          | 병합 파일 신규 오류 **0** (베이스라인 7,789건) |
  | `npx vitest run`        | 2 files / 8 tests 통과                         |
  | `git diff --exit-code`  | clean                                          |
  | §4.5 grep 체크리스트    | 전항목 통과                                    |

- `integration/v0.11.3`에 `--no-ff` 병합 (`1db7a2cba`).

### 5. 하네스 고정 — 권위 문서 4종 한글화 및 모순 정리

세션 드리프트의 근본 원인 분석 결과, 릴리스 루틴은 문서화돼 있으나 **"이 개발 박스에서 무엇이 되고 안 되는가"라는 환경 계약이 부재**했음을 확인. 커밋 `c35140fc4`.

**삭제** (혼선 유발)

- `github-actions-ghcr-release-deployment.md` "Current Integration Status" — 2026-07-16 기준 "v0.10.2 통합, PR #1 열림, main 미병합, 프로덕션 미배포". 현실은 v0.11.1-kwh.2 운영 중이라 적극적 오해 유발.
- 동 문서 "Remaining Release Steps" — 완료된 v0.10.2 잔여 8단계.
- `kwh-release-routine.md` §9 문서 전용 `main` 직행 단축 경로 절차 (2026-07-31 폐지). 섹션 번호는 타 문서 참조 때문에 유지하고 폐지 기록으로 대체.

**수정**

- 권위 순서 정정: `handoff.ko.md`(최상위) → `ghcr-release-deployment`(CI/CD) → `kwh-release-routine`(실무). 기존엔 ghcr 문서를 최상위로 잘못 기술.
- `git fetch upstream --tags` → `--no-tags` + refmap 분리 (fork 동명 태그 clobber로 **항상 실패**하던 절차).
- 스테이징 SSH 검증 → 로컬 프로덕션 미러 게이트.
- 수동 SSH 프로덕션 배포 → GitHub Issue 핸드오프 (Protocol v1.2).
- §12 divergence 인벤토리를 v0.11.3 병합 트리 기준으로 갱신 (`Chat.svelte:910`, `InterfaceSettings.svelte:59/340`, `env.py:936`, `Dockerfile:31` 추가, `users.py`는 upstream 졸업 분리).

**추가 — 재발 방지 하네스**

- `AGENTS.md` §"로컬 환경 제약" 신설: `nvm use 22` 필수 · `pip install ruff` · **로컬 `npm run build` 금지** · npm 스크립트 순차 실행 · `npm run test:frontend` watch 모드 주의 · svelte-check 베이스라인 약 7,800건. (초판에 있던 "`npm run format` 파손" 항목은 같은 날 오탐으로 확인되어 제거 — 아래 §"정정" 참조)
- `CLAUDE.md` 상단에 동일 제약 요약 (조회 없이 매 세션 컨텍스트 유지).

### 6. 계획서 v3 — 로컬 빌드 제외

- 커밋 `79c1a909a`. 로컬 `npm run build`가 heap OOM으로 3회 실패(7 GB RAM). **빌드 권위를 GH Actions RC 태그로 확정**하고 §2.1·§7.3·§7.4·§10·§12에서 로컬 빌드 제외.

## 커밋 / 브랜치

`integration/v0.11.3` (신규, `main` 기점) — tip `1db7a2cba`

| 커밋        | 내용                                    |
| ----------- | --------------------------------------- |
| `98083c5c3` | docs: v0.11.3 통합 계획 초안 (v1)       |
| `212659d0b` | docs: Stage 2 검증 반영 (v2)            |
| `01654946d` | docs: Stage 2 MINOR 반영 (v2.1)         |
| `7233168a1` | style: 계획서 prettier 포맷 정정        |
| `c35140fc4` | docs: 권위 문서 4종 한글화 및 모순 정리 |
| `79c1a909a` | docs: 계획서 v3 — 로컬 빌드 제외        |
| `af25ef36f` | merge: integrate Open WebUI v0.11.3     |

merge 커밋: `363352695`, `a7cd2eddb`, `6f71f83c4`, `cdc9cb772`, `a11294d23`, `d63472658`, `1db7a2cba`

feature 브랜치: `feature/docs-plan-v0.11.3-integration`, `feature/upstream-merge-v0.11.3`, `feature/docs-ko-authoritative-cleanup`, `feature/docs-plan-v0.11.3-v3`

**origin에 push하지 않음** (사용자 지시 스코프).

## 학습 사항 (→ OpenViking 이관 대상)

- **파일 트리 비교 ≠ 내용 비교**: `git ls-tree --name-only` 결과가 같아도 내용은 다를 수 있다. 마이그레이션·설정 디렉터리 비교 시 반드시 `git diff --stat <ref1> <ref2> -- <path>`를 쓸 것. 이번에 `internal/db.py` +40줄(SQLite LIKE UDF)을 놓쳐 CRITICAL 지적을 받았다.
- **rtk 프록시가 `prettier --check` 결과를 stale 캐시로 반환**: 실제로는 실패인데 "All files formatted correctly"를 반환. `npx prettier --version`도 같은 문자열을 반환해 캐시 오염이 확인됨. 포맷 검증은 `./node_modules/.bin/prettier`를 직접 호출할 것.
- **환경 계약 부재가 세션 드리프트의 근본 원인**: 세션마다 Node 24/engine-strict 충돌 · ruff 미설치 · 빌드 OOM을 밑바닥부터 재발견했다. `AGENTS.md` §"로컬 환경 제약"으로 고정.
- ~~**`npm run format`이 Prettier 3에서 파손**~~ → **정정: 오탐이었음** (같은 날 KOR-22 조사에서 확인, 아래 §"정정" 참조). `--plugin-search-dir` / `pluginSearchDirs`는 Prettier 3가 **경고만 내고 무시**하며 스크립트는 정상 동작한다.
- **진짜 교훈은 "동시 실행 금지"였다**: 위 오류(`Cannot find package 'prettier-plugin-svelte'`)는 `npm run check`와 `npm run build`를 백그라운드로 돌리는 중에 `npm run format`을 실행했을 때 한 번 발생했고 재현되지 않았다. npm 스크립트는 순차 실행할 것.
- **한 번 본 오류를 재현 없이 "파손"으로 단정하고 권위 문서에 기록한 것이 실수**: `AGENTS.md`에 거짓 제약이 들어갔고, 하네스가 막으려던 바로 그 오염을 스스로 만들었다. 환경 제약을 문서에 박기 전에 **최소 2회 재현 + 다른 브랜치/CI 대조**를 거칠 것.
- **`npm run test:frontend`는 로컬에서 watch 모드로 뜬다**: 스크립트가 `vitest --passWithNoTests` (run 서브커맨드 없음). CI는 non-TTY라 단발 실행되지만 로컬에선 종료되지 않는다. 로컬에선 `npx vitest run --passWithNoTests`를 쓸 것.
- **계획 검증은 "계획 vs CI"뿐 아니라 "계획 vs 실제 머신"도 봐야 한다**: §7.4가 `npm run build`를 명시했고 verifier도 CI 정합성만 확인해 통과시켰으나, 실제로는 머신이 못 하는 작업이었다.
- **`pkill -f <패턴>`이 자기 셸을 죽인다**: 명령줄에 패턴 문자열이 포함되면 자기 자신도 매칭된다. 프로세스 정리 시 패턴을 변수로 쪼개거나 PID로 지정할 것.

## 정정 (같은 날 후속 — KOR-22 조사 결과)

**초판에 기록한 "`npm run format`이 Prettier 3에서 파손"은 오탐이었습니다.**

검증 내역:

| 검증 항목                                                       | 결과                                                                 |
| --------------------------------------------------------------- | -------------------------------------------------------------------- |
| `npm run format` on `integration/v0.11.3`                       | 정상 (전 파일 처리, 트리 clean)                                      |
| `npm run format` on `main`                                      | 정상                                                                 |
| CI 게이트 순서 `format` → `i18n:parse` → `git diff --exit-code` | clean 통과                                                           |
| GH Actions `frontend.yaml` 최근 8회 실행                        | 전부 success (최신: `main` @ 2026-08-31)                             |
| `--plugin-search-dir` / `pluginSearchDirs`                      | Prettier 3가 `[warn] Ignored unknown option`으로 **무시**. 에러 아님 |

- 최초 관측된 `Cannot find package 'prettier-plugin-svelte'` 오류는 `npm run check`와 `npm run build`를 백그라운드로 동시 실행하던 시점에 **1회** 발생했고 재현되지 않았습니다. node_modules 동시 접근에 의한 일시적 현상으로 판단합니다.
- 이 오탐이 `AGENTS.md` §"로컬 환경 제약"에 거짓 제약으로 기록됐다가 정정됐습니다. **하네스가 막으려던 종류의 오염을 스스로 만든 사례**이므로 학습 사항에 별도 기록했습니다.
- 정정 대상: `AGENTS.md`, `docs/plan/v0.11.3-integration.md`(§7.3·§7.4·§10·§12), 본 로그, Linear KOR-22.

## Linear 이벤트

- 프로젝트 `openwebui v0.11.3` 생성 (`f5d8fd0c-8c32-49b2-8d54-29dc45ce26b3`).
- KOR-14(parent) + KOR-15~21(sub) + **KOR-22**(신규 — `npm run format` 조사 → **오탐으로 종결**).
- KOR-14 라벨 전이: `plan-draft` → `needs-review` → `plan-approved`.
- **Linear 기록을 한글로 전환** (사용자 지시). 기존 영문 코멘트 2건은 이력으로 유지.

## 릴리스 실행 (같은 날 후속 — RC → main → 최종 태그 → 배포 가이드)

계획서 §12 "다음 세션" 항목을 같은 날 전부 실행했다.

### 실행 순서와 결과

| 단계                                 | 결과                                                                         |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| push `integration/v0.11.3` + feature | 완료                                                                         |
| RC 태그 `v0.11.3-kwh.1-rc.1`         | GH Actions run `33582427125` success (8분 41초)                              |
| RC 로컬 게이트                       | **PASS** — 마이그레이션 3건 정상 실행, 브라우저 체크리스트 사용자 수행 PASS  |
| PR #29 `integration/v0.11.3 → main`  | `--merge` 병합, main tip `af4f111d1`                                         |
| 최종 태그 `v0.11.3-kwh.1`            | GH Actions run `33588400126` success                                         |
| 최종 태그 로컬 게이트                | **PASS** — 자동 검증 전 항목 통과                                            |
| 배포 가이드                          | `docs/manual/kwh-deploy-guide-v0.11.3-kwh.1.md` 작성 완료 (표준 11섹션 스펙) |

### 릴리스 아티팩트

- main tip: `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`
- 이미지: `ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1`
- OCI index digest: `sha256:5a08d0a9a7a3ea22134e84f8a5d9b950654103aa3f60bcdcb60f72a1d5c403b3`
- linux/amd64 digest: `sha256:20445c5a562910c7900c8f6b2e15645e7f1a90fc3754b026e2ebdaad55966bb6`
- parity 태그 `git-af4f111` 동일 digest 확인
- 롤백 대상: `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.2`

### 핵심 발견 — 프로덕션 마이그레이션은 완전 no-op

```
git diff --name-status v0.11.1-kwh.2 v0.11.3-kwh.1 -- backend/open_webui/migrations/versions/
→ (출력 없음)
```

`v0.11.1-kwh.2` → `v0.11.3-kwh.1` 사이 마이그레이션 파일 변화가 **0건**이고, 프로덕션은
`v0.11.1-kwh.1` 배포 이후 이미 `d4c1a8e37b62`(= v0.11.3 head)다. 세션 내내 최대 리스크로
추적하던 `#29280`(마이그레이션 실패 시 `raise`)은 **실행할 마이그레이션이 없어 도달 지점이
없다**. 계획서 §10에서 해소 처리했다.

역으로 프로덕션 기동 로그에 `Running upgrade`가 출현하면 프로덕션 revision이 전제와 다르다는
뜻이므로, 배포 가이드 §6에 **즉시 중단 조건**으로 명문화했다.

한편 로컬 게이트는 `f0bd01a18a3d` → `d4c1a8e37b62`로 3건을 실제 실행하는 **더 긴 경로**를
예외 없이 통과했다. 정확한 프로덕션 미러는 아니지만 통과 조건이 더 엄격하다.

### 게이트 스크립트 오판정 3회 연속 — KOR-23 정량 근거 확보

최종 태그 게이트에서도 `scripts/local-test.sh`가 `[FAIL]`을 냈다. 이번에는 기동 시간을 측정했다.

| 항목                          | 값                                     |
| ----------------------------- | -------------------------------------- |
| 컨테이너 기동 → `/health` 200 | **520초**                              |
| 스크립트 하드코딩 타임아웃    | 60초 (`scripts/local-test.sh:552-563`) |
| 배포 workflow 타임아웃 (참고) | 300초 (`HEALTH_TIMEOUT_SECONDS`)       |

지연 원인은 **로컬 머신의 디스크 I/O 병목**이며 이미지 결함이 아니다. PID 1이
`State: D (disk sleep)` / `wchan: __wait_on_buffer` 상태로, fd 3이
`torch/utils/__pycache__/_foreach_utils.cpython-311.pyc`에 열려 있었다. 호스트는
free 123MB / buff/cache 3.3GB — 게이트가 직전에 쓴 ~844MB 백업 tar가 페이지 캐시를 채운
직후 PyTorch(~2GB)를 로드하며 정체됐다. 외부 네트워크 연결은 없었다(다운로드 아님).
RC 게이트 때는 메모리 여유가 있어 1분 내 healthy에 도달했다.

→ KOR-23의 타임아웃은 최소 600초 + `--health-timeout` 플래그로 잡아야 한다.

### 배포 가이드 설계 결정

`kwh-deploy-guide-v0.11.1-kwh.2.md`(9섹션 축약형)가 아니라 handoff §"Per-Release Deploy
Guide Template"의 **표준 11섹션 스펙**(표준 인스턴스 `kwh-deploy-guide-v0.11.0-kwh.1.md`)을
따랐다. kwh.2는 `users.py`-only 핫픽스였지만 이번은 185 파일 / +6866-4501 규모의 upstream
2개 릴리스 통합이라 전체 사전조건·롤백·스모크 절차가 필요하다.

릴리스 특화 반영:

- §2에 마이그레이션 0건 명시 + `Running upgrade` 출현 시 즉시 중단 조건
- §3.6 pipelines 기동 사전 확인 신설 — `check_pipelines=true`가 실제로 검사하는 엔드포인트는
  `http://localhost:9099/openapi.json`이다 (워크플로 `:229`에서 확인). 중지 상태로 dispatch하면
  배포가 실패 판정된다
- §6에 로컬 520초 기동 사실과 원인을 기록해, 프로덕션에서 300초 초과 시 이미지 결함으로
  단정하지 말고 자원 상태를 먼저 조사하도록 안내
- §8.1을 기본 복구 경로로 승격 — 스키마 변경 0건이라 이미지 롤백만으로 완전 복구
- §7.5에 SQLite LIKE UDF 검색 정확도·지연을 version-specific spot check로 배치

### 열린 확인 사항 해소

이전 섹션의 "미해결 확인 사항" 3건이 모두 정리됐다.

| 항목                      | 결과                                                                                               |
| ------------------------- | -------------------------------------------------------------------------------------------------- |
| `ENABLE_IMAGE_GENERATION` | 프로덕션 env 미설정. PersistentConfig이나 게이트에서 실효값 `false` 확인 → 이미지 생성 스모크 생략 |
| `ENABLE_DB_MIGRATIONS`    | 미설정 = 기본 `True` → 마이그레이션 경로 진입. 단 실행 대상 0건이라 무해                           |
| pipelines 기동            | 로컬 게이트에서 확인. **프로덕션은 배포 요청 전 재확인 필요** (가이드 §3.6)                        |

### 추가 학습 — `rtk` 훅 재발

`curl`이 `rtk` 훅에 가로채여 `000`을 반환하는 현상이 재발했다(프리티어 때와 동일 패턴).
게이트 수동 검증 시에는 `/usr/bin/curl` 절대 경로를 사용한다.

또한 로컬 테스트 포트를 `3001`로 잘못 기억해 전 엔드포인트가 `000`으로 나왔다. 실제는
`127.0.0.1:8082`다. 검증 실패 시 **도구 탓으로 단정하기 전에 `docker port`로 실제 매핑을
먼저 확인**한다.

## Stage 5 핸드오프 — 프로덕션 배포 요청 제출

### PR #30 병합

문서 전용 PR(`integration/v0.11.3 → main`). CI 양쪽 통과 후 `--merge` 병합.

| 항목             | 값                                         |
| ---------------- | ------------------------------------------ |
| Format & Build   | pass (3m36s)                               |
| Unit Tests       | pass (43s)                                 |
| 병합 후 main tip | `4898b2e681aafb60497c00842ec97e5407ba9693` |

배포 가이드가 해당 커밋에 존재함을 **배포 워크플로가 쓰는 것과 같은 GitHub Contents API 경로**로 확인했다 (`docs/manual/kwh-deploy-guide-v0.11.3-kwh.1.md`, 24,574 bytes). 워크플로의 "Deploy guide pin" 검증이 통과할 조건을 사전에 충족시킨 것이다.

feature 브랜치는 로컬·원격 모두 삭제.

### 배포 요청 Issue #31 제출

https://github.com/kwh8121/openwebui-service/issues/31 (라벨 `production-deploy`)

Protocol v1.2 §"배포 요청 계약"의 10개 필수 필드를 모두 채웠다.

| 필드          | 값                                                              |
| ------------- | --------------------------------------------------------------- |
| Release tag   | `v0.11.3-kwh.1`                                                 |
| Main tip SHA  | `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`                      |
| Build Run     | 33588400126                                                     |
| Image digest  | `sha256:5a08d0a9…c403b3` (amd64 `sha256:20445c5a…66bb6`)        |
| Deploy guide  | `docs/manual/kwh-deploy-guide-v0.11.3-kwh.1.md` at `4898b2e68…` |
| Rollback tag  | `v0.11.1-kwh.2`                                                 |
| dispatch 입력 | `check_pipelines=true`                                          |

`check_pipelines=true`는 프로덕션 pipelines 컨테이너 기동 상태를 관리자가 확인한 뒤 확정했다. 로컬 에이전트는 프로덕션 상태를 조회할 권한이 없으므로 이 항목은 관리자 확인이 필수 선행 조건이다.

**증적을 숨기지 않았다**: 게이트 스크립트가 `[FAIL]`을 낸 사실과 그 원인(도구 결함, KOR-23), 수동 확인으로 판정했다는 절차를 Issue 본문에 명시했다. 통과 결과만 적고 오판정을 생략하면 프로덕션 에이전트가 게이트 신뢰도를 오판할 수 있다.

### Linear 연결

- KOR-14 / KOR-21에 Issue #31 URL을 attachment로 연결 (`create_attachment`는 base64 업로드 전용이라 `save_issue`의 `links` 필드 사용)
- KOR-21 라벨 `verify-passed` 전이
- KOR-14에 Stage 1~5 전체 진행 요약을 한글로 기록

### 로컬 테스트 환경 정리

`docker compose -f docker-compose.local-test.yaml down`. 데이터는 bind mount(`~/openwebui-local-test-data`)라 보존되며, 상태는 alembic `d4c1a8e37b62` / chat 4 / user 3 / model 369 — **다음 사이클의 baseline**이다. v0.11.1 사이클처럼 게이트를 건너뛰면 baseline이 뒤처지므로, 다음 릴리스에서도 게이트를 실행해 이 상태를 유지한다.

정리 시 `OPENWEBUI_LOCAL_TEST_TAG` 미설정으로 compose 보간이 실패했다. 이는 §8.1에서 로그 캡처 결함의 원인으로 **잘못 지목했던** 바로 그 현상이며, 실제로는 조사자 셸에서만 발생하는 별개 문제임이 이번에 재확인됐다.

## 하네스 고정 (PR #33)

세션 하네스를 감사해 **상시 로드 컨텍스트에 없는 지식**을 찾아 승격했다.

감사 방법은 기억이 아니라 파일 상태 조회다 — `@import` 체인 확인, 권위 문서별 grep, `git ls-files`, OpenViking `list_watches`. 처음 `grep -r`로 디렉터리를 훑었을 때 어느 파일에 적중했는지 부정확했고, 파일별 개별 grep으로 다시 검증해 오탐을 걸러냈다.

### 감사 결과

| 구분      | 내용                                                                                                                                           |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 상시 로드 | `CLAUDE.md` 39줄 + `@import AGENTS.md` 113줄 = **152줄 / 22.5KB**                                                                              |
| 조회 필요 | 권위 문서 4종 **1,285줄** (자동 로드 안 됨)                                                                                                    |
| 고정 완료 | nvm 22, 로컬 빌드 금지, ruff, npm 동시실행, vitest watch, svelte-check 베이스라인, main 직접커밋 금지, immutable, 5단계 라벨, 데이터 위치 원칙 |
| **공백**  | 게이트 `[FAIL]` 해석, 도구 함정 5건, `create_attachment` 표기                                                                                  |

### 핵심 공백 — 게이트 `[FAIL]` 오판정

`scripts/local-test.sh`가 정상 이미지에도 `[FAIL]`을 내는데, 그 사실이 **릴리스 스코프 문서에만** 있었다:

- `local-test-workflow.md:248`은 `/health` 60초 폴링을 **정상 사양으로 기술**한다 — 결함 표시가 아니다
- 결함 기록은 `docs/jobs/2026-09-02-*.md`와 `docs/plan/v0.11.3-integration.md`뿐이고, **후자는 릴리스 스코프**다. v0.11.4는 새 계획서를 만들므로 승계되지 않는다

위험 방향이 중요하다. 이 구조에서는 **정상을 실패로 읽는 쪽이 더 위험**하다 — 멀쩡한 릴리스를 폐기하고 `kwh.N+1`을 발행하면 immutable 규칙상 되돌릴 수 없다.

`AGENTS.md`에 결함 2종(60초 하드코딩 vs 실측 520초 / 로그 캡처 타이밍 거짓 음성)과 수동 판정 절차를 명시하고, `CLAUDE.md` 릴리스 루틴 **5·8번**(게이트를 실행하는 바로 그 지점)에 경고 포인터를 달았다. **KOR-23 완료 시 이 절을 삭제하라**는 조건을 본문에 박아 수정 후 잔존으로 인한 혼선을 막았다.

### 도구 함정 5건

이번 사이클에서 **실제 피해가 난 것만** 넣었다 (가설 배제).

| 함정                                             | 피해                                   |
| ------------------------------------------------ | -------------------------------------- |
| `rtk` 훅 결과 위조                               | prettier 미포맷 커밋 3회, curl `000`   |
| `gh`의 upstream 오해석                           | PR 생성 2회 실패                       |
| `gh pr checks`의 `no checks reported`            | CI 대기 루프 오탈출 1회                |
| `compose down`도 `OPENWEBUI_LOCAL_TEST_TAG` 요구 | 정리 명령 실패                         |
| 로컬 포트 `8082`                                 | 포트 오인으로 전 엔드포인트 `000` 오진 |

빈도가 높은 `gh --repo`와 절대 경로 호출은 `CLAUDE.md` 최상단에도 중복 배치했다.

### 표기 정정

MCP `create_attachment`는 **base64 업로드 전용**이라 URL 연결에 못 쓴다. `save_issue`의 `links` 필드가 정확한 방법이다. 데이터 위치 원칙 표 5곳 수정 + 사용법 주석 추가.

**결과**: 상시 컨텍스트 152줄/22.5KB → **184줄/27.0KB**.

## 브랜치 위생

병합 완료 브랜치 **29개** 삭제 (로컬 15 + 원격 15 + 원격전용 14, 중복 제외).

삭제 전 각각 `origin/main` 조상임을 재확인하고 `git branch -d`(미병합 시 거부되는 안전 모드)를 썼다. 삭제 후 릴리스 태그 5종이 전부 `main` 조상으로 도달 가능함을 확인 — 고아 커밋 없음.

원격 전용 14개는 로컬 참조가 없어 첫 목록에 잡히지 않았다. `git branch -vv`만으로는 원격 잔존을 못 본다.

결과: feature 브랜치 **0개**. 남은 것은 `main` + `integration/v0.11.{0,1,3}`.

## 프로덕션 배포 — 성공 (Issue #31 CLOSED)

| 항목                     | 값                                                                                                      |
| ------------------------ | ------------------------------------------------------------------------------------------------------- |
| 워크플로 run             | [33615303045](https://github.com/kwh8121/openwebui-service/actions/runs/33615303045) success, 11분 20초 |
| 유지보수 창              | 2026-09-02 18:33~18:48 KST (15분), 사전 승인 코멘트로 고정                                              |
| 이미지 digest            | `sha256:5a08d0a9…c403b3` — 배포 대상과 일치                                                             |
| `/_app/version.json`     | `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`                                                              |
| `/api/config`            | version `0.11.3`, name `Koreatimes`                                                                     |
| manifest                 | name·short_name `Koreatimes`                                                                            |
| **`Running upgrade`**    | **0건** — no-op 예측 프로덕션에서 확증                                                                  |
| alembic                  | `d4c1a8e37b62` 유지                                                                                     |
| `PRAGMA integrity_check` | `ok`                                                                                                    |
| 컨테이너                 | healthy, 부팅창 오류 키워드 0건                                                                         |
| 백업                     | `/home/ubuntu/prod-backup-preupgrade-20260902-094640-v0.11.1-kwh.2.tar.gz` (2.1G)                       |
| 롤백                     | 요청·수행 없음. `v0.11.1-kwh.2` 가용 유지                                                               |

**§2에서 예측한 "프로덕션 마이그레이션 완전 no-op"이 실제로 확인됐다.** `Running upgrade` 0건 + revision 불변 + integrity ok. 사이클 내내 최대 리스크로 추적한 upstream `#29280`은 끝까지 실현되지 않았다.

### ⚠️ 편차 — `check_pipelines=false`로 진행

**내가 작성한 배포 가이드는 `check_pipelines=true`를 필수로 규정했으나, 실제 배포는 `false`로 실행됐다.**

경위: 배포 요청 직전 pipelines 기동 여부를 확인받았고 "기동 중"이라는 답을 근거로 가이드 §3.6을 **하드 사전조건**으로, §5.1을 `true`로 확정했다. 그러나 프로덕션 실제 상태는 `Exited (137)`였고, 관리자가 pipelines를 이번 릴리스에서 **의도적으로 제외**하기로 결정했다.

처리 방식은 올바랐다 — **고정된 가이드 파일이나 태그를 수정하지 않고**, Issue 코멘트로 supersede 기록을 남겼다 (immutable 원칙 준수). 편차 범위는 pipelines 한정이며 나머지 게이트는 전부 원안대로 적용됐다.

| 초안 (가이드)                           | 실제                                    |
| --------------------------------------- | --------------------------------------- |
| §3.6 pipelines 기동 = dispatch 사전조건 | **철회** — 중지 상태가 정상·수용된 상태 |
| §5.1 `check_pipelines=true`             | **`false`**                             |
| §7.4 pipelines 브라우저 검증 2항목      | `SKIPPED (intentionally disabled)`      |
| §9 Pipelines = `PASS` 여야 함           | `SKIPPED`                               |

`SKIPPED`는 **증거 미수집**을 뜻하며 통과로 롤업하면 안 된다. `utils/middleware.py`(+163)와 `routers/pipelines.py`(+6)는 **프로덕션 미검증 상태로 남았다.**

### 후속 — Issue #34

deferred pipelines 작업을 전용 트래커로 분리해 #31 종료 후에도 유실되지 않게 했다.

**#34** — Pipelines 안전 재기동 + v0.11.3 middleware/routers 프로덕션 회귀 검증. 별도 요청 Issue와 `production` Environment 승인이 있어야 실행 가능하다.

### 브라우저 acceptance

**PASS with follow-up.** 비-pipelines 범위 전 항목 통과, 사용자 가시 회귀 없음. plain PASS가 아닌 유일한 이유가 pipelines `SKIPPED`다.

### 학습 — 배포 가이드의 사전조건 기술 방식

로컬 에이전트는 **프로덕션 상태를 조회할 권한이 없다.** 그런데 나는 전달받은 답변("기동 중")을 근거로 가이드에 **단정형 사전조건**을 박았고, 실제 상태가 달라 편차 기록이 필요해졌다.

릴리스별 가이드는 검증 불가능한 프로덕션 상태를 **단정하지 말고**, "dispatch 직전 확인 → 결과에 따라 `true`/`false` 선택 + 근거를 Issue에 기록"이라는 **분기 절차**로 기술해야 한다. 그러면 상태가 달라도 편차가 아니라 정상 경로가 된다.

## 다음 세션 재개 지점

**현재 상태**: v0.11.3 사이클 **완결**. `main` @ `dd9254ed8`. 프로덕션에 `v0.11.3-kwh.1` 배포 성공, Issue #31 CLOSED. 작업트리 clean, feature 브랜치 0개.

**열린 작업**:

1. **Issue #34** (OPEN) — Pipelines 안전 재기동 + `utils/middleware.py`(+163) / `routers/pipelines.py`(+6) 프로덕션 회귀 검증. 이번 배포에서 `SKIPPED`로 남은 유일한 미검증 범위다. 별도 요청 Issue + `production` Environment 승인 필요.
2. **KOR-23** (High) — `scripts/local-test.sh` 결함 3종: ① health 타임아웃 60초(실측 520초 필요, 최소 600초 + `--health-timeout`), ② `up -d` 직후 로그 캡처로 검사가 항상 통과하는 거짓 음성, ③ 마이그레이션 자동 assertion 부재. **완료 시 `AGENTS.md` §"로컬 게이트 스크립트는 `[FAIL]`을 냅니다" 절을 삭제할 것** (본문에도 명시됨).
3. **가이드 템플릿 개선 (권고, 미착수)** — 릴리스별 배포 가이드가 검증 불가능한 프로덕션 상태를 단정하지 않도록, 사전조건을 분기 절차로 기술하는 규칙을 handoff 문서 §"Per-Release Deploy Guide Template"에 추가. 근거는 위 §"학습 — 배포 가이드의 사전조건 기술 방식".

**다음 upstream 사이클 시작 시**: 로컬 테스트 데이터는 `~/openwebui-local-test-data`에 alembic `d4c1a8e37b62` / chat 4 / user 3 / model 369로 보존돼 있다. v0.11.1 사이클처럼 게이트를 건너뛰면 baseline이 뒤처지므로 매 사이클 게이트를 실행해 이 상태를 유지한다.

## 사용자 노트

- 로컬 PC는 빌드 여건이 되지 않아 빌드는 GitHub Actions에서 수행한다는 점을 사용자가 지적. 이를 계기로 계획서 §7.4와 `AGENTS.md`를 정정했다.
- Linear 기록은 앞으로 한글로 작성한다.
- 로컬 테스트 데이터(`~/openwebui-local-test-data`, `~/openwebui-local-test-pipelines`)는 `v0.11.1-kwh.2` 상태로 보존 — v0.11.3 upgrade 마이그레이션 검증의 baseline.
