# Open WebUI Jobs Log — 2026-09-02

> 이 세션은 2026-09-01에 시작해 09-02로 이어졌습니다. 09-01 구간(omc 플러그인 업데이트, v0.11.3 Stage 1~2)도 함께 기록합니다.

## 요약

upstream v0.11.3 통합 사이클을 5-stage 워크플로로 **Stage 1~4 완료 + Stage 5 준비 완료**. 계획 수립 → 계획 검증(1라운드 REVISION-REQUESTED → 2라운드 PLAN-APPROVED) → 로컬 병합(충돌 2건 해소) → 정적 검증 → RC 태그·게이트 PASS → PR #29 main 병합 → 최종 태그 `v0.11.3-kwh.1` 빌드·게이트 PASS → 배포 가이드 작성. `main` @ `af4f111d1`, package.json `0.11.3`. **프로덕션 미배포** — 배포 요청 Issue 제출이 남았다.

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

## 다음 세션 재개 지점

**현재 상태**: `main` @ `af4f111d1`, 최종 태그 `v0.11.3-kwh.1` 발행·빌드·로컬 게이트 PASS 완료.
배포 가이드 작성 완료. **프로덕션 미배포.**
작업 브랜치: `feature/docs-v0.11.3-deploy-guide` (배포 가이드 + 계획서 §8.2/§9/§10/§11/§12 갱신).

**다음 작업 순서**:

1. `feature/docs-v0.11.3-deploy-guide` → `integration/v0.11.3` `--no-ff` 병합 → push → PR → `main`.
2. **프로덕션 pipelines 컨테이너 기동 확인** — `check_pipelines=true` 사전 조건 (가이드 §3.6).
   중지 상태면 dispatch가 실패 판정된다.
3. `Production deployment request` Issue 제출 (Protocol v1.2 §"배포 요청 계약"). 필수 필드:
   최종 태그, 40자 SHA `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`, build run `33588400126`,
   digest, 가이드 경로 + main 커밋 SHA, 로컬 게이트 2회 PASS, 마이그레이션 0건,
   fork carryover 검증 결과, 롤백 태그 `v0.11.1-kwh.2`.
4. Linear KOR-14에 배포 Issue URL을 `create_attachment`로 연결하고 `verify-passed` 유지.
5. 배포 후 가이드 §7.5 검색 지연 관찰 결과를 jobs log에 기록.

**릴리스와 독립된 잔여 과제**:

- **KOR-23** (High) — `scripts/local-test.sh` 결함 3종: health 타임아웃 60→600초 + 플래그,
  로그 캡처 타이밍(거짓 음성), 마이그레이션 자동 assertion 부재. 다음 사이클 전 처리 권장.

## 사용자 노트

- 로컬 PC는 빌드 여건이 되지 않아 빌드는 GitHub Actions에서 수행한다는 점을 사용자가 지적. 이를 계기로 계획서 §7.4와 `AGENTS.md`를 정정했다.
- Linear 기록은 앞으로 한글로 작성한다.
- 로컬 테스트 데이터(`~/openwebui-local-test-data`, `~/openwebui-local-test-pipelines`)는 `v0.11.1-kwh.2` 상태로 보존 — v0.11.3 upgrade 마이그레이션 검증의 baseline.
