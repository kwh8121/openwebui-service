# Open WebUI Jobs Log — 2026-08-11

## 요약

- 시나리오 B (Linear 이슈 기반 계획→검증 인계) full-cycle 검증 완료. Planner/Verifier 두 역할을 한 세션에서 시연.
- Linear 워크스페이스 `koreatimes` 초기 구성: workflow 라벨 5개, Project `openwebui v0.11.1`, 부모 이슈 KOR-5 + sub-issues KOR-6~8 (4개 이슈) 생성.
- Verifier가 계획에서 **CRITICAL 설계 결함 발견**: "Bootstrap paradox" — runner를 모니터링하는 workflow가 해당 runner 위에서 실행되면 runner offline을 감지 불가. Planner가 놓친 근본 결함을 comment로 영구 기록.
- 결과: KOR-5 라벨 `needs-review` → `plan-draft`로 반환 (revision 요청 신호). Linear가 이 반환 신호를 자연 표현.
- 5단계 워크플로우(계획→검증→개발→개발검증→배포) 채택 결정. 배포(stage 5)는 opencode 계약 유지 위해 GitHub Issue 그대로 유지.
- AGENTS.md, CLAUDE.md에 5단계 명문화 진행 (별도 feature 브랜치 → integration/v0.11.0 → PR).

## 세션 흐름 (Reviewer가 나중에 이 로그로 복기 가능하도록 작성)

### Phase 1 — 초기 세팅 (Orca + Linear MCP)

- Orca ADE에서 `gh CLI: Not Installed` 표시 원인 진단: Windows 데스크톱 앱이 WSL PATH를 미조회. 해결안 A(Windows에 gh 설치) vs B(Orca 원격 서버로 WSL 연결) 제시, B 권장. → **실행 안 함, 다음 세션 결정 대기**.
- Linear MCP 서버 로컬 등록: `claude mcp add --transport http linear-server https://mcp.linear.app/mcp`. OAuth flow는 WSL 특성상 callback URL 수동 처리 필요할 수 있음 안내 → 실제로는 자동 완료됨.
- 워크스페이스 `koreatimes` 연결 확인 (id `4342ee5a-...`), 팀 `Koreatimes` 단독 (id `5604ec99-...`), 초기 이슈 4건 (온보딩 KOR-1~4).
- Linear MCP 도구 54개 카탈로그화. 4개 시나리오(A/B/C/D) 정리.

### Phase 2 — 5단계 워크플로우 설계

**결정**: 계획 + 계획 검증 단계에서 Linear 사용 실익이 있으므로 채택. 단, 아래 조건 준수:
1. jobs log는 여전히 진실 소스 유지 (Linear는 계획·검토 대화용, jobs log는 감사·세션 재개용). 이관하지 말고 양립.
2. 개발 단계부터는 git이 진실 소스. Linear 이슈는 "어떤 계획 항목을 작업 중"이라는 포인터 역할만.
3. 배포는 GitHub Issue 유지 (opencode 프로덕션 에이전트 계약 불변).
4. Linear ↔ GitHub 브리지는 `create_attachment`로 얇게.

**5단계**:
```
[1] 계획 (Linear)      Project + Parent + Sub-issues, label: plan-draft
[2] 계획 검증 (Linear) label: needs-review ↔ plan-approved (or plan-draft for revision)
[3] 개발 (git)         feature/* branch (gitBranchName from Linear), issue = 진행 포인터
[4] 개발 검증 (Linear) label: verify-request ↔ verify-passed
[5] 배포 (GitHub)      opencode 계약 유지, Linear에서 attachment로 GitHub Issue 링크
```

### Phase 3 — 실전 시연 (테스트 재료 = handoff v1.3 "러너 health 자동화")

**Step A** — 라벨 5개 생성 (workspace-level):
- `plan-draft` (gray), `needs-review` (yellow), `plan-approved` (teal), `verify-request` (orange), `verify-passed` (green)
- 색상 톤을 stage 흐름에 맞게 (초기 회색 → 승인 녹색)

**Step B** — Project `openwebui v0.11.1` 생성:
- Lead: 곽원희, Icon: Rocket, Priority: Medium, Status: Backlog
- Description에 5단계 boundaries + label workflow 명시

**Step C** — 계획 이슈 4개 생성 (Planner 시뮬레이션):
- KOR-5 Parent: "Runner health monitoring automation" (label: plan-draft → needs-review)
- KOR-6 Sub 1: "Design heartbeat check protocol"
- KOR-7 Sub 2: "Implement heartbeat scheduled workflow" (blocked by KOR-6)
- KOR-8 Sub 3: "Add alerting on missed heartbeat" (blocked by KOR-6, KOR-7)
- 각 이슈에 목표·비목표·산출물·검증 기준·의존성 명시. `gitBranchName` 필드 자동 생성 확인.

