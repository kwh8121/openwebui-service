# 2026-11-25 Open WebUI 작업일지

## 18:30 KST — GH #81 Pyodide 파일 표시 버그 수정과 fork 가드 (개발 에이전트)

### 상태 인지·결정

- [GitHub #81](https://github.com/kwh8121/openwebui-service/issues/81) 증상: 코드 인터프리터(Pyodide)가 `/mnt/uploads`에 만든 SVG를 모델이 `display_file`로 보여주려다 실패했다. 그런데도 "완료"라고 답했고, 채팅에는 Open WebUI 로고(`/favicon.png`)가 회로도처럼 표시됐다.
- 원인:
  - Pyodide는 브라우저에서 실행되므로 `/mnt` 파일은 IDBFS에만 있고 서버는 볼 수 없다.
  - `safeImageUrl`이 `sandbox:`를 `/favicon.png`로 바꾼다.
  - upstream [#34777](https://github.com/open-webui/open-webui/issues/34777)은 같은 증상을 의도된 동작으로 보고 닫았다.
- 소유자 결정:
  - A안(최소 수정)을 택했다.
  - 로직은 fork 전용 파일에 두고 upstream 파일에는 hook 몇 줄만 넣는다. 회귀 방지 CI를 추가한다.
  - 릴리스 루틴에 확인 단계를 추가하는 안은 제외했다.
  - upstream PR은 조사만 했다. 저장소가 GitHub fork가 아니고, 템플릿이 요청 없는 코드 PR을 금지하며, 최근 한 달 외부 PR 9건 중 병합 0건이라 불가로 판단했다.
- Linear:
  - [KOR-71](https://linear.app/koreatimes/issue/KOR-71) 계획은 1차 REVISE(MEDIUM 4) 뒤 2차 APPROVE를 받았다.
  - 하위 작업은 KOR-72(백엔드)와 KOR-73(프론트엔드)다.
  - 승인 계획은 다음 날 [docs/plan](../plan/2026-11-25-kor71-pyodide-display-guard.md)으로 승격했다.

### 수행·증적

1. 백엔드 `b95116fa4`:
   - `utils/kwh_browser_sandbox.py`를 새로 만들었다.
   - `config.py`에서 Pyodide 프롬프트에 안내 문구를 덧붙인다.
   - `builtin.py`의 `display_file`은 `sandbox:`·`/mnt/` 경로일 때만 `exists:false`와 Files 탭 안내를 돌려준다.
2. 프론트엔드 `7f81538b6`:
   - `src/lib/utils/kwh/browserSandboxRef.ts`를 새로 만들었다.
   - `MarkdownInlineTokens.svelte`의 image·link 분기에 안내 span을 넣었다.
   - `i18n:parse`로 64개 locale을 갱신하고 ko-KR 번역을 넣었다.
3. fork 가드:
   - `.github/workflows/kwh-fork-guards.yaml`의 job은 `kwh-guard-frontend`(vitest)와 `kwh-guard-backend`(pytest) 두 개다.
   - 백엔드와 프론트엔드가 판정 예시 JSON을 공유한다.
   - hook이 빠지면 실패하는 wiring 테스트를 넣었고, 로컬에서 hook을 제거해 실제로 실패하는지 확인했다.
   - 첫 CI 실행은 두 가지로 실패해 `a172f1614`로 고쳤다.
     - pytest 9가 `open_webui` 패키지를 import했다. 테스트를 `backend/kwh_guard_tests/`로 옮겼다.
     - onnxruntime CUDA 다운로드가 404였다. `--onnxruntime-node-install-cuda=skip`을 추가했다.
4. `main` ruleset 22414966에 required status check `kwh-guard-frontend`, `kwh-guard-backend`를 추가했다.
   - 설정: `strict=false`, `integration_id` 15368.
   - 소유자 결정은 "가드만 필수"였다.
5. `docs/manual/kwh-release-routine.md` §12에 fork 수정 목록 5행을 추가했다.
6. RC `v0.13.4-kwh.2-rc.1`의 GHCR 빌드는 성공했다.
   - 축적 데이터 게이트 PASS: 586초, upgrade 0건, head `9f6c2a8d1b43`, SQLite `ok`.
   - fresh 게이트 PASS: 72 migrations.
   - 이미지 안 runtime 확인 PASS: 프롬프트 포함, `/mnt`와 `sandbox:`는 `exists:false`, `/home/...`은 upstream 오류 유지.
   - 브라우저에서 저장된 채팅을 다시 열었을 때 안내 3개가 보이고 로고는 0개였다.
7. svelte-check는 로컬 메모리 부족으로 중단됐다. 소유자 결정에 따라 CI 빌드로 대체했다.

### 다음 재개 지점

- 릴리스 경로(소유자 결정): `v0.13.4-kwh.2`는 PR #82로 `main`까지만 병합하고 태그와 배포는 하지 않는다. upstream v0.13.5와 함께 `v0.13.5-kwh.1`로 배포한다. Issue #78은 대체된다. 이후 경과는 [2026-11-26 작업일지](./2026-11-26-openwebui-jobs.md)에 있다.
- 한계: "실패를 성공으로 말하지 않음"은 모델이 프롬프트를 따르는지에 달려 있다. UI가 보장하는 것은 안내 표시뿐이다.
