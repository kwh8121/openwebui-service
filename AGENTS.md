# Open WebUI 에이전트 가이드

## 저장소 구조

- `src/`는 SvelteKit 프론트엔드입니다. `src/routes`에 라우트가, `src/lib`에 공유 UI·스토어·클라이언트 유틸리티가 있습니다.
- `backend/open_webui/main.py`가 FastAPI 앱을 생성하고, `/api/v1`·`/ollama`·`/openai` 아래에 라우터를 등록한 뒤, 빌드된 프론트엔드를 SPA fallback으로 마운트합니다. 백엔드 설정은 `backend/open_webui/config.py`와 `env.py`에 집중돼 있습니다.
- `npm run build`는 `build/`를 생성하며, 이는 Python wheel에 `open_webui/frontend`로 패키징됩니다. 빌드 산출물은 직접 수정하지 않습니다.
- DB 마이그레이션은 `backend/open_webui/migrations`에 있습니다. 생성 명령: `DATABASE_URL=<url> alembic revision --autogenerate -m "description"`.

## 로컬 개발

- Node는 engine-strict이며 `>=18.13.0` ~ Node 22 범위여야 합니다. Python은 3.11–3.12를 지원합니다.
- 프론트엔드: `npm run dev`가 Pyodide 자산을 먼저 받은 뒤 Vite를 시작합니다. 포트 5050이 필요할 때만 `npm run dev:5050`을 사용합니다.
- 백엔드: `backend/`에서 `./dev.sh`를 실행합니다. 포트 8080에서 reload 서버가 뜨고 Vite origin을 허용합니다. 풀스택 작업 시 Vite와 함께 실행합니다.
- 패키지 서버 실행 명령은 `open-webui serve`입니다. `WEBUI_SECRET_KEY`가 없으면 `.webui_secret_key`를 생성하거나 읽어들입니다. 이 키와 `backend/data`는 커밋하지 않습니다.

## 로컬 환경 제약 (이 개발 PC)

`npm` / `ruff` 명령을 실행하기 전에 반드시 읽으십시오. 아래는 취향이 아니라 **머신의 사실**입니다. 이를 모르고 시작한 세션은 매번 같은 실패를 반복하게 됩니다.

- **Node**: nvm에 Node 22와 Node 24가 있고 기본 PATH는 Node 24를 가리킵니다. 프로젝트는 engine-strict `<=22.x`이므로 **먼저 `nvm use 22`**를 실행합니다. Node 24에서는 `npm ci`와 스크립트가 실패합니다.
- **ruff**: 기본 설치돼 있지 않습니다. `npm run format:backend` 또는 `ruff format --check` 전에 `pip install ruff`가 필요합니다.
- **프론트엔드 프로덕션 빌드는 로컬에서 실행하지 않습니다.** `npm run build`(vite)는 이 7 GB 머신에서 heap OOM으로 실패합니다. **GitHub Actions의 GHCR 이미지 빌드**(`v*-kwh.*` 태그 트리거)가 유일한 빌드 권위이며, `scripts/local-test.sh`가 그 빌드 결과 이미지를 검증합니다. push 전 로컬 검증은 **정적 검사만** 수행합니다: `npm run check`(svelte-check), `npm run test:frontend`, `npm run i18n:parse`, `ruff format --check`, `npx prettier --check <files>`.
- **`npm run format`은 정상 동작합니다** (2026-09-02 `main`·`integration` 양쪽 재확인, CI도 green). `--plugin-search-dir` 플래그와 `.prettierrc`의 `pluginSearchDirs`는 Prettier 2 잔재로 Prettier 3가 **경고만 내고 무시**합니다(`[warn] Ignored unknown option`). 동작에 문제 없으며 정리는 선택적 housekeeping입니다.
- **npm 스크립트를 동시 실행하지 마십시오.** `npm run check` / `npm run build`를 백그라운드로 돌리면서 `npm run format`을 실행했을 때 `Cannot find package 'prettier-plugin-svelte'` 오류가 한 번 발생했습니다(재현 불가). node_modules 동시 접근으로 보이므로 순차 실행합니다.
- **`npm run test:frontend`는 로컬에서 watch 모드로 뜹니다.** 스크립트가 `vitest --passWithNoTests`로 `run` 서브커맨드가 없어 종료되지 않습니다. CI는 non-TTY라 단발 실행되지만, 로컬에서는 `npx vitest run --passWithNoTests`를 사용합니다.
- **svelte-check 베이스라인**: `npm run check`는 upstream에서 물려받은 기존 오류 약 7,800건을 보고합니다. 병합이 깨끗하다는 기준은 총합이 0인 것이 아니라, **병합이 건드린 파일에 신규 오류가 0건**인 것입니다.

