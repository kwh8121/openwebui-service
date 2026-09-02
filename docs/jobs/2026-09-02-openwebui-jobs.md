# Open WebUI Jobs Log — 2026-09-02

> 이 세션은 2026-09-01에 시작해 09-02로 이어졌습니다. 09-01 구간(omc 플러그인 업데이트, v0.11.3 Stage 1~2)도 함께 기록합니다.

## 요약

upstream v0.11.3 통합 사이클을 5-stage 워크플로로 **Stage 1~3까지 완료**. 계획 수립 → 계획 검증(1라운드 REVISION-REQUESTED → 2라운드 PLAN-APPROVED) → 로컬 병합(충돌 2건 해소) → 정적 검증. `integration/v0.11.3` @ `1db7a2cba`, package.json `0.11.3`. **아직 push하지 않음.**

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

- `AGENTS.md` §"로컬 환경 제약" 신설: `nvm use 22` 필수 · `pip install ruff` · **로컬 `npm run build` 금지** · `npm run format` Prettier 3 비호환 · svelte-check 베이스라인 약 7,800건.
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
- **환경 계약 부재가 세션 드리프트의 근본 원인**: 세션마다 Node 24/engine-strict 충돌 · ruff 미설치 · 빌드 OOM · `npm run format` 파손을 밑바닥부터 재발견했다. `AGENTS.md` §"로컬 환경 제약"으로 고정.
- **`npm run format`이 Prettier 3에서 파손**: `--plugin-search-dir` 플래그가 Prettier 3.0에서 제거됐고 `.prettierrc`의 `pluginSearchDirs`도 deprecated. CI가 이 스크립트를 clean-tree 게이트로 쓰므로 PR CI 실패 가능 → **KOR-22**로 분리.
- **`npm run test:frontend`는 로컬에서 watch 모드로 뜬다**: 스크립트가 `vitest --passWithNoTests` (run 서브커맨드 없음). CI는 non-TTY라 단발 실행되지만 로컬에선 종료되지 않는다. 로컬에선 `npx vitest run --passWithNoTests`를 쓸 것.
- **계획 검증은 "계획 vs CI"뿐 아니라 "계획 vs 실제 머신"도 봐야 한다**: §7.4가 `npm run build`를 명시했고 verifier도 CI 정합성만 확인해 통과시켰으나, 실제로는 머신이 못 하는 작업이었다.
- **`pkill -f <패턴>`이 자기 셸을 죽인다**: 명령줄에 패턴 문자열이 포함되면 자기 자신도 매칭된다. 프로세스 정리 시 패턴을 변수로 쪼개거나 PID로 지정할 것.

## Linear 이벤트

- 프로젝트 `openwebui v0.11.3` 생성 (`f5d8fd0c-8c32-49b2-8d54-29dc45ce26b3`).
- KOR-14(parent) + KOR-15~21(sub) + **KOR-22**(신규 — `npm run format` Prettier 3 비호환 조사).
- KOR-14 라벨 전이: `plan-draft` → `needs-review` → `plan-approved`.
- **Linear 기록을 한글로 전환** (사용자 지시). 기존 영문 코멘트 2건은 이력으로 유지.

## 다음 세션 재개 지점

**현재 상태**: `integration/v0.11.3` @ `1db7a2cba` — Stage 3 완료, **push 안 됨**. Stage 4 미진입 (KOR-14 라벨 `plan-approved` 유지).

**다음 작업 순서**:

1. **선행 — KOR-22 조사**: `npm run format`이 `main`에서도 깨지는지(= 기존 문제) 확인. CI `frontend.yaml`이 이 스크립트로 clean-tree를 게이트하므로 PR 전에 해소 필요.
2. `integration/v0.11.3` + feature 브랜치 push → Stage 4 진입 (`verify-request`, PR 첨부, verifier diff 리뷰 → `verify-passed`).
3. RC 태그 `v0.11.3-kwh.1-rc.1` → GH Actions 빌드 → `./scripts/local-test.sh v0.11.3-kwh.1-rc.1 --allow-rc` (계획서 §8.1, 브라우저 체크리스트 §8.3 — **SQLite LIKE UDF 검색 항목 포함**).
4. PR `integration/v0.11.3 → main` → `--merge` 병합.
5. 최종 태그 `v0.11.3-kwh.1` → GH Actions 빌드 → 로컬 게이트 재실행 (§8.2).
6. `docs/manual/kwh-deploy-guide-v0.11.3-kwh.1.md` 작성 (**`check_pipelines=true` 필수**) → GitHub 배포 Issue 핸드오프.

**미해결 확인 사항** (KOR-21 사전 조건):

- 프로덕션 `.env.openwebui.oauth`에 `ENABLE_IMAGE_GENERATION` 설정 여부 (§3.3 `routers/images.py` 검증 범위 결정)
- 프로덕션 `ENABLE_DB_MIGRATIONS=false` 운영 여부 (§3.1-a `#29280` 도달 가능성)
- 배포 시점 pipelines 컨테이너 기동 여부

## 사용자 노트

- 로컬 PC는 빌드 여건이 되지 않아 빌드는 GitHub Actions에서 수행한다는 점을 사용자가 지적. 이를 계기로 계획서 §7.4와 `AGENTS.md`를 정정했다.
- Linear 기록은 앞으로 한글로 작성한다.
- 로컬 테스트 데이터(`~/openwebui-local-test-data`, `~/openwebui-local-test-pipelines`)는 `v0.11.1-kwh.2` 상태로 보존 — v0.11.3 upgrade 마이그레이션 검증의 baseline.
