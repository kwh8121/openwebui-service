# Open WebUI Jobs Log — 2026-07-22

> Resume: `claude --resume 7def1cac-e184-4341-af02-4e2ac774fd31`

## 요약

- 채팅 화면의 "제안" 프롬프트 카드(예: "AP Style 교정") 클릭 시 즉시 전송되는 UX 문제 원인 규명: 개인별 클라이언트 설정 `$settings.insertSuggestionPrompt` 기본값 `false` 때문. 코드 3줄 수정으로 기본값 `true`로 변경 후 커밋.
- 릴리스 워크플로 문서(`github-actions-ghcr-release-deployment.md`) 위반 발견: `main`에 직접 커밋함. 재배치로 시정 — `feature/default-insert-suggestion-prompt` 브랜치로 커밋 옮기고 `main` 리셋, `integration/v0.10.2`에 `--no-ff` 머지.

## 작업 흐름

1. **AP Style 프롬프트 카드 UX 버그 진단**
   - 스크린샷 (`C:\Temp\waveterm-938427886\waveterm_paste_1784686472297_i14w0f.png`) 확인: 채팅 placeholder 하단 "제안" 카드.
   - 관련 컴포넌트 조사: `Suggestions.svelte:95` → `Placeholder.svelte:274` `onSelect` prop → `Chat.svelte:317-329` `onSelect` 핸들러.
   - 루트 원인: `Chat.svelte:323`의 `if (!($settings?.insertSuggestionPrompt ?? false))` — 기본값 `false`면 텍스트 세팅 후 즉시 `submitHandler(prompt)` 호출.
   - 설정 UI: 설정 → 인터페이스 → "Insert Suggestion Prompt to Input" 토글 (`Settings/Interface.svelte:899-916`).
   - 관리자가 문제없이 보였던 이유: 관리자 브라우저 localStorage에만 토글이 켜져있었기 때문. 권한/역할 로직과 무관.
   - 백엔드 참조 없음 확인 (순수 클라이언트 설정).

2. **UX 버그 해결 옵션 결정 및 적용**
   - 옵션 A(개별 안내), 옵션 B(기본값 변경), 옵션 C(백엔드 확장)를 제시.
   - 사용자 첫 결정: 옵션 A → 안내 문구(한/영) 작성해 전달.
   - 사용자 재결정: 옵션 B도 진행. 코드 3줄 편집 후 커밋.
     - `src/lib/components/chat/Chat.svelte:323` `?? false` → `?? true`
     - `src/lib/components/chat/Settings/Interface.svelte:57` `= false` → `= true`
     - `src/lib/components/chat/Settings/Interface.svelte:227` `?? false` → `?? true`
   - 커밋: `c68c745d2` on `main`.

3. **워크플로 위반 발견 및 안전 재배치**
   - 릴리스 문서 재확인 후 규칙 위반 인지: 커스텀 변경은 `feature/*` → `integration/*` `--no-ff` 흐름을 거쳐야 하는데 `main`에 직접 커밋함.
   - 사용자 선택: 옵션 ① 안전 재배치.
   - 절차:
     - `feature/default-insert-suggestion-prompt` 브랜치를 `c68c745d2`에서 생성 → 커밋 보존.
     - `main`을 `origin/main`(`8b68b8a62`)으로 `git reset --hard`.
     - `integration/v0.10.2` 체크아웃 (`dcba1c957`, `origin`과 동일).
     - `feature/default-insert-suggestion-prompt`를 `--no-ff`로 머지 → 머지 커밋 `6532473a1` 생성.
   - 결과: `main` 손대지 않음, 커밋은 `integration/v0.10.2`(로컬 ahead 3)에만 존재, 원본 커밋 SHA 보존.

4. **로컬 스테이징 대신 GHCR 파이프라인 사용 결정**
   - 프로덕션 리소스 제약 때문에 로컬 빌드/스테이징 회피가 문서의 설계 의도임을 확인.
   - RC 태그(`v0.10.2-kwh.N-rc.M`) 커팅 → GitHub Actions가 `ghcr.io/kwh8121/openwebui-service:0.10.2-kwh.N-rc.M` 빌드 → 스테이징 서버에서 `docker-compose.staging.yaml`로 검증 → integration → main PR → 최종 태그.
   - 사용자 계획: 추가 수정 사항 몇 가지를 더 반영한 뒤 RC 태그 커팅 예정. 이번 세션에서는 태그/푸시 진행하지 않음.