## 검증 및 포매팅

- 프론트엔드 타입 검사: `npm run check`. 프로덕션 빌드: `npm run build` — **단, 빌드는 로컬에서 실행하지 않습니다** (위 §"로컬 환경 제약" 참조). 두 명령 모두 Pyodide를 먼저 받습니다.
- 프론트엔드 테스트: `npm run test:frontend -- <path-or-vitest-args>`.
- `npm run lint:frontend`, `npm run format`, `npm run i18n:parse`는 파일을 수정합니다. 마지막 명령은 `src/lib/i18n`을 재생성하므로, 번역 대상 문자열을 바꾼 뒤 실행하고 그 산출물을 함께 커밋합니다.
- CI는 `npm run format` → `npm run i18n:parse` 순으로 실행한 뒤 clean tree를 요구하고 빌드합니다. 변경을 일으키지 않는 프론트엔드 포맷 검사가 필요할 때는 `npx prettier --check <files>`를 사용합니다.
- 백엔드 CI는 `ruff format --check . --exclude .venv --exclude venv`입니다. 백엔드 수정은 `npm run format:backend`로 포맷합니다. `npm run lint:backend`는 `backend/` 전체에 Pylint를 실행합니다.

## 전달 제약

- 커스텀 변경은 `feature/*`에서 개발하고, 공식 릴리스와 기능은 `integration/vX.Y.Z`에 병합한 뒤, 검증된 integration PR을 `main`에 엽니다. PR 제목은 타입을 명시하고, 본문에 필수 CLA 섹션을 유지합니다.
- 루트 Compose 설정은 배포 전용입니다: `.env.openwebui.oauth`를 로드하고, 80 포트를 노출하며, `shared_bridge_network`에 연결됩니다. 범용 로컬 개발 스택으로 가정하지 마십시오.

## 데이터 위치 원칙 — One Fact, One Home

2026-08-11 채택. 각 정보 유형에는 정본 위치가 하나씩 있고, 다른 도구에는 링크나 짧은 요약만 두며 절대 복제하지 않습니다.

| 정보 유형                                  | 원본 위치                                           | 다른 도구에는 어떻게 둘 것인가                                                                                      |
| ------------------------------------------ | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| 계획안, 검증 요청, 상태 전이 (in-flight)   | Linear                                              | jobs log에는 결과 요약만                                                                                            |
| **확정된 개발·리뷰 계획 (approved plans)** | **`docs/plan/`**                                    | **Linear 이슈는 유지하고 `create_attachment`로 `docs/plan/<file>.md` 링크만 (승격 후에도 stage 3~4 포인터로 사용)** |
| 세션에서 실제로 한 일                      | jobs log (`docs/jobs/YYYY-MM-DD-openwebui-jobs.md`) | OpenViking이 watch로 자동 인제스션                                                                                  |
| 코드 변경, 브랜치, PR, 태그                | Git / GitHub                                        | Linear·jobs log에는 링크와 요약만                                                                                   |
| 배포 승인·결과 evidence                    | GitHub Issue                                        | Linear에는 `create_attachment` 링크만                                                                               |
| **upstream Open WebUI 버전·기능 참고자료** | **`docs/references/`**                              | **jobs log에는 참조 링크만. mem0에는 넣지 않음**                                                                    |
| 장기 학습, 반복 실수, 운영 원칙            | jobs log → OpenViking                               | mem0에는 넣지 않음 (참고 캐시로 남을 수 있음)                                                                       |
| 개인 선호, 답변 스타일, 일반 습관          | mem0                                                | 프로젝트 문서에는 넣지 않음                                                                                         |

**4-도구 역할 요약:**

- **A. Linear** = 지금 살아 있는 작업판. 작업 단위의 대화·상태만. 세션 전체 요약은 jobs log로 이관.
- **B. jobs log** = 세션 종료 후 남기는 공식 작업일지. Append-only 감사 기록. 오늘 무엇을 했는가·어떤 결정을 했는가·어떤 이슈/PR/커밋이 생겼는가·어떤 문제가 발견됐는가·다음 세션 재개 지점·학습 사항을 포함.
- **C. OpenViking** = 다음 에이전트가 읽을 장기 컨텍스트 DB. Watch 대상: `docs/jobs/`, `docs/manual/`, `docs/plan/`, `docs/references/`, `AGENTS.md`, `CLAUDE.md`. GitHub repo watch(24h refresh)로 committed 파일 자동 인제스션. Linear 승인 계획은 `docs/plan/` 승격 후 자동 커버, GitHub 배포 이슈 결과는 jobs log를 게이트웨이로 커버.
- **D. mem0** = 프로젝트 밖 개인 선호. auto-capture 훅이 프로젝트 결정도 저장하나 이는 참고 캐시이며 진실 소스가 아니다. 원칙 판단 시 jobs log와 OpenViking 이관본이 우선하며 mem0 결과에 의존하지 말 것.