**Step D** — 계획 검증 시뮬레이션 (Verifier 역할, 저 자신이 역할 분리 수행):
- Pickup: `list_issues --label needs-review` → KOR-5 확인
- 실측 검증:
  - 참조 문서 `docs/manual/github-control-plane-local-agent-handoff.ko.md` 실존 확인 (grep 2 matches)
  - 신규 workflow 파일명 `runner-heartbeat.yaml` 기존 10개 파일과 collision 없음 확인
- 발견 사항을 각 이슈에 코멘트로 회신 (verdict + PASS/CRITICAL/MEDIUM/MINOR 등급).

## 리뷰어 관점 — 발견 사항과 판단 근거

### CRITICAL: Bootstrap paradox (전 이슈 공통)

**결함**: 3개 sub-issue 모두 self-hosted runner에서 실행되는 workflow를 전제. 그런데 스코프의 최대 실패 시나리오는 **runner 자체가 offline**인 경우. 이 경우 heartbeat workflow는 실행조차 되지 못하므로 실패 신호가 생성되지 않음. 결과적으로 자동화의 존재 이유("runner offline 감지")가 무효화됨.

**왜 planner가 놓쳤나**: 계획서에 "systemd active + gh runner online + docker + GHCR + 데이터 경로" 등 healthy 정의를 정교하게 나열하면서, "정의를 검증하는 주체 자체가 실패할 수 있다"는 메타 관점을 놓침. 텍스트로만 계획을 정리할 때 흔히 발생하는 시야 축소.

**권장 조치**: sub-issue 추가 필요 — `runner-watchdog` github-hosted workflow (`ubuntu-latest`, external monitor). `gh api actions/runners`로 runner 상태 조회 + "last successful heartbeat" recency 검사. 이 watchdog는 runner에 의존하지 않으므로 self-hosted 실패를 커버.

### MEDIUM 발견 요약

- **KOR-6**: 각 체크 command의 개별 timeout 없음 (docker info hang 시 workflow 5분 소진 가능). cron 지연 window 미정의.
- **KOR-7**: `gh api actions/runners` scope 명시 필요 (`actions:read`). Step 8 결과 종합의 exit code 규칙 미정.
- **KOR-8**: 두 workflow(heartbeat + watchdog)가 동일 Issue를 동시 조회·생성할 때 race condition. Actions `concurrency` group으로 두 workflow 큐잉 필요.

### MINOR

- GHCR 검증에 `docker manifest inspect`가 `docker pull --quiet`보다 우수 (다운로드 없이 인증만 확인).
- `test -w`가 심볼릭 링크 뒤 실제 대상 미검증.
- Slack option secret은 org-level 등록 권장 (repo-level은 fork 유출 위험).

### 각 이슈 verdict

| 이슈 | Verdict |
|------|---------|
| KOR-5 | NEEDS REVISION (CRITICAL: watchdog sub-issue 필요) |
| KOR-6 | NEEDS MINOR REVISION (timeout·cron 스펙) |
| KOR-7 | NEEDS REVISION (workflow 분리) |
| KOR-8 | APPROVED WITH CHANGES (재사용 구조) |

**상태 전이**: KOR-5 라벨 `needs-review` → `plan-draft` 반환 (revision 요청).

## Linear 사용감 평가

### 잘한 것

| 요소 | 관찰 |
|------|------|
| 계층 구조 | Parent-Sub-issue UI 자동. jobs log의 flat markdown 대비 명확 |
| 의존성 시각화 | Blocked by 관계가 UI에 표시. 개발 pickup 시 순서 판단 자연스러움 |
| 라벨 상태 머신 | 5-라벨 전이가 워크플로우 신호 역할 수행. 라벨 변경만으로 다음 단계 트리거 |
| 코멘트 = 감사 추적 | 4개 이슈에 verifier의 상세 발견 영구 기록. 다음 revision 사이클에서 참조 가능 |
| `gitBranchName` | planning 단계부터 개발 브랜치명 예고. 팀 규약 강제 효과 |
| MCP 도구 성숙도 | 첫 시도에 모두 성공. 스키마 명확, 오류 없음 |

### 마찰