## 커밋 / PR

- `c68c745d2` fix: default insertSuggestionPrompt to true to avoid accidental send
  - 브랜치 소속: `feature/default-insert-suggestion-prompt` (병합됨), `integration/v0.10.2` (via merge commit)
  - `main`에는 존재하지 않음 (reset으로 제거).
- `6532473a1` merge: feature/default-insert-suggestion-prompt into integration/v0.10.2
  - `integration/v0.10.2` `--no-ff` 머지 커밋.
- PR 없음 (이번 세션에서 생성/변경 없음).

## 브랜치 이동

- `main` → `integration/v0.10.2` (재배치 과정 중)

## 학습 사항

- **`~/.claude.json`은 Claude Code가 편집 중에도 자동 재기록한다.** 편집 실패 시 재조회 후 재시도로 회복 가능. 편집 전 백업 파일 생성이 안전.
- **Hermes gateway는 `systemd --user` 유닛으로 등록돼 자동 재기동한다.** `hermes gateway stop`만으로는 중단 불가 → `systemctl --user disable` 필요.
- **개인별 UI 토글이 "관리자만 정상"으로 오해될 수 있다.** `$settings`는 브라우저 localStorage 저장이므로 계정/역할과 무관. 유사 버그 리포트 시 이 가능성부터 확인.
- **`main` 직접 커밋은 릴리스 문서 규칙 위반.** 이 저장소의 커스텀 변경은 반드시 `feature/*` → `integration/vX.Y.Z` `--no-ff` → PR → `main`.
- **로컬 스테이징 빌드는 문서상 회피 대상.** GHCR + `docker-compose.staging.yaml` + RC 태그 흐름이 표준.
- **문서 최우선 규칙:** `github-actions-ghcr-release-deployment.md`가 다른 참고 자료와 충돌 시 우선.

## 다음 후보 작업

- 추가 UX/기능 수정 사항 몇 개를 같은 `feature/*` 또는 별도 `feature/*` 브랜치로 진행 → `integration/v0.10.2`에 누적.
- 수정 완료 시:
  1. `git push origin integration/v0.10.2 feature/default-insert-suggestion-prompt`
  2. 다음 RC 태그 번호 확인: `git tag -l 'v0.10.2-kwh.*'`
  3. RC 태그 생성 및 push (예: `v0.10.2-kwh.2-rc.1`)
  4. GH Actions 빌드 확인 → 스테이징 검증 → integration → main PR → 최종 태그 `v0.10.2-kwh.2`
- `~/.claude.json.bak-agentmemory-removal-20260722-110656` 백업 파일 며칠 후 상태 문제없으면 삭제 가능.

## 미커밋 상태

이 로그 파일은 로컬에만 저장되었고 git에 스테이지/커밋하지 않았습니다. 필요 시:

```bash
git add docs/jobs/2026-07-22-openwebui-jobs.md
git commit -m "docs: add 2026-07-22 openwebui jobs log"
```

---

## 13:24 — Koreatimes 브랜드 스왑 + 릴리스 파이프라인 실전 + 세션-연속성 문서 정착

> Resume: `claude --resume 7def1cac-e184-4341-af02-4e2ac774fd31`

### 요약