**한 줄 요약**: Linear = 지금 할 일 · jobs log = 오늘 실제로 한 일 · docs/plan = 확정된 계획 · docs/references = upstream 참고 · OpenViking = 다음 에이전트가 읽을 기억 · mem0 = 프로젝트 밖 개인 선호.

**`docs/manual/` vs `docs/references/` 경계 원칙 (2026-08-11 채택):**

- **`docs/manual/`**: **이 fork의** 배포·운영·정책 문서 (kwh-release-routine, github-control-plane-local-agent-handoff, github-actions-ghcr-release-deployment, 릴리스별 배포 가이드, oauth notes, korean-locale-image-notes, openwebui-repo, openwebui-migration-notes 등). fork 이력에 종속.
- **`docs/references/`**: **upstream Open WebUI에 관한** 조사·업데이트·기능 참고 (release notes, 업데이트 리포트, 기능 research). fork와 무관하게 upstream 변화만 반영. 경계가 모호한 파일은 팀 판단에 맡기고 이번 스코프에서 재분류하지 않음.

**승격 경로 (수동, 자동화 없음)**:

- Linear plan-approved → `docs/plan/<slug>.md` 파일 작성 → Linear 이슈에 `create_attachment` 링크
- Upstream release/기능 발견 → `docs/references/<slug>.md` 작성

## 개발·릴리스 워크플로 (5단계)

프로덕션으로 향하는 모든 변경의 전체 생명주기입니다. 1~4단계는 Linear(`koreatimes` 워크스페이스, 프로젝트 `openwebui vX.Y.Z`)를 사용하고, 5단계는 기존 opencode 프로덕션 에이전트 계약에 따라 GitHub Issue에 남습니다.

1. **계획 (Planning)** — Planner 에이전트가 Linear Project + 부모 이슈 + 하위 이슈를 생성합니다. 라벨: `plan-draft`. 부모/자식 계층, 의존성용 `blockedBy`, 향후 브랜치 명명에 쓸 `gitBranchName` 자동 생성을 활용합니다.
2. **계획 검증 (Plan verification)** — Planner가 부모 라벨을 `plan-draft` → `needs-review`로 전이합니다. Verifier 에이전트가 `list_issues --label needs-review`로 이를 집어 findings를 이슈 코멘트로 게시하고(PASS/CRITICAL/MEDIUM/MINOR + 판정), 승인 시 `plan-approved`로, 수정 요청 시 `plan-draft`로 되돌립니다. 코멘트 스레드가 감사 지면입니다.
3. **개발 (Development)** — Dev 에이전트가 `plan-approved` 하위 이슈를 집어 그 이슈의 `gitBranchName` 필드로 feature 브랜치를 만듭니다. 표준 `feature/* → integration/vX.Y.Z → main` 흐름(아래 §"릴리스 루틴 및 세션 연속성" 참조). Linear 이슈 상태("In Progress")는 진행 포인터일 뿐이며 진실은 git이 보유합니다.
4. **개발 검증 (Dev review)** — Dev 에이전트가 이슈 라벨을 `verify-request`로 전이합니다. Verifier가 이를 집어 diff를 리뷰하고(Linear 이슈에 `create_attachment`로 연결된 GitHub PR 경유) findings를 게시한 뒤 `verify-passed`로 전이합니다. 2단계와 동일한 코멘트 스레드 감사 패턴입니다.
5. **배포 (Deployment)** — **변경 없음, GitHub Issue 유지.** 로컬 dev 에이전트가 handoff §"배포 요청 계약"(Protocol v1.2)에 따라 `Production deployment request` Issue를 제출합니다. opencode 프로덕션 에이전트가 `deploy-approved-production-release.yaml` 워크플로로 실행합니다. Linear 이슈는 감사 추적을 위해 `create_attachment`로 GitHub 배포 Issue URL을 참조합니다.

**라벨 어휘** (워크스페이스 레벨, 2026-08-11 생성):

| 라벨             | 색상   | 의미                                           |
| ---------------- | ------ | ---------------------------------------------- |
| `plan-draft`     | gray   | Planner가 아직 계획을 작성 중                  |
| `needs-review`   | yellow | 계획 완료, plan verifier 대기                  |
| `plan-approved`  | teal   | 계획 검증 완료, dev 착수 가능                  |
| `verify-request` | orange | 개발 완료, dev verifier 대기                   |
| `verify-passed`  | green  | 개발 검증 완료, GitHub 배포 핸드오프 준비 완료 |

