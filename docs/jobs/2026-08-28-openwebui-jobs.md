# Open WebUI Jobs Log — 2026-08-28

> Resume: `claude --resume 086651c3-9ca8-497d-96cd-bd6cc483ea64`

## 요약

upstream `v0.11.1` 릴리스 감지 후 통합 사이클 킥오프 세션. `docs/plan/v0.11.1-integration.md` 초안 작성·검토·정정, opencode-notebooklm 매뉴얼 커밋, personal-scope `.gitignore` 확장, `integration/v0.11.1` 신규 브랜치와 4개 feature 브랜치 분리 커밋 후 PR #21 오픈. `v0.11.0-kwh.1` 로컬 게이트를 baseline 검증용으로 실행 — 스크립트는 60s `/health` 타임아웃으로 FAIL 판정했으나 컨테이너는 정상 healthy, 브랜드·config 자동/수동 검증 모두 PASS.

## 작업 흐름

1. **Linear MCP·CLI 상태 점검**
   - `linear-server` MCP `✓ Connected` 확인. read-only 스모크(get_workspace/user/teams/projects/issues) 모두 성공.
   - Claude Code CLI 2.1.119 → 2.1.241 업데이트. multi-install(native + npm) 정리로 native(`~/.local/bin/claude`, `~/.local/lib/node_modules/@anthropic-ai/claude-code`) 제거, nvm 경로 단일화.
   - OMC v5.0.0 upstream 릴리스 조사 → 17개 워크플로 이름 alias 없이 breaking removal. CLAUDE.md v4 트리거(`ulw`, `ccg`, `mcp-setup`, `omc-reference`) 즉시 무효화 위험으로 **v4.15.10 유지 결정**.

2. **v0.11.1 통합 사이클 킥오프**
   - upstream `open-webui/open-webui` v0.11.1(2026-08-25) 감지. Linear 프로젝트 `openwebui v0.11.1` (Backlog, `f4687915-d8e5-4ba1-b368-54659f68a2a3`)이 이미 존재하나 통합 이슈는 미생성.
   - upstream v0.11.0..v0.11.1 diff 400+ 커밋 중 refactor 제외 실질 변경 파악: 보안 권고 포함(knowledge 검색 ACL 우회, 문서 zip-bomb, 스트리밍 조기 종료, 웹 fetch 필터 우회), Streaming rebuilt 델타 프로토콜, Human-in-the-loop 툴 승인, 비밀번호 변경 시 타 세션 종료(Redis 필요), OAuth env read-only 표시, 성능 개선 다수.
   - fork 커스터마이징 인벤토리 재확인(v0.11.0..v0.11.0-kwh.1): `171e0f742`(브랜드 자산), `4cbd9a061`(WEBUI_NAME 접미사 제거), `c68c745d2`(suggestion prompt 자동 전송 방지).

3. **초안 작성 및 자체 검토**
   - `docs/plan/v0.11.1-integration.md` (259 lines) 작성 — 12 섹션 구조.
   - 자체 리뷰 후 2건 정정:
     - §11: "미머지 브랜치 5개 잔존" 문장 → 모두 이미 main 병합됨을 확인, "삭제만 필요"로 정정.
     - §7.3: `git fetch upstream --tags`가 fork의 동명 태그(v0.10.2, v0.11.0)와 clobber되어 실패하는 실제 이슈 반영. `--no-tags` 권장, refmap 분리 저장 예시, `--force` 비권장 경고 추가.
   - 프리티어 통과 확인.

4. **housekeeping**
   - `.gitignore` 확장: `.opencode/commands/`, `.opencode/skills/`, `.claude/` 추가 (personal scope 명시 주석).
   - `docs/SESSION.md` 삭제 (1 line skeleton).
   - `docs/manual/opencode-notebooklm-{workflow,native-tools}.md` (245 lines) 커밋 후보 확정.
   - `docs/memo/one-fact-one-home.md` (358 lines) 커밋 후보 확정.

5. **브랜치 분기 및 4개 관심사별 커밋**
   - `integration/v0.11.1` (main 기점 신규 생성).
   - 4개 feature 브랜치 fan-out → 각각 단일 관심사 커밋 → `--no-ff` merge into integration.
   - 모두 origin에 push. PR #21 오픈 (base=main ← head=integration/v0.11.1, +869/-0, docs-only, MERGEABLE).

6. **로컬 게이트 실행 (baseline 검증용)**
   - `./scripts/local-test.sh v0.11.0-kwh.1` 실행. 축적 데이터(cache 889M) 보존 모드 기본 동작.
   - 자동 백업(`20260828-170716-v0.11.0-kwh.1.tar.gz` 805M) → 이미지 pull(둘 다 cached) → 컨테이너 기동.
   - 스크립트 `/health` 60초 폴링 타임아웃 초과로 **FAIL 판정**. 그러나 실제 컨테이너는 그 이후 정상 startup 완료 → `docker inspect ... health=healthy`, `curl /health` = 200.
   - 자동 브랜드 검증: `/api/config` name=`Koreatimes` (접미사 없음), `/manifest.json` name/short_name=`Koreatimes`, splash(라이트 14157B / 다크 14280B) 200, favicon(17048B) 200.
   - 사용자 브라우저 수동 체크리스트 완료 확인.
   - `./scripts/local-test.sh --down`으로 정상 tear-down. 데이터 dir 보존.