- Plan 모드로 Koreatimes 브랜딩 완전 스왑을 설계·승인·실행: 로고 자산 스크래핑 → Pillow LANCZOS 리사이즈 → `static/static/` + `backend/open_webui/static/` 두 디렉토리 배치 → `env.py` 접미사 로직 2줄 제거. `feature/koreatimes-branding`에서 진행 후 integration에 `--no-ff` 머지.
- 정식 릴리스 파이프라인 최초 완주: feature/integration push → RC 태그 `v0.10.2-kwh.2-rc.1` → GH Actions RC 빌드 → 사용자 스테이징 검증 → PR #3 `--merge` → main 동기화 → 최종 태그 `v0.10.2-kwh.2` → GH Actions 프로덕션 빌드 → `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.2` 준비 완료.
- 배포 진단 접수 후 문서 오류·안전성 3건 정정: 태그 예시에 `v` 접두사 명시(PR #4), 실무 루틴 문서 `docs/manual/kwh-release-routine.md` 신설 + AGENTS.md 세션-연속성 섹션(PR #5, CLAUDE.md 포함), CLAUDE.md에 릴리스 루틴 요약 인라인화(PR #6).
- Claude Code CLI 자동 로드 대상은 `<repo>/CLAUDE.md`뿐이라는 점 확인. `.gitignore`의 `CLAUDE.md` 제외 항목(upstream 관례) 제거 후 신규 CLAUDE.md 커밋 성립. divergence 인벤토리 갱신.
- 클린업: `~/.claude.json.bak-agentmemory-removal-*` (66 KB) 삭제, 머지된 원격+로컬 feature 브랜치 5개 삭제. 프로덕션 배포는 사용자 결정으로 다음 코드 수정 반영 후 일괄 진행 예정.

### 작업 흐름

1. **Koreatimes 브랜딩 Plan 모드**
   - Explore 에이전트로 로고/브랜딩 지점 조사 (40+ touchpoints 확인).
   - `env.py:842-844`의 upstream 접미사 강제 로직(`WEBUI_NAME != 'Open WebUI'` → `+= ' (Open WebUI)'`) 발견 — 완전 no-code 불가, 백엔드 최소 수정 필요.
   - AskUserQuestion 3개: (스코프) 완전 스왑 / (자산) koreatimes.co.kr 자동 스크래핑 / (브랜치) `feature/koreatimes-branding` 신설 — Plan 승인.
2. **자산 획득 및 리사이즈**
   - `curl -sSL https://www.koreatimes.co.kr/`로 홈페이지 HTML 확인 후 og:image meta에서 `logo_1200x1200.png` (RGB 1200×1200), `/images/logo.svg` (7.3 KB), `/favicon.ico` (159 KB MS Windows Icon) 확인.
   - `/tmp/koreatimes-logo/`에 원본 저장, Pillow LANCZOS로 11개 사이즈 생성: favicon(512/-dark/96), logo, splash(-dark), apple-touch-icon(180), web-app-manifest-192/512.
   - `static/static/` + `backend/open_webui/static/` 양측 동시 배치. SHA256 parity 확인 완료.
   - `site.webmanifest` `name`/`short_name` → "Koreatimes" (양측).
3. **코드 수정 (env.py 접미사 제거)**
   - `backend/open_webui/env.py:842-844` — `if WEBUI_NAME != 'Open WebUI': WEBUI_NAME += ' (Open WebUI)'` 두 줄 삭제.
   - Python `ast.parse` + `os.getenv` 시뮬레이션으로 `WEBUI_NAME=Koreatimes` → `'Koreatimes'` (접미사 없음) 확인.
4. **feature 머지 + push**
   - 커밋 `171e0f742` (assets), `4cbd9a061` (env.py).
   - `integration/v0.10.2`로 `--no-ff` 머지 → `87f41b9f6`.
   - 두 feature + `integration/v0.10.2` (ahead 6) 원격 push.
5. **RC 태그 + GH Actions 빌드**
   - `git tag -a v0.10.2-kwh.2-rc.1 87f41b9f6 -m "..."` push.
   - Run `29892539580` 성공 (6분 25초). GHCR: `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.2-rc.1` + `git-87f41b9f`.
6. **스테이징 검증** (사용자 서버 작업, 통과 확인).
7. **PR #3 → main `--merge`**
   - `gh pr create` + `gh pr merge 3 --merge` → main `42681f0e9`.
   - 로컬 main fast-forward 동기화.
8. **최종 태그 + 프로덕션 빌드**
   - `git tag -a v0.10.2-kwh.2 42681f0e9 -m "..."` push.
   - Run `29893567404` 성공 (7분 17초). GHCR: `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.2` + `git-42681f0`.
9. **배포 진단 접수 → 정정**
   - 진단 요점 검증:
     - GHCR 태그 형식: 실제로는 v 접두사 유지 + short 7자 SHA (`v0.10.2-kwh.2`, `git-42681f0`). 문서 예시 잘못됨. `git show v0.10.2-kwh.2:backend/open_webui/env.py`로 접미사 제거는 태그에 포함됐음을 확인 (진단 우려는 오해).
     - SQLite WAL 백업: 단순 tar 불충분 → stop-tar 또는 `sqlite3 .backup` 온라인 백업.
     - 배포 env 명시: `OPENWEBUI_IMAGE_TAG`, `OPENWEBUI_LOCAL_DATA`, `OPENWEBUI_DEPLOY_ENV_FILE` 모두 export.
     - 스모크: `/health` 이상으로 OAuth, 모델, RAG, pipelines 확인.
   - PR #4 (`feature/fix-docs-ghcr-tag-format`, `51ab6e210`): 태그 예시 v 접두사 + short SHA 명시, doc-only shortcut로 main 직접 PR.
10. **세션-연속성 문서 정착**
    - `docs/manual/kwh-release-routine.md` 신설 (333줄): repo/remote 셋업, branch/tag 컨벤션, RC/final 흐름, compose 파일, 환경변수, 검증 체크리스트, SSH 카피페이스트 블록, WAL 백업, 복구 패턴, divergence 인벤토리 (`8a3b32a56`).
    - AGENTS.md "Release Routine And Session Continuity" 섹션 추가 → 개요 확장 (`8a3b32a56`, `c50a55f64`).
    - **사용자 지적**: AGENTS.md는 Claude Code CLI 자동 로드 대상 아님. `<repo>/CLAUDE.md`만 자동 로드.
    - `CLAUDE.md` 신설 with `@AGENTS.md` @-import (`9edb3712d`).
    - `.gitignore` 라인 22 `CLAUDE.md` 항목 제거 (upstream 관례에서 diverge, divergence 인벤토리 갱신).
    - PR #5 (`feature/docs-kwh-release-routine`) `--merge` → main `3286bb0ab`.
11. **CLAUDE.md 릴리스 루틴 인라인화**
    - 사용자 요청: 세션 시작 시 즉시 참조 가능하도록 CLAUDE.md 본문에 9단계 요약 직접 삽입.
    - PR #6 (`feature/docs-add-release-routine-to-claudemd`, `8b59cd37c`): "Production Release Routine (at-a-glance)" 섹션 추가 (recovery guard → feature/integration → push → RC → staging → PR → main sync → final tag → prod deploy → doc-only shortcut + 매 세션 log append 리마인더).
    - `--merge` → main `18e754ed1`.
12. **환경 정리**
    - `~/.claude.json.bak-agentmemory-removal-20260722-110656` (66.3 KB) 삭제.
    - 머지된 원격+로컬 feature 브랜치 5개 삭제: `feature/default-insert-suggestion-prompt`, `feature/koreatimes-branding`, `feature/fix-docs-ghcr-tag-format`, `feature/docs-kwh-release-routine`, `feature/docs-add-release-routine-to-claudemd`. 삭제 전 각 브랜치 HEAD가 `origin/main`의 조상임을 `git merge-base --is-ancestor`로 검증.
    - `/tmp/koreatimes-logo/` (1 MB) 사용자 지시로 존치.

### 커밋 / PR

**PR 히스토리 (전부 머지됨):**
- #3 Merge integration/v0.10.2 (kwh.2) — merge commit `42681f0e9`
- #4 docs: correct GHCR image tag examples — merge commit `f39ad5842`
- #5 docs: kwh release routine + AGENTS.md pointer + CLAUDE.md — merge commit `3286bb0ab`
- #6 docs(CLAUDE): inline production release routine summary — merge commit `18e754ed1`

**태그:**
- `v0.10.2-kwh.2-rc.1` at `87f41b9f6` — RC (스테이징 검증 통과)
- `v0.10.2-kwh.2` at `42681f0e9` — 최종 (GHCR 이미지 준비, 프로덕션 배포 대기)

**주요 커밋 (전부 main 히스토리에 포함):**
- `171e0f742` assets: Koreatimes brand (12 파일 × 2 디렉토리)
- `4cbd9a061` fix: remove forced (Open WebUI) suffix from WEBUI_NAME
- `51ab6e210` docs: correct GHCR image tag examples
- `8a3b32a56` docs: add kwh release routine + AGENTS.md pointer
- `c50a55f64` docs(AGENTS): expand release-routine section with doc overview
- `9edb3712d` docs: add repo-root CLAUDE.md that @-imports AGENTS.md
- `8b59cd37c` docs(CLAUDE): inline production release routine summary

### 브랜치 이동

`main` → `integration/v0.10.2` → `feature/koreatimes-branding` → `integration/v0.10.2` → `main` → `feature/fix-docs-ghcr-tag-format` → `main` → `feature/docs-kwh-release-routine` → `main` → `feature/docs-add-release-routine-to-claudemd` → `main` (최종)

### 학습 사항

- **GH Actions `docker/metadata-action@v5` 기본 태그 형식**: `type=ref,event=tag`는 태그명 그대로(**v 접두사 유지**), `type=sha,prefix=git-`는 **7자 short SHA**. 문서 예시가 이와 달라 배포 커맨드 `OPENWEBUI_IMAGE_TAG=0.10.2-kwh.N` 시 pull 실패. 항상 `v0.10.2-kwh.N` 필수.
- **SQLite WAL 백업**: 컨테이너 실행 중 단순 tar은 WAL 미커밋 데이터 유실 위험. `docker compose stop openwebui` 후 tar이 가장 단순한 안전책. 무중단 시 `sqlite3 <db> ".backup"` 온라인 백업 후 관련 디렉토리 tar.
- **Claude Code CLI 자동 로드 대상**: `<repo>/CLAUDE.md`만. `AGENTS.md`는 agents.io/Codex 컨벤션으로 자동 로드 대상 아님. Claude Code 세션에 컨텍스트 주입하려면 `CLAUDE.md`에서 `@AGENTS.md` @-import 필요.
- **`.gitignore CLAUDE.md`** (upstream 관례): 원본 Open WebUI는 CLAUDE.md를 개발자별 파일로 취급해 gitignore 처리. Fork에서 세션 startup 파일로 사용하려면 해당 라인 제거 필수. divergence 인벤토리에 반드시 기록.
- **문서 전용 변경 shortcut**: `feature/docs-*` 브랜치 → main 직접 PR (integration 사이클 스킵). 이미지 재빌드/스테이징 무관. 오늘 PR #4, #5, #6 모두 이 방식.
- **`docker/metadata-action` semver 미지정 시 태그 원본 유지**: `type=semver,pattern={{version}}` 같은 pattern을 설정하지 않으면 raw 태그 사용. v 접두사 제거 원하면 pattern 명시 필요.
- **buildx 캐시 효과**: RC 빌드(6분 25초)에서 캐시 warmup 완료 후 프로덕션 빌드(7분 17초)는 거의 비슷. Frontend/Python 레이어 재사용이 유효.
- **`git merge-base --is-ancestor <sha> origin/main`**: 브랜치 삭제 안전성 검증에 유용. 스크립트로 5개 브랜치 일괄 검증 후 push --delete.
- **Plan 모드 실용화**: Explore 1개로 코드베이스 사전 조사 → AskUserQuestion으로 스코프/자산/브랜치 결정 → 계획 파일 → ExitPlanMode 후 실행. 40+ touchpoints 조사도 한 번의 Explore로 처리됨.

### 다음 후보 작업

- 추가 코드 수정 (사용자 지시 대기).
- 다음 RC/태그 번호: `v0.10.2-kwh.3-rc.1` → `v0.10.2-kwh.3`.
- 스테이징 검증 → 프로덕션 배포 일괄 진행 (WEBUI_NAME=Koreatimes 서버 env 설정 포함).
- `feature/agents-md-deepinit` 로컬 브랜치 처리 결정.