**채택 근거**: 1~2단계(계획 + 계획 검증)가 Linear의 계층적 이슈 모델과 코멘트 기반 리뷰에서 가장 큰 이득을 봅니다 — 텍스트만으로 하는 계획은 코멘트 스레드가 잡아내는 설계 결함을 놓칩니다. 배포가 GitHub에 남는 이유는 opencode 프로덕션 에이전트 계약이 안정적이고, 이를 바꾸면 회귀 위험이 생기기 때문입니다. 2026-08-11 시나리오 B 워크스루(`docs/jobs/2026-08-11-openwebui-jobs.md` 참조)에서 검증됐으며, 이때 verifier가 runner health monitoring 계획의 Bootstrap paradox를 잡아냈습니다(planner는 놓쳤던 결함).

**jobs log와의 공존**: 전체 경계 매트릭스는 위 §"데이터 위치 원칙" 참조. 요약하면 jobs log는 세션 단위 진실(append-only), Linear 코멘트는 이슈별 대화, OpenViking은 jobs log를 watch해 자동 인제스션, mem0은 개인 선호 전용입니다.

## 릴리스 루틴 및 세션 연속성

릴리스·배포 경로를 건드리기 전에 아래를 참조하십시오. **충돌 시 권위 순서는 1 → 2 → 3입니다.**

1. **최상위 권위 (협업 규약)**: `docs/manual/github-control-plane-local-agent-handoff.ko.md` — **Protocol v1.2. 릴리스·배포 협업에 관한 모든 충돌에서 이 문서가 이깁니다.** 로컬↔프로덕션 에이전트 핸드오프, 통제 평면으로서의 GitHub, 필수 릴리스 흐름(문서를 포함한 모든 변경이 `feature/* → integration/vX.Y.Z → main`), 배포 요청 Issue 스키마, 프로덕션 에이전트 응답 계약, 인시던트 매트릭스, 상태 인지를 다룹니다.
2. **CI/CD 메커니즘 권위**: `docs/manual/github-actions-ghcr-release-deployment.md` — 태그 규칙, GHCR 관례, 이미지 빌드 정책. 충돌이 CI/CD 고유 사안이고 위 협업 규약이 다루지 않을 때 이깁니다. 저장소 역할(`origin` push 대상, `upstream` fetch 전용에 push URL `DISABLED`), 브랜치·릴리스 흐름, 이미지 빌드 정책(immutable 태그, `linux/amd64`, buildx registry 캐시, `v*-kwh.*` 워크플로 트리거, RC vs 최종 태그 의미), 배포 정책(compose 파일 역할, 사전 백업, 이전 이미지 태그로 롤백), slim vs non-slim 빌드의 모델 캐시 고려사항을 다룹니다.
3. **실무 루틴 (여기서 시작)**: `docs/manual/kwh-release-routine.md` — feature → integration → RC → 로컬 게이트 → PR → main → 최종 태그 → 프로덕션까지의 전 과정, 복사해 쓰는 명령 블록, 환경 변수 목록, SQLite WAL-safe 백업, 스모크 체크리스트, 복구 패턴.

기타 참조:

- **세션/작업 이력**: `~/projects/openwebui-service/docs/jobs/` 아래 `YYYY-MM-DD-openwebui-jobs.md`. 각 파일은 그날의 결정·커밋·PR·학습을 세션 간 컨텍스트로 남깁니다. 같은 날 작업은 `## HH:MM` 섹션으로 **append**, 날짜가 바뀌면 **새 파일**. 작업 반복을 피하려면 이전 날짜 로그를 먼저 확인합니다.
- **GHCR 이미지 태그 형식**: `vX.Y.Z-kwh.N` (git 태그 그대로, `v` 접두사 포함)과 `git-<7자리-short-sha>`. 접두사 없는 `X.Y.Z-kwh.N`이나 40자 전체 SHA는 발행되지 않으며 `docker pull`이 실패합니다.
- **`main`에 절대 직접 커밋하지 않습니다.** 로컬에서 실수했다면, 그 SHA에 `feature/<slug>` 브랜치를 만들어 커밋을 보존하고 `git reset --hard origin/main` 후 `--no-ff`로 integration에 병합합니다. 복구 검증 사례: 2026-07-22 커밋 `c68c745d2`.
- **모든 변경(문서 포함)**은 `feature/*` → `integration/vX.Y.Z` → PR → `main` 경로를 따릅니다. `feature/docs-*` → `main` 직행 단축 경로는 **폐지되었습니다** (2026-07-31).
