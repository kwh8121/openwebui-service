# One Fact, One Home — openwebui-service 개발·리뷰·배포 흐름 요약

작성 목적: 사용자가 이 프로젝트(`~/projects/openwebui-service`)의 계획→개발→리뷰→배포 전체 흐름과 이를 뒷받침하는 하네스 구성을 **단일 파일로 이해**하기 위한 요약. 상세 규약은 각 참조 문서에 있고, 이 문서는 색인 겸 개괄임.

- 진실 소스: `AGENTS.md` §"Data Location Principle" 및 §"Development And Release Workflow (5 Stages)"
- 이 파일: 개인 이해용 요약 (`docs/memo/`는 OpenViking watch 대상 아님)
- 최근 갱신: 2026-08-12 (PR #20 이후 상태 반영)

---

## 1. 원칙 — One Fact, One Home

**한 줄 요약**: 각 정보는 하나의 원본 위치(canonical home)만 갖는다. 다른 도구에는 링크·짧은 요약만 두고 원본을 복제하지 않는다.

### 정보 유형별 원본 위치

| 정보 유형                                  | 원본 위치                                               | 다른 도구에는 어떻게 둘 것인가                     |
| ------------------------------------------ | ------------------------------------------------------- | -------------------------------------------------- |
| 계획안, 검증 요청, 상태 전이 (in-flight)   | **Linear** (`koreatimes` 워크스페이스)                  | jobs log에는 결과 요약만                           |
| **확정된 개발·리뷰 계획 (approved plans)** | **`docs/plan/`**                                        | Linear 이슈 유지 + `create_attachment`로 파일 링크 |
| 세션에서 실제로 한 일                      | **jobs log** (`docs/jobs/YYYY-MM-DD-openwebui-jobs.md`) | OpenViking watch로 자동 인제스션                   |
| 코드 변경, 브랜치, PR, 태그                | **Git / GitHub**                                        | Linear·jobs log에는 링크와 요약만                  |
| 배포 승인·결과 evidence                    | **GitHub Issue** (`production-deploy` 라벨)             | Linear에는 `create_attachment` 링크만              |
| **upstream Open WebUI 버전·기능 참고자료** | **`docs/references/`**                                  | jobs log에는 참조 링크만                           |
| 장기 학습, 반복 실수, 운영 원칙            | jobs log → **OpenViking**                               | mem0에는 넣지 않음 (참고 캐시 허용)                |
| 개인 선호, 답변 스타일, 일반 습관          | **mem0**                                                | 프로젝트 문서에는 넣지 않음                        |

### 4-도구 역할 (한 줄 요약)

- **Linear** = 지금 할 일 (in-flight 계획·검증·상태)
- **jobs log** = 오늘 실제로 한 일 (append-only 감사 기록)
- **OpenViking** = 다음 에이전트가 읽을 장기 컨텍스트
- **mem0** = 프로젝트 밖 개인 선호 (auto-capture 결과는 참고 캐시, 진실 소스 아님)

### `docs/manual/` vs `docs/references/` 경계 원칙 (2026-08-11 채택)

- **`docs/manual/`** = **이 fork의** 배포·운영·정책 문서. fork 이력에 종속.
  - 예: `kwh-release-routine.md`, `github-control-plane-local-agent-handoff.ko.md`, `github-actions-ghcr-release-deployment.md`, `kwh-deploy-guide-v0.11.0-kwh.1.md`, `openwebui-oauth-provider-registration-notes.md`
- **`docs/references/`** = **upstream Open WebUI에 관한** 조사·업데이트·기능 참고. fork와 무관하게 upstream 변화만 반영.
  - 예: `OpenWebUI_업데이트_리포트_YYYY-MM-DD.md`, `openwebui-*-research.md`

---

## 2. 5-단계 개발·리뷰·배포 워크플로

전체 라이프사이클. Stages 1–4는 Linear에서 관리, Stage 5는 GitHub Issue (opencode 프로덕션 에이전트 계약 유지).

```
[1] 계획 (Linear)              plan-draft
        ↓ Planner 완료
[2] 계획 검증 (Linear)         needs-review ↔ plan-approved (반려 시 plan-draft로 복귀)
        ↓ 승인 후 docs/plan/으로 승격 (수동)
[3] 개발 (git)                 feature/* → integration/vX.Y.Z → main, PR 머지
        ↓ 개발 완료
[4] 개발 검증 (Linear)         verify-request ↔ verify-passed
        ↓ 검증 통과
[5] 배포 (GitHub Issue)        production-deploy Issue → opencode 실행
```

### Stage 1 — 계획 (Planning)

- **주체**: Planner 에이전트
- **도구**: Linear MCP `save_project`, `save_issue`
- **산출물**: Linear Project (예: `openwebui v0.11.1`) + Parent Issue + Sub-issues (계층 구조)
- **필수 필드**: `title`, `description` (배경/목표/비목표/스코프/DoD/의존성), `labels: [plan-draft]`, `parentId`, `blockedBy`
- **자동 획득**: `gitBranchName` (Linear가 issue 생성 시 자동 생성. 예: `kwh8121/kor-5-runner-health-monitoring-automation`)
- **완료 시**: Planner가 parent 라벨 `plan-draft` → `needs-review` 전환

### Stage 2 — 계획 검증 (Plan Verification)

- **주체**: Verifier 에이전트 (Planner와 역할 분리)
- **Pickup**: `list_issues --label needs-review`
- **검증 관점**: 스코프 완결성 · 참조 문서 실존 · Sub-issue 커버리지 · DoD 실행 가능성 · Bootstrap paradox 등 설계 결함
- **회신**: `save_comment`로 각 이슈에 PASS/CRITICAL/MEDIUM/MINOR + verdict 게시
- **판정 라벨 전이**:
  - 승인 → `plan-approved`
  - 반려 → `plan-draft` (Planner에게 revision 요청 신호)
- **승격**: 승인된 계획을 `docs/plan/<slug>.md`로 파일 작성 후 Linear 이슈에 `create_attachment`로 파일 URL 첨부 (수동)

### Stage 3 — 개발 (Development)

- **주체**: Dev 에이전트
- **Pickup**: `list_issues --label plan-approved` (blocked 여부 별도 판단 — `blockedBy` 관계 확인)
- **브랜치**: Linear 이슈의 `gitBranchName` 필드 사용 (예: `feature/koreatimes-loading-splash`)
- **흐름**: `feature/* → integration/vX.Y.Z → main` PR (§5 참조)
- **Linear**: 이슈를 "In Progress"로 두고 진행 포인터로만 사용. 코드 진실은 git.
- **완료**: PR 머지 후 이슈 라벨을 `verify-request`로 전환

### Stage 4 — 개발 검증 (Dev Review)

- **주체**: Verifier 에이전트
- **Pickup**: `list_issues --label verify-request`
- **재료**: GitHub PR (Linear 이슈에 `create_attachment`로 링크됨), diff, 실제 실행 결과
- **회신**: `save_comment`로 리뷰 결과. `verify-passed` 또는 `verify-request` 유지 (재작업)
- **완료**: `verify-passed` 라벨 도달 시 Stage 5로 인계

### Stage 5 — 배포 (Deployment) — **GitHub Issue 유지 (opencode 계약)**

- **주체**: 로컬 dev 에이전트 (Issue 생성) → opencode 프로덕션 에이전트 (실행) → 관리자 (승인)
- **Issue 형식**: `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` 폼 사용, 라벨 `production-deploy`
- **Issue 필수 필드** (handoff v1.2 §"배포 요청 계약"):
  - Release tag (`v<X.Y.Z>-kwh.<N>`)
  - Main tip SHA (40자)
  - GHCR build Run URL, Image digest (`sha256:...`)
  - Deploy guide 경로 + commit SHA (`docs/manual/kwh-deploy-guide-<tag>.md at commit <SHA>`)
  - Rollback tag (현재 프로덕션 태그)
  - Local verification 결과 (`scripts/local-test.sh v4.2`)
  - Migration risk / Fork carryovers / Browser checks required
- **워크플로**: `.github/workflows/deploy-approved-production-release.yaml`가 `production` GitHub Environment 승인 후 self-hosted runner `openwebui-prod-runner`에서 실행. Tag 검증·백업·pull·up·health poll·log scan 9개 하드닝 검증 수행.
- **관리자 최소 액션 4가지**:
  1. `production` Environment 승인 클릭
  2. `## Deployment success` 코멘트 확인
  3. 브라우저 acceptance 검수 → `## Browser acceptance` 코멘트 게시
  4. 다음 세션 시작 시 로컬 에이전트에게 Issue URL relay
- **Linear ↔ GitHub 브릿지**: Linear 이슈에 `create_attachment`로 GitHub 배포 Issue URL 첨부 → 감사 추적 완결

---

## 3. Linear 라벨 vocabulary (workspace-level, 2026-08-11 생성)

| Label            | Color  | 의미                             |
| ---------------- | ------ | -------------------------------- |
| `plan-draft`     | gray   | Planner 작성 중                  |
| `needs-review`   | yellow | 계획 완성, 검증 대기             |
| `plan-approved`  | teal   | 검증 통과, dev 착수 준비         |
| `verify-request` | orange | 개발 완료, 검증 대기             |
| `verify-passed`  | green  | 검증 통과, GitHub 배포 인계 준비 |

**전이 요약**: `plan-draft` → `needs-review` → `plan-approved` → (dev) → `verify-request` → `verify-passed` → (GitHub deploy Issue).

---

## 4. Git·GitHub 흐름 (Stage 3)

**필수 규약** (handoff v1.2, `docs/manual/github-actions-ghcr-release-deployment.md`):

```
feature/<slug>         ← 개발 브랜치 (Linear gitBranchName 사용)
    │  --no-ff merge
    ▼
integration/vX.Y.Z     ← 통합 브랜치
    │  PR
    ▼
main                   ← 배포 대상 tip
    │  tag
    ▼
vX.Y.Z-kwh.N           ← immutable tag → GHCR image build 트리거
```

**규칙:**

- Doc-only 변경도 동일 경로 (`feature/docs-* → main` 우회 폐기, 2026-07-31)
- `main`에 직접 커밋 금지 (실수 시 recovery: feature 브랜치 파고 `git reset --hard origin/main`)
- Immutable tag 재작성 금지 (수정은 항상 `-kwh.<N+1>` 새 태그)
- GHCR 이미지 태그: `vX.Y.Z-kwh.N` (v prefix 필수) + `git-<7-char-short-sha>`

**PR 예시** (이 세션 흐름):

- PR #17: docs 5-stage workflow
- PR #18: Data Location Principle
- PR #19: docs/jobs 백필 커밋
- PR #20: docs/plan + docs/references 채택

---

## 5. Promotion Path — 확정 계획·업스트림 참고자료 승격 (수동)

**Linear plan-approved → `docs/plan/`**

1. Linear에서 parent 이슈 `plan-approved` 도달
2. 승인된 계획 내용을 `docs/plan/<slug>.md` 파일로 정리 (immutable 스냅샷)
3. Linear 이슈에 `create_attachment`로 파일 링크 (stage 3~4 포인터 유지, 이슈 close하지 않음)
4. feature 브랜치 통해 commit → PR → main

**Upstream 관찰 → `docs/references/`**

1. Upstream Open WebUI 릴리스·기능 발견 (예: `open-webui/open-webui` 새 태그, 블로그 포스트)
2. `docs/references/<slug>.md` 작성 (fork와 무관한 관점)
3. feature 브랜치 → PR → main

두 폴더 모두 GitHub repo watch(24h)로 OpenViking 자동 인제스션.

---

## 6. OpenViking 자동화

- **Watch 등록**: `viking://resources/kwh8121/openwebui-service` (2026-08-11 등록, 24h refresh)
- **Watch 대상 경로** (repo tracked 파일 중):
  - `docs/jobs/` — 세션 로그
  - `docs/manual/` — fork 운영 문서
  - `docs/plan/` — 확정 계획
  - `docs/references/` — upstream 참고
  - `AGENTS.md`, `CLAUDE.md` — 프로젝트 루트 규약
- **인제스션 흐름**: git push → 24h 내 다음 refresh cycle에서 repo re-ingest → 신규/변경 파일이 vector DB에 반영
- **가시성**: 다음 세션 재개 시 `SessionStart` context에 자동 injection

**`docs/memo/` 는 watch 대상 아님** — 개인 노트 성격 (이 파일 포함). 인용용 진실 소스는 AGENTS.md.

---

## 7. jobs log 관례

- **파일명**: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (시스템 로컬 시각 KST 기준, 사용자 입력 파일명 무시)
- **같은 날 여러 세션**: 하단에 `## HH:MM — <제목>` append (신규 파일 생성 아님)
- **커밋 관례**: 2026-08-11부터 커밋 대상 (그 이전에는 로컬만 저장). OpenViking watch 커버를 위해 규약 전환.
- **저장 스킬**: `~/.claude/skills/openwebui-jobs/SKILL.md` (사용자 발화 트리거: "openwebui 작업 저장", "openwebui-jobs 저장", "/openwebui-jobs" 등)
- **스킬 특성**: `AskUserQuestion`으로 append vs 신규 sibling 파일 확인. 자동 커밋 안 함 (사람이 별도 스텝으로 커밋).

**jobs log에 담아야 할 것:**

- 그날의 실제 활동·결정 (자동 요약)
- 이슈/PR/커밋 링크 + 짧은 요약
- 발견된 문제·미해결 사항
- 다음 세션 재개 지점 (`> Resume: claude --resume <UUID>`)
- 학습 사항 (→ OpenViking 이관 대상)
- Linear 이슈 상태 전이 요약 (본문 아님)
- GitHub 배포 이슈·태그 이벤트 요약

**jobs log에 담지 말아야 할 것:**

- Linear 이슈 본문·코멘트 원문 (링크만)
- 코드 diff 전체 (커밋/PR 링크만)
- 계획 검토 대화 원문 (Linear 코멘트 스레드 링크)
- mem0 auto-capture 결과 (mem0에서 별도 조회)

---

## 8. 하네스 구성 (Claude Code 세션 관점)

| 구성요소                  | 정체                                           | 역할                                                           |
| ------------------------- | ---------------------------------------------- | -------------------------------------------------------------- |
| Claude Code CLI           | Anthropic 공식 CLI                             | 세션 컨테이너                                                  |
| **openwebui-jobs 스킬**   | `~/.claude/skills/openwebui-jobs/SKILL.md`     | 세션 로그 저장 (jobs log gateway)                              |
| **Linear MCP**            | `linear-server` (`https://mcp.linear.app/mcp`) | 5-단계 워크플로 stages 1·2·4 조작                              |
| **OpenViking MCP**        | `openviking-memory` 플러그인                   | 장기 컨텍스트 DB, 24h watch                                    |
| **mem0 MCP**              | `mem0.ai` 플러그인                             | 개인 선호 (auto-capture 훅 유지, 참고 캐시)                    |
| **gh CLI**                | GitHub CLI                                     | Stage 3·5 (PR·Issue·workflow dispatch)                         |
| **Serena MCP**            | 코드 심볼 인덱스                               | 코드 탐색 (필요 시)                                            |
| **오래된 mem0 auto-hook** | SessionStart / UserPromptSubmit                | 프로젝트 결정도 mem0에 저장 (참고 캐시로 인정, 진실 소스 아님) |

**핵심 소통 채널 매핑**:

| 채널                                         | 도구                                                        |
| -------------------------------------------- | ----------------------------------------------------------- |
| 개발자 ↔ Planner 에이전트                    | 대화 (직접)                                                 |
| Planner ↔ Verifier                           | Linear 이슈 + 코멘트                                        |
| Dev 에이전트 ↔ Verifier                      | Linear 이슈 라벨 + 코멘트 + GitHub PR 첨부                  |
| 로컬 에이전트 ↔ 프로덕션 에이전트 (opencode) | GitHub Issue (`production-deploy` 라벨)                     |
| 프로덕션 에이전트 ↔ 관리자                   | GitHub Environment 승인 + Issue 코멘트 (browser acceptance) |
| 세션 A ↔ 세션 B (같은 프로젝트)              | jobs log + OpenViking watch                                 |

---

## 9. 실전 예시 — 하나의 기능 릴리스 처음부터 끝까지

가상 예시: "runner heartbeat monitoring 자동화" (실제 v0.11.1 계획 재료)

```
[1] Planner (사용자 대화)
    → save_project "openwebui v0.11.1"
    → save_issue KOR-5 "Runner health monitoring automation" (label: plan-draft)
    → sub-issues KOR-6/7/8 (blockedBy 관계)
    → KOR-5 label → needs-review

[2] Verifier (동일 세션 or 별도 세션)
    → list_issues --label needs-review → KOR-5 pickup
    → 참조 문서 실존 검증, sub-issue 스코프 확인
    → CRITICAL 발견 (예: Bootstrap paradox)
    → save_comment (PASS/CRITICAL/MEDIUM/MINOR + verdict)
    → KOR-5 label → plan-draft (revision 요청)

[2'] 재작성 후 재검증
    → sub-issue 신설, 스코프 조정
    → KOR-5 label → plan-approved
    → 계획 요약을 docs/plan/runner-health-monitoring.md 작성
    → feature/docs-plan-runner-health 브랜치 → integration → PR → main
    → Linear 이슈에 create_attachment로 파일 URL 첨부

[3] Dev (별도 세션 or 계속)
    → KOR-6부터 착수 (blocked 없음)
    → gitBranchName "kwh8121/kor-6-design-heartbeat-check-protocol" 사용
    → feature 브랜치에서 docs/manual/runner-heartbeat-protocol.md 작성
    → integration → PR → main
    → KOR-6 label → verify-request

[4] Verifier
    → list_issues --label verify-request → KOR-6 pickup
    → PR diff 리뷰, protocol 실행 가능성 검증
    → save_comment verdict
    → KOR-6 label → verify-passed
    (KOR-7·8 반복)

[5] 배포 (모든 sub-issue verify-passed 이후)
    → 로컬 에이전트가 GitHub Issue 생성 (production_deployment_request 폼)
    → 관리자 production Environment 승인
    → opencode 프로덕션 에이전트 workflow 자동 실행
    → 성공 시 Issue에 ## Deployment success 코멘트
    → 관리자 브라우저 검수 → ## Browser acceptance PASS 코멘트
    → Linear 이슈들에 create_attachment로 GitHub deploy Issue URL 첨부
```

각 단계에서 jobs log에는 "무엇을 했는가·다음은 어디" 요약만 append. Linear·GitHub 원문은 링크로만 참조.

---

## 10. 문서 우선순위 (충돌 시 위가 우선)

1. **최상위 권위**: `docs/manual/github-control-plane-local-agent-handoff.ko.md` (Protocol v1.2, 2026-07-31)
2. **CI/CD 규약**: `docs/manual/github-actions-ghcr-release-deployment.md`
3. **실용 릴리스 루틴**: `docs/manual/kwh-release-routine.md` (§7 폐기, 나머지 참고)
4. **프로젝트 delivery constraint + Data Location Principle + 5-Stage Workflow**: `AGENTS.md`
5. **세션 요약 (매 세션 자동 로드)**: `CLAUDE.md`
6. **Per-release deploy guides**: `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`
7. **확정 계획**: `docs/plan/`
8. **Upstream 참고자료**: `docs/references/`
9. **세션 로그**: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md`
10. **개인 이해 요약 (이 파일)**: `docs/memo/one-fact-one-home.md`

---

## 11. 인프라 현재 상태 (2026-08-12 기준)

**GitHub 저장소:**

- 원본: `https://github.com/kwh8121/openwebui-service`
- Main tip: `a97033fc7` (PR #20 머지 후)
- `integration/v0.11.0` = main과 동기
- 프로덕션 이미지: `ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1`

**컨트롤 플레인:**

- `production` GitHub Environment (required reviewer: `kwh8121`)
- Self-hosted runner `openwebui-prod-runner` (systemd active, labels `self-hosted, Linux, X64, production`)
- Workflow `.github/workflows/deploy-approved-production-release.yaml` (296줄, v1.2 하드닝 완료)
- Issue form `.github/ISSUE_TEMPLATE/production_deployment_request.yaml`

**Linear:**

- Workspace: `koreatimes` (id `4342ee5a-...`)
- Team: `Koreatimes` (KOR)
- Project: `openwebui v0.11.1` (v0.11.1 kwh 사이클 계획 컨테이너)
- 활성 이슈: KOR-5~8 (Runner health monitoring 계획, plan-draft 상태)

**OpenViking:**

- Resource: `viking://resources/kwh8121/openwebui-service`
- Watch: 24h refresh, 자동 인제스션

---

## 12. 잔여·미완 사항 (기억용)

- **KOR-5 Bootstrap paradox revision**: 검증에서 발견된 설계 결함 반영해 sub-issue 재구성 필요 (다음 착수)
- **기존 jobs log 소급 인제스션 여부**: watch는 향후 refresh부터 커버. 과거 파일도 이미 커밋된 상태라 다음 24h cycle에서 자동 흡수 예상.
- **mem0 저장 용량 관리**: auto-capture 결과가 계속 누적. 주기적 정리 필요 시 mem0:dream / mem0:forget 스킬 활용.
- **경계 모호 파일 재분류**: `docs/manual/korean-locale-image-notes.md`, `docs/manual/openwebui-repo.md`는 upstream 참고 성격이 강함. 재분류 판단은 별도.
- **`.gitignore` 추가 판단**: `.claude/`, `.opencode/`, `docs/SESSION.md`, `docs/manual/opencode-notebooklm-*.md` 등 untracked 파일 유지·정리 판단 필요.

---

## 참조

- 상세 규약: `AGENTS.md`, `CLAUDE.md`, `docs/manual/github-control-plane-local-agent-handoff.ko.md`
- 세션 이력: `docs/jobs/2026-07-21` ~ `2026-08-11` (특히 `2026-08-11-openwebui-jobs.md`가 이 규약 채택 배경)
- 스킬: `~/.claude/skills/openwebui-jobs/SKILL.md`
- 이 파일 갱신 관례: AGENTS.md 갱신 시 수동 동기. `docs/memo/`는 watch 대상 아니므로 진실 소스가 아님을 명심.