## 커밋 / PR

- `c102ae07f` docs: draft v0.11.1 upstream integration plan
- `3ae444ca9` docs: add opencode NotebookLM workflow and native-tools notes
- `6454fd1be` docs: add one-fact-one-home summary memo
- `a67aba2c3` chore: ignore .opencode commands/skills and .claude harness state
- (merges) `c90ebe213`, `d2e40ce9a`, `914994f49`, `31c5b4a53` — 각 feature → integration/v0.11.1 `--no-ff` merge
- **PR #21**: https://github.com/kwh8121/openwebui-service/pull/21 (OPEN, MERGEABLE)

## 학습 사항 (→ OpenViking 이관 대상)

- **`scripts/local-test.sh` `/health` 60초 폴링 부족**: 축적 데이터(cache dir 800M+) 환경에서 openwebui 정상 startup이 60초를 초과. 스크립트는 FAIL 판정하나 실제 컨테이너는 그 이후 healthy 도달. 개선 후보: `--health-timeout <sec>` 플래그 또는 `docker inspect health` 상태 폴링으로 판정 전환. 본 사이클 스코프 밖, 별도 세션에서 처리 권장.
- **upstream 태그 clobber 회피 패턴**: fork에 이미 동명 태그(`v0.10.2`, `v0.11.0` 등)가 존재해 `git fetch upstream --tags`는 항상 실패. 표준 대응은 `git fetch upstream --no-tags`(브랜치만) + 필요 시 `refs/tags/vX.Y.Z:refs/tags/upstream/vX.Y.Z` refmap 분리 저장. `--force`는 태그 이력 손상 리스크로 비권장.
- **Claude Code multi-install 락 경합**: native(`~/.local/bin/claude`) + npm-global(`~/.nvm/.../bin/claude`) 병존 시 `claude update`가 `.update.lock` 경합으로 무한 실패. 하나로 단일화하는 것이 지속 가능.
- **OMC v5.0.0 breaking release 회피 근거**: 5.0.0은 major-boundary carve-out으로 17개 워크플로 이름을 alias 없이 삭제(`ultrawork`, `ccg`, `mcp-setup`, `omc-reference` 등). 현재 CLAUDE.md는 이 이름들에 강하게 의존하므로 upgrade 시 즉시 무효화. v4.15.10 유지 결정은 CLAUDE.md 재작성 없이는 번복 불가.
- **`docs/memo/` 커밋 결정 근거**: 문서 자체가 "OpenViking watch 대상 아님"이라 명시했으나, 이는 watch 스코프에 관한 진술일 뿐 git tracking 정책과 무관. 사용자가 커밋 지시 → 팀 공유 자산으로 저장. 향후 memo 폴더에 개인 노트 추가 시 이 관례 유지.

## Linear 이벤트

- 워크스페이스 `koreatimes` 접근 확인 (admin 권한).
- 프로젝트 `openwebui v0.11.1` Backlog 확인. **v0.11.1 통합 이슈 트리는 아직 미생성**. 초안(`docs/plan/v0.11.1-integration.md`) 사용자 검토 통과 후 stage 1 승격 예정.
- KOR-5~8 Runner health monitoring 이슈들은 이번 세션 스코프 밖.

## GitHub 이벤트

- **PR #21** 오픈: `docs: v0.11.1 integration kickoff — plan draft + housekeeping` — https://github.com/kwh8121/openwebui-service/pull/21
- 신규 원격 브랜치 5개: `integration/v0.11.1`, `feature/docs-plan-v0.11.1-integration`, `feature/docs-opencode-notebooklm`, `feature/docs-memo-one-fact-one-home`, `feature/chore-gitignore-personal-scopes`
- 코드 변경 없음 → GH Actions 이미지 빌드 트리거 없음 (docs-only).
- 잔존 원격 브랜치 5건(`feature/docs-cleanup-handoff-priority`, `feature/docs-data-location-principle`, `feature/docs-jobs-commit-backfill`, `feature/docs-linear-5stage-workflow`, `feature/docs-plan-references-adoption`) — 모두 main 병합 완료 확인. 삭제만 남음.

## 다음 후보 작업

- PR #21 병합 → main에 v0.11.1 계획 초안 반영
- Linear stage 1: `openwebui v0.11.1` 프로젝트에 parent + 7 subissue 트리 생성, `plan-draft` 라벨, 본 계획 문서 attachment 링크
- Stage 2: verifier가 needs-review 라벨 전이 → 리뷰 → plan-approved
- Stage 3 개발 착수: `feature/upstream-merge-v0.11.1` (upstream v0.11.1 병합)
- (병행) origin 원격 잔존 `feature/docs-*` 5개 브랜치 삭제
- (병행) `scripts/local-test.sh` `/health` 타임아웃 개선 후보 검토

## 사용자 노트

- 로컬 baseline 검증 성공. 데이터 dir(`/home/kwh8121/openwebui-local-test-data`, `/home/kwh8121/openwebui-local-test-pipelines`)은 v0.11.0-kwh.1 상태로 보존됨 — v0.11.1-kwh.1 발행 시 upgrade 마이그레이션 검증의 baseline으로 재사용 예정.
