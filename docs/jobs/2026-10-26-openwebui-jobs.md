# 2026-10-26 Open WebUI 작업일지

## 05:20 UTC (기록 시각) — upstream v0.12.4 병합 → `v0.12.4-kwh.1-rc.1` RC 발행 (개발 에이전트)

### 상태 인지

직전 사이클(`v0.12.3-kwh.1`)은 2026-10-21 프로덕션 배포 완료·Issue #66 종결로 끝나 있었다. 로컬 `main`은 `origin/main`과 동기(`3cb8b6cbd`), 미병합 작업 브랜치 없음. `git fetch upstream --tags`로 **`v0.12.4`(2026-10-25)** 를 확인해 10-21 일지의 재개 지점("다음 upstream 릴리스가 나오면 `integration/vX.Y.Z`부터 같은 루틴을 재시작")대로 사이클을 시작했다.

열린 Issue는 #49(프로덕션 백업 권한 강화·정지 시간 단축), #34(Pipelines 안전 재기동, deferred). #48은 종결돼 있었다.

### 수행

1. **범위 사전 파악.** `v0.12.3..v0.12.4`는 386 커밋 / 364 파일 / +26,822 −16,886. **마이그레이션 파일 변경 0건.** fork 변경 파일과 upstream 변경 파일의 교집합(충돌 후보)은 `Dockerfile`, `env.py`, `utils/middleware.py`, `Chat.svelte`, `InterfaceSettings.svelte` 5건.
2. **병합.** `main`에서 `integration/v0.12.4`와 `feature/upstream-merge-v0.12.4`를 만들고 `v0.12.4`를 `--no-ff` 병합. **충돌 1건** — `Chat.svelte`. upstream이 콜백을 받는 `setText`를 `setTextHandler`로 분리(`MessageInput.svelte:435` 단일 인자 `setText`, `:442` `setTextHandler(text?, cb?)`)하면서 기본값을 `?? false`로 둔 것과, fork의 `?? true`가 같은 hunk에서 겹쳤다. **upstream rename을 받고 fork 기본값 `?? true`를 유지**해 해소했다. 병합 커밋 `097e5074b`.
3. **커스터마이징 보존 확인.** Dockerfile `NODE_OPTIONS=6144`, `env.py` `WEBUI_NAME = os.getenv('WEBUI_NAME', 'Open WebUI')`(접미사 `+=` 없음), `InterfaceSettings.svelte` `insertSuggestionPrompt = true` / `?? true`, `middleware.py`의 memory-review guard(`messages and ctx.get('assistant_message')`) 모두 유지. 브랜드 자산은 `main`과 **blob 해시 동일**(`favicon.png` `827f10c5`, `logo.png` `68317cb1`, `splash.png` `9b513b0b`, `site.webmanifest` `950a8f27`). fork 고유 파일(`scripts/local-test.sh`, `pipelines/`, compose, `.github/workflows/*`, `AGENTS.md`, `CLAUDE.md`, `docs/`) 무변경. 병합이 바꾼 파일 364개 = upstream 변경 범위와 일치.
4. **정적 검사 (Node 22.23.2 / npm 10.9.8).** `npm ci` 통과. `ruff format --check` 추적 파일 325개 통과. `npm run i18n:parse`(upstream이 끝에 신규 `i18n:check`를 추가) 통과하고 **추적 파일 변경 0건** — CI clean-tree 요구 충족. `./node_modules/.bin/prettier --check`로 병합이 바꾼 297개 파일 통과. `npx vitest run --passWithNoTests` 4/4. `npm run check`(svelte-check) **5,675 errors / 188 warnings / 3,507 files**(직전 측정 5,918건에서 243건 감소).
5. **RC 발행.** `integration/v0.12.4`에 feature를 `--no-ff` 병합 → tip `bd982e79beaf2094b42b1aacd74045fc94cacae5`. 두 브랜치 `origin` push. `v0.12.4-kwh.1-rc.1`(annotated)을 `bd982e79b`에 발행·push. GHCR 빌드 run [40272564940](https://github.com/kwh8121/openwebui-service/actions/runs/40272564940) **success** (05:07:32 → 05:14:37 UTC, 약 7분), `headSha` 일치.
6. **digest 대조.** `docker buildx`가 이 머신에 없어 `docker manifest inspect -v`와 GHCR 레지스트리 API(`docker-content-digest` 헤더)로 확인했다. OCI index `sha256:151467e16253c283e0b85d45509aae6c28b49e683c485e63046e8144d7af2523`, amd64 manifest `sha256:48a82d4a8031e04430b52b1fdb8b2fc9f94f7c6dac9548b4b9c5ce94362c2c88`, attestation manifest `sha256:caa36950f4bd797d4ca6acf29852d3f576f6e88fa0f831047c755b0d0c24b77d`. **`v0.12.4-kwh.1-rc.1`과 parity 태그 `git-bd982e7`가 같은 index digest** — 이미지를 pull하지 않고 대조했다.

### 배포 가이드에 반영할 upstream 변경

- **`ENABLE_SKILL_LAZY_LOADING`** — `config.py:2072` 기본 `False`, 영속 키 `skills.lazy_loading.enable`. 챗에서 선택하거나 모델에 붙인 스킬의 전체 지침을 매 메시지에 보내는 대신 목록만 노출하고 모델이 필요할 때 로드한다(메시지에서 직접 언급한 스킬은 즉시 로드). **내장 Skills 도구가 필요하다.** 10-19 일지가 "미검증"으로 남긴 "모델 연결 스킬이 전체 지침을 전송해 토큰 사용이 늘 수 있다"의 직접 대응책이다.
- **UI 가시성 게이팅 전면 도입** — 신규 `src/lib/utils/ui-visibility.ts`, `admin/Settings/Interface/Visibility.svelte`, 영속 키 `ui.visibility`(`config.py:1749`, 기본 `{}`). 권한·기능이 꺼진 항목이 이제 **숨겨진다**(이전엔 보이지만 동작하지 않았다). 프로덕션 권한 설정에 따라 기존에 보이던 메뉴가 사라져 보일 수 있다.
- **신규 영속 config 키 3개** — `skills.lazy_loading.enable`, `ui.visibility`, `ldap.server.default_email_domain`. 첫 기동 시 `Seeded 3 new config defaults`가 예상된다.
- **컨텍스트 압축 UI** — "Context compacted" 줄이 압축 지점에 표시되고 요약을 펼칠 수 있다. 진행·오류가 팝업이 아니라 챗 안에 표시된다. 신규 `Messages/ContextCompactionLabel.svelte`.
- **OAuth** — OAuth 인증을 쓰는 연결이 API 키·bearer 토큰 호출에서도 사용자 OAuth 토큰을 전달한다(도구 서버와 동일하게).
- **채널** — 온라인 멤버가 많은 채널 조회가 크게 빨라졌고, 채널 메시지 삭제가 스레드 답글까지 삭제한다(이전엔 남아 검색에 노출).
- **의존성** — `mcp` 1.27.2 → **2.3.0 메이저**, `httpx2` 2.16.0 신규, `pillow` 12 → 13, `pypdf` 6.7.5 → 6.21.2, `uvicorn` 0.51 → 0.54, `dompurify` 3.2.6 → 3.4.17. upstream `build` 스크립트가 `node --max-old-space-size=12288`을 직접 지정하게 바뀌었다.

### 판단·한계 (PASS로 읽지 말 것)

- **로컬 프로덕션 미러 게이트를 아직 실행하지 않았다.** 이미지 동작·마이그레이션·OAuth·pipelines·RAG·브랜드·`/health` 검증 전이다. 사용자 승인 대기.
- **`svelte-check` 베이스라인을 `main`에서 따로 측정하지 않았다.** "병합 신규 오류 없음" 판정의 근거는 ① 총계 감소(5,918 → 5,675), ② 충돌 해소 지점의 유일한 오류가 기존 fork 항목(`Chat.svelte 1016:22 "Property 'insertSuggestionPrompt' does not exist on type 'Settings'."` — 10-15 일지의 `Chat.svelte:986`이 줄 번호만 이동), ③ `setTextHandler` 관련 오류 0건 — 세 가지다. 파일별 완전 대조가 아니다.
- **`npm run build`는 실행하지 않았다**(로컬 금지, 7 GB 머신 heap OOM). 빌드 권위는 GH Actions run 40272564940뿐이다.
- **upstream `build` 스크립트의 `--max-old-space-size=12288`은 위험 요소가 아니다.** fork의 `.github/workflows/docker.yaml`이 빌드 시 awk로 Dockerfile에 `ENV NODE_OPTIONS="--max-old-space-size=12288"`을 이미 주입하고 있어(`ubuntu-latest`) 값이 같다. Dockerfile의 6144는 CI 외 빌드에만 적용된다.
- **이미지 롤백·백업 복원·DB downgrade는 여전히 미시험**(#49). 신규 config 기본값 3행이 롤백에 주는 영향은 직전 사이클과 같은 미확인 항목이다.
- 프로덕션 스냅샷 리허설 여부는 미결정(소유자 몫). 마이그레이션 0건이므로 직전 사이클과 같은 판단 구조다.
- 이 기록은 배포 승인이 아니다.

### 학습 사항

- **`ruff` 0.16.5는 Markdown 안의 Python 코드 블록까지 포맷 검사한다.** `ruff format --check .`가 미추적 `docs/plan/2026-10-12-wire-desk-poc-*.md` 등 4건을 "reformat 대상"으로 보고한다(예: `...-r6.md:836`). 추적 파일이 아니라 현재 CI와 무관하지만, **그 문서들을 커밋하면 CI의 `ruff format --check` 가 깨진다.** 커밋 전에 코드 블록을 포맷하거나 `pyproject.toml`에서 `docs/`를 제외해야 한다.
- **이 머신에 `docker buildx`가 없다.** digest 대조는 `docker manifest inspect -v`(amd64 manifest) + GHCR 레지스트리 API의 `docker-content-digest` 헤더(OCI index)로 하면 이미지를 pull하지 않고 끝난다. 익명 토큰(`https://ghcr.io/token?scope=repository:kwh8121/openwebui-service:pull`)으로 동작한다.
- **전체 트리 `grep -r`을 피한다.** `node_modules`·`static/pyodide`까지 읽어 120초 타임아웃을 넘긴다. 충돌 마커 검사는 `git grep`이나 `git diff --diff-filter=U`로 한다.

### 다음 재개 지점

- **로컬 게이트 (RC)**: `./scripts/local-test.sh v0.12.4-kwh.1-rc.1 --allow-rc --health-timeout 1200`. 기동에 수 분 + 자동 백업(수백 MB tar). 마이그레이션 0건이므로 `Running upgrade` 0줄과 `alembic current == heads`(`0bd252b206fb`)를 확인한다.
- **스모크 추가 항목**: UI 가시성 게이팅으로 권한이 꺼진 기능의 메뉴가 숨겨지는지, `ENABLE_SKILL_LAZY_LOADING`을 켰을 때 스킬 목록·로드 동작, 컨텍스트 압축 표시.
- 게이트 통과 후: PR `integration/v0.12.4` → `main`(CLA 확인은 소유자 지시대로) → `--merge` → 최종 태그 `v0.12.4-kwh.1`을 병합된 main tip에 발행 → 최종 이미지 게이트 → 배포 가이드 `docs/manual/kwh-deploy-guide-v0.12.4-kwh.1.md` → 문서 전용 PR → `guide_commit` 확정 → `Production deployment request` Issue.
- 소유자 결정 대기: 프로덕션 스냅샷 리허설 여부, `ENABLE_SKILL_LAZY_LOADING` 프로덕션 적용 여부(토큰 사용량 대응), `check_pipelines` 값(배포 직전 컨테이너 상태 기준).
- 열린 Issue #49·#34는 이번 릴리스와 별개로 유지.

## 05:45 UTC (기록 시각) — RC 로컬 프로덕션 미러 게이트 PASS (개발 에이전트)

### 수행

`./scripts/local-test.sh v0.12.4-kwh.1-rc.1 --allow-rc --health-timeout 1200`. 실행 전 상태: local-test 컨테이너 0개, 포트 8082·9099 비어 있음, 디스크 807 GB 여유, 누적 데이터 898 MB·pipelines 192 KB 보존.

**[PASS]** — 전체 소요 약 23분(05:21 → 05:44 UTC, 이미지 pull 약 3 GB와 자동 백업 포함), **`/health` 200까지 부팅 228초**.

| 점검                                                                   | 결과                                                                                                                 |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `Running upgrade`                                                      | **0줄** (마이그레이션 변경 0건과 일치)                                                                               |
| `alembic current == heads`                                             | OK, `0bd252b206fb` 유지                                                                                              |
| SQLite `PRAGMA integrity_check`                                        | `ok`                                                                                                                 |
| pipelines                                                              | `http://127.0.0.1:9099/openapi.json` 응답                                                                            |
| `/api/config`                                                          | `name=Koreatimes`, `version=0.12.4`                                                                                  |
| `/_app/version.json`                                                   | `bd982e79beaf2094b42b1aacd74045fc94cacae5` — RC 태그 대상 SHA와 일치                                                 |
| `/manifest.json`                                                       | `name=Koreatimes`, `short_name=Koreatimes`                                                                           |
| `/health`                                                              | 200                                                                                                                  |
| 로그 92줄의 `Traceback`·`KeyError`·`IntegrityError`·`OperationalError` | 각 **0건**                                                                                                           |
| 로그 `ERROR`                                                           | 2건 — 모두 #48의 기존 도구 서버 DNS 실패(`fastapi-tools-v2:8000` name resolution). `Initialized 0 tool server(s)`    |
| pull된 이미지 `RepoDigests`                                            | `sha256:151467e16253c283e0b85d45509aae6c28b49e683c485e63046e8144d7af2523` — RC·parity 태그의 OCI index digest와 일치 |

**`Seeded 3 new config defaults`** 가 `open_webui.models.config:seed_defaults:273`에 기록됐다. 사전 예측(신규 영속 키 `skills.lazy_loading.enable`, `ui.visibility`, `ldap.server.default_email_domain` 3개)과 수가 일치한다.

자동 백업: `~/openwebui-local-test-data.backups/20261026-142129-v0.12.4-kwh.1-rc.1.tar.gz`, `~/openwebui-local-test-pipelines.backups/20261026-142547-v0.12.4-kwh.1-rc.1.tar.gz`.

### 판단·한계 (PASS로 읽지 말 것)

- **브라우저 수동 검증은 수행하지 않았다.** OAuth 로그인, 모델 대화, 업로드·RAG, 브랜드 표시, 도구, 그리고 이번 릴리스의 신규 항목(UI 가시성 게이팅으로 권한이 꺼진 메뉴가 숨겨지는지, `ENABLE_SKILL_LAZY_LOADING` 동작, 컨텍스트 압축 표시)은 모두 미확인이다. 게이트는 자동 점검만 통과했다.
- **`Seeded 3 new config defaults`의 개별 키를 DB에서 직접 조회해 확인하지 않았다.** 수가 예측과 같다는 것이 근거다.
- **마이그레이션이 0건이므로 데이터 보존 검증(합성/실데이터)을 하지 않았다.** 스키마가 바뀌지 않았다는 점이 근거다.
- **이미지 롤백·백업 복원은 이번에도 시험하지 않았다**(#49). 신규 config 기본값 3행이 `v0.12.3-kwh.1`로의 롤백에 주는 영향은 미확인이다.
- 게이트 컨테이너(8082·9099)가 **떠 있는 상태**다. 브라우저 확인이 끝나면 `./scripts/local-test.sh --down`.

### 다음 재개 지점

- 소유자: 브라우저 prod-mirror 체크리스트 수행(`docs/plan/local-test-workflow.md` § "로컬 수동 검증 체크리스트"). 접속 `http://127.0.0.1:8082`.
- 이후: PR `integration/v0.12.4` → `main` → `--merge` → 최종 태그 `v0.12.4-kwh.1`을 병합된 main tip에 발행 → 최종 이미지 게이트 → 배포 가이드 `docs/manual/kwh-deploy-guide-v0.12.4-kwh.1.md` → 문서 전용 PR → `guide_commit` 확정 → `Production deployment request` Issue.
- 이 일지는 미커밋이다. 커밋 시 규약대로 `feature/docs-jobs-20261026` → `integration/v0.12.4` 경로를 쓴다(현재 `integration/v0.12.4`에 체크아웃된 상태).

## 06:15 UTC (기록 시각) — P0 브라우저 검증 (Playwright) + 게이트 정리 (개발 에이전트)

### 배경

이번 병합에서 **사람이 직접 작성한 코드는 `Chat.svelte` 충돌 해소 1곳뿐**이다. 정적 검사는 타입만 통과시켰으므로 동작 확인이 필요했다. 사용자 지시로 Playwright MCP로 이 항목만 먼저 확인했다. 로그인은 사용자가 제공한 로컬 테스트 계정(`reporter`, 비관리자)을 썼고 **자격 증명은 이 일지·저장소·스크래치패드에 기록하지 않는다.**

### 수행

1. **사전 조사.** `ui.prompt_suggestions = []`이고 모델별 `suggestion_prompts`도 비어 있어(유일한 값은 `perplexity/sonar-pro-search`의 `content: ''`) 추천 프롬프트가 **하나도 구성돼 있지 않았다.** `Chat.svelte:5343` → `Placeholder` → `Suggestions.svelte:99`가 해소 지점에 닿는 **유일한 경로**임을 코드로 확인했으므로(슬래시 커맨드 쪽 `onSelect`는 `MessageInput` 내부 핸들러로 간다), 검증용 데이터를 만들어야 했다.
2. **임시 데이터 생성 → 삭제.** Workspace에 모델 `p0-suggestion-test`(base `anthropic/claude-opus-5`, 추천 프롬프트 1개)를 만들어 검증한 뒤 삭제했다. Models 수 2 → 3 → 2로 복귀하고 `Deleted p0-suggestion-test` 토스트를 확인했다. **누적 데이터에 남은 변경은 없다.**
3. **P0 판정 — PASS.**
   - Settings > Interface의 "Insert Suggestion Prompt to Input" 스위치가 **`[checked]`**. 이 계정은 해당 설정을 건드린 적이 없으므로 fork 기본값 `?? true`가 런타임에 적용됨이 확인된다.
   - 추천 프롬프트 클릭 → composer에 텍스트가 **삽입**되고 **전송되지 않았다.** 새 챗 화면이 유지되고(`heading "p0-suggestion-test"`, `heading "Suggested"` 목록 그대로) 챗이 생성되지 않았으며 URL도 불변. 텍스트가 들어오자 `Send message` 버튼이 나타나 전송 대기 상태임이 드러났다.
   - `setTextHandler` rename에서 런타임 오류 없음.
   - 로그인·설정·챗 전 과정 **콘솔 오류 0건**.
4. **부수 확인.** 로그인 화면 "Sign in to Koreatimes" + Google OAuth 버튼 + 신규 접근성 기능 "Skip to main content" 링크. UI 하단 `Koreatimes ‧ v0.12.4`. 추천 프롬프트가 `heading "Suggested"`(level 3) + `list` + `button` 구조로 렌더돼 v0.12.4 접근성 변경과 일치. 모델 편집기의 Capabilities(+6)·Default Features(Web Search, Image Generation)·Builtin Tools(+12)·Voice 섹션이 **비관리자에게도 표시**됐다(해당 기능이 인스턴스에서 켜져 있어 숨김이 발동하지 않음).
5. **Playwright 산출물 정리.** 저장소 루트의 `.playwright-mcp/`(스냅샷·콘솔 로그)를 삭제해 커밋에 들어가지 않게 했다.
6. **게이트 정리.** `./scripts/local-test.sh --down` — 컨테이너 2개·네트워크 제거, 8082·9099 해제. 데이터 디렉터리는 보존.

### 판단·한계 (PASS로 읽지 말 것)

- **`reporter` 계정은 관리자가 아니다.** 영속 설정 `ui.default_user_role = "pending"`가 env `DEFAULT_USER_ROLE=admin`을 덮는다. 따라서 **Admin Settings 쪽 신규 항목을 확인하지 못했다** — `ui.visibility` 패널(신규 가시성 관리 UI)과 `ENABLE_SKILL_LAZY_LOADING` 토글. 관리자 계정이 필요하다.
- **토글을 OFF로 둔 upstream 기본 경로(자동 전송)는 시험하지 않았다.** 그 경로는 `submitHandler`를 호출해 OpenRouter에 실제 모델 요청이 나가 비용이 발생한다. fork 동작 검증에는 불필요하다고 판단했다.
- **나머지 P1·P2 항목은 전부 미확인이다** — 모델 대화, 제목 생성(#47), 업로드·RAG, 채널(메시지 삭제 시 스레드 답글 동반 삭제 포함), 컨텍스트 압축 표시, Admin Analytics `UsageChart`, 파일 hover 미리보기.
- **도구 서버 검증은 로컬에서 불가하다.** `fastapi-tools-v2:8000` DNS가 해소되지 않아 `Initialized 0 tool server(s)`다(#48). 따라서 **OAuth 토큰을 API 키·bearer 호출에서도 전달하는 신규 동작**은 프로덕션 배포 후 점검 항목으로 넘어간다.
- Google OAuth 로그인은 시험하지 않았다(폼 로그인만 사용).

### 정정

05:20 섹션에서 `ui.visibility`를 근거로 "권한이 꺼진 메뉴가 사라져 보일 수 있다"고 적었으나 **그 메커니즘은 그렇지 않다.** `src/lib/utils/ui-visibility.ts`의 해소 로직은 `user?.role === 'admin' || config?.ui?.visibility?.[id] !== false`이므로, `ui.visibility`는 **관리자가 숨길 항목을 명시적으로 고르는 opt-in 목록**(약 70개 control ID)이고 기본값 `{}`에서는 아무것도 숨지 않으며 관리자에게는 애초에 적용되지 않는다. 메뉴가 사라지는 변화는 이것과 별개인 **가용성 기반 숨김**(기능·권한이 없으면 해당 UI를 숨김) 쪽이다. 검증 대상이 둘로 나뉜다.

### 다음 재개 지점

- 작업일지 커밋(`feature/docs-jobs-20261026` → `integration/v0.12.4`) → PR `integration/v0.12.4` → `main`.
- 관리자 계정 확보 시: `ui.visibility` 패널, `ENABLE_SKILL_LAZY_LOADING` 동작과 토큰 사용량 변화(프로덕션 적용 결정 근거).
- 비관리자 관점 가시성 게이팅 확인은 기능을 끈 상태를 만들어야 해 로컬에서는 제약이 있다.
