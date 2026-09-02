# Open WebUI Service — Claude Code 세션 시작 문서

Claude Code가 세션 시작 시 이 파일을 자동으로 읽습니다. 이 문서는 `@`-import로 `AGENTS.md`를 re-export하며, 그 결과 `AGENTS.md`가 Claude Code와 `AGENTS.md` 규약을 따르는 다른 에이전트 도구(Codex 등) 모두의 **단일 진실 소스**로 유지됩니다.

내용이 많은 수정은 `AGENTS.md` 또는 링크된 문서에 합니다. 아래 요약은 **의도적으로 중복**시킨 것입니다 — 별도 조회 없이 모든 Claude Code 세션의 컨텍스트에 남아 있어야 하기 때문입니다.

## 로컬 환경 — 반드시 먼저 알 것

- **로컬에서 `npm run build`를 실행하지 않습니다.** 이 개발 PC(7 GB RAM)는 `vite build`가 heap OOM으로 실패합니다. 빌드 권위는 **GitHub Actions**(`v*-kwh.*` 태그 트리거)이며, `scripts/local-test.sh`가 그 결과 이미지를 검증합니다.
- **Node는 `nvm use 22`**로 전환 후 사용합니다 (프로젝트 engine-strict `<=22.x`, 기본 PATH에는 Node 24가 잡혀 있음).
- **`gh` 명령에는 항상 `--repo kwh8121/openwebui-service`를 붙입니다.** `upstream` 리모트 때문에 `gh`가 기본적으로 upstream 저장소를 가리켜 PR 생성이 실패합니다.
- **검증 목적 명령은 절대 경로로 호출합니다** (`./node_modules/.bin/prettier`, `/usr/bin/curl`). `rtk` 훅이 결과를 위조한 사례가 있습니다.

전체 제약 목록은 `AGENTS.md` §"로컬 환경 제약"에 있습니다.

## 데이터 위치 원칙 (요약)

**One Fact, One Home** (2026-08-11 채택): Linear = 지금 할 일 (in-flight 계획·검증·상태) · jobs log = 오늘 실제로 한 일 · `docs/plan/` = 확정된 개발·리뷰 계획 (Linear plan-approved 이후 승격) · `docs/references/` = upstream Open WebUI 버전·기능 참고자료 · OpenViking = 다음 에이전트가 읽을 기억 (watch 대상: `docs/jobs/`, `docs/manual/`, `docs/plan/`, `docs/references/`, `AGENTS.md`, `CLAUDE.md`) · mem0 = 프로젝트 밖 개인 선호 (auto-capture 결과는 참고 캐시, 진실 소스 아님). `docs/manual/` vs `docs/references/` 경계 = fork-specific vs upstream. 전체 매트릭스와 promotion path는 `AGENTS.md` §"데이터 위치 원칙 — One Fact, One Home".

## 개발·릴리스 워크플로 — 5단계

1~4단계는 Linear(`koreatimes` 워크스페이스, 프로젝트 `openwebui vX.Y.Z`)를 사용하고, 5단계(배포)는 opencode 계약에 따라 GitHub Issue에 남습니다. 전체 정의는 `AGENTS.md` §"개발·릴리스 워크플로 (5단계)". 이슈별 라벨 진행: `plan-draft` → `needs-review` → `plan-approved` → (개발) → `verify-request` → `verify-passed` → (GitHub 배포 Issue).

## 프로덕션 릴리스 루틴 (한눈에)

5단계(프로덕션으로 향하는 모든 코드·자산 변경)용 요약입니다. 상세는 `docs/manual/kwh-release-routine.md`, 협업 규약(최상위 권위)은 `docs/manual/github-control-plane-local-agent-handoff.ko.md`(Protocol v1.2), CI/CD 메커니즘은 `docs/manual/github-actions-ghcr-release-deployment.md`.

1. **복구 가드**: 커스터마이징을 실수로 `main`에 커밋했다면, 그 SHA에서 `feature/<slug>` 브랜치를 만들고 → `git reset --hard origin/main` → `integration/vX.Y.Z`로 `--no-ff` 병합. (2026-07-22 커밋 `c68c745d2`로 검증됨.)
2. **feature 브랜치**: `git checkout integration/vX.Y.Z && git pull && git checkout -b feature/<slug>`; 커밋; 이후 `git checkout integration/vX.Y.Z && git merge --no-ff feature/<slug>`.
3. **push**: feature 브랜치와 integration 브랜치 모두 `origin`으로.
4. **RC 태그**를 integration tip에 발행: `git tag -a vX.Y.Z-kwh.N-rc.M <sha> -m "..."` → push → GH Actions가 `ghcr.io/kwh8121/openwebui-service:vX.Y.Z-kwh.N-rc.M` 빌드 (`v` 접두사 필수).
5. **로컬 프로덕션 미러 게이트 (RC)**: `./scripts/local-test.sh vX.Y.Z-kwh.N-rc.M --allow-rc`. 축적된 로컬 데이터 위에서 upgrade 마이그레이션·OAuth·pipelines·RAG·브랜드·`/health`를 검증합니다. 상세는 `docs/plan/local-test-workflow.md`. **운영 호스트 병렬 기동 방식의 스테이징 검증은 폐기됐습니다.**
   기동에 수 분 걸립니다(`/health` 대기 기본 600초). 느린 호스트에서는 `--health-timeout <초>`로 늘립니다 — `AGENTS.md` §"로컬 게이트 기동은 오래 걸립니다".
6. **PR** `integration/vX.Y.Z` → `main`; `--merge` 방식으로 병합; 로컬 `main` 동기화 (`git fetch && git checkout main && git pull --ff-only`).
7. **최종 태그**를 병합된 main tip에 발행: `git tag -a vX.Y.Z-kwh.N <sha> -m "..."` → push → GH Actions가 프로덕션 이미지 빌드.
8. **로컬 게이트 재실행 (최종 태그)**: `./scripts/local-test.sh vX.Y.Z-kwh.N`. 동일한 축적 데이터로 2차 게이트. 5번의 기동 시간 주의가 동일하게 적용됩니다.
9. **프로덕션 배포는 GitHub Issue 핸드오프로 수행합니다.** `Production deployment request` Issue를 제출하고(Protocol v1.2 §"배포 요청 계약"), 릴리스별 배포 가이드 `docs/manual/kwh-deploy-guide-vX.Y.Z-kwh.N.md`를 함께 커밋합니다. opencode 프로덕션 에이전트가 `deploy-approved-production-release.yaml` 워크플로로 실행하며, 이 워크플로가 SQLite WAL-safe 백업·이미지 pin·`--no-deps` 재기동·스모크를 자동 수행합니다. **로컬 에이전트가 프로덕션에 직접 SSH 배포하지 않습니다.**
10. **모든 변경(문서 포함)**은 동일 흐름을 따릅니다: `feature/*` → `integration/vX.Y.Z` → PR → `main`. `feature/docs-*` → `main` 직행 단축 경로는 **폐지되었습니다** (2026-07-31). 문서 전용 변경은 새 태그나 이미지 재빌드가 필요 없습니다.

**매 세션 반드시** 그날의 작업을 `docs/jobs/YYYY-MM-DD-openwebui-jobs.md`에 기록합니다 (같은 날은 append, 날짜가 바뀌면 새 파일). 시작 전 이전 날짜 로그를 확인해 작업 중복을 피합니다.

@AGENTS.md