| 요소 | 관찰 |
|------|------|
| 초기 셋업 비용 | 라벨 5 + Project 1 = 6번 API 호출. idempotent bootstrap 스크립트 필요 |
| status ≠ label | Linear status(Backlog/Todo/Done)와 workflow label 병존. 매핑 여부 나중 결정 |
| Blocked 상태 필터링 부재 | `list_issues --label`로는 blocked 여부 안 나옴. 개발 pickup 시 "실제 시작 가능" 판단 로직 별도 필요 |
| 이중 관리 | Linear 코멘트 + jobs log 병존 → 어느 것이 진실 소스인지 관습화 필요 |
| 워크스페이스 vs 팀 스코프 | 라벨을 workspace로 만들었으나 팀별 정책 다르면 재정리 |

### 실효 판정

- **계획 + 검증 (Stage 1-2)**: **Linear 실효 있음.** 특히 오늘 Bootstrap paradox처럼 텍스트만으로는 놓치기 쉬운 설계 결함이 comment thread에 영구 기록되어 revision 순환에서 유실 안 됨. jobs log는 append-only라 이런 대화형 검증 어려움.
- **개발 (Stage 3)**: Linear는 "지금 어떤 계획 작업 중" 포인터로 충분. git이 진실 소스.
- **개발 검증 (Stage 4)**: 같은 label workflow 재사용. 오늘 시연 pattern 그대로 적용.
- **배포 (Stage 5)**: GitHub + opencode 유지. 변경 시 회귀 위험. Linear에서 `create_attachment`로 링크만 첨부.

## 후속 결정 사항

### 유지된 이슈들 (테스트 → 실제 계획으로 승격)

KOR-5~8을 삭제하지 않고 실제 v0.11.1 사이클 계획 재료로 유지. Bootstrap paradox 반영해 revision 필요:
1. KOR-5에 watchdog 관련 sub-issue 추가 (신설 KOR-9 예상)
2. KOR-7 스코프를 self-hosted heartbeat만으로 축소
3. KOR-8을 재사용 alerting composite action으로 재정의
4. KOR-6에 external watchdog protocol 추가 + timeout·cron window 스펙

이 revision은 다음 세션의 실제 착수 작업. 오늘은 워크플로우 검증까지만.

### 문서 명문화 (병렬 진행)

AGENTS.md, CLAUDE.md에 5단계 워크플로우 명문화. feature 브랜치 `feature/docs-linear-5stage-workflow → integration/v0.11.0 → main` PR로 처리 예정.

## 커밋 / PR

**이 세션에서 발생한 Linear 아티팩트** (커밋 대상 아님):
- Labels: plan-draft, needs-review, plan-approved, verify-request, verify-passed
- Project: openwebui v0.11.1
- Issues: KOR-5, KOR-6, KOR-7, KOR-8 + 4개 verification comment

**커밋 예정** (다음 스텝):
- AGENTS.md, CLAUDE.md 5단계 명문화

## 학습 사항

- **Verifier의 존재 이유가 오늘 세션에서 즉시 증명됨**: Planner가 사려깊게 작성한 계획도 Bootstrap paradox 같은 근본 결함을 포함할 수 있음. 텍스트로 자기검토만 하면 놓침. Verifier가 별도 사이클로 검증하면 잡힘. Linear의 comment thread가 이 발견을 revision 순환 사이에서 유실 없이 보존.
- **Linear의 label = workflow state machine**: 5개 라벨의 전이만으로 스테이지 신호 전달 충분. 커스텀 status 정의 없이도 workflow 표현 가능. 시작 오버헤드 최소.
- **`gitBranchName` 필드가 예상 밖 이득**: planning 단계에서 이미 개발 브랜치명이 확정되므로, 개발 착수 시 이름 고민 없음. 팀 관례 자동 강제.
- **자기 자신을 role-play로 분리한 검증도 가치 있음**: 오늘은 저 혼자 Planner+Verifier 역할을 했지만, 검증 관점을 명시적으로 분리하니 실제 결함이 발견됨. 두 에이전트로 실제 분리하면 이 효과가 강화될 전망.
- **jobs log와 Linear는 상호보완**: Linear 코멘트는 이슈별 대화, jobs log는 세션·날짜별 요약. 겹치지 않게 사용하면 이중 관리 아님. 오늘 이 로그가 그 예시.

## 미커밋 상태

이 로그 파일 (`docs/jobs/2026-08-11-openwebui-jobs.md`)은 로컬만 저장. 커밋 안 함 (이전 관례 유지).

```bash
git add docs/jobs/2026-08-11-openwebui-jobs.md
git commit -m "docs: add 2026-08-11 openwebui jobs log"
```
