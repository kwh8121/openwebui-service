# KOR-71 Pyodide 생성 파일 표시 실패 수정 (GH #81, A안 + 회귀 방지)

- 상태: 계획 승인 2026-11-25 (Linear [KOR-71](https://linear.app/koreatimes/issue/KOR-71), 1차 REVISE → 2차 APPROVE)
- 하위 작업: KOR-72 (백엔드), KOR-73 (프론트엔드)
- 원 리포트: [GitHub #81](https://github.com/kwh8121/openwebui-service/issues/81). upstream [#34777](https://github.com/open-webui/open-webui/issues/34777)은 의도된 동작으로 종료됐다.

## 문제

Pyodide `execute_code`는 브라우저에서 실행된다. `/mnt/uploads`에 만든 파일은 브라우저 IDBFS에만 있고 서버는 볼 수 없다. 모델이 그 파일을 `display_file`이나 `sandbox:` 링크로 보여주려다 실패했는데, 사용자에게는 "완료"라는 답과 함께 Open WebUI 로고(`/favicon.png`)가 보였다.

- `display_file`은 파일 ID나 `/api/v1/files/<id>/content`만 받는다. 터미널이 있으면 파일 ID가 아닌 경로는 터미널로 간다(`middleware.py`).
- `safeImageUrl`은 `sandbox:`를 `/favicon.png`로 바꾼다. `/mnt/...`는 상대 경로로 통과해 404가 난다. `safeLinkUrl`은 `sandbox:` 링크의 href를 비운다.

## 범위 (A안: 최소 수정)

1. **백엔드**: Pyodide 시스템 프롬프트에 파일 표시 규칙을 추가한다. `display_file`이 브라우저 경로(`sandbox:`, `/mnt/`, `file:///mnt/`)를 받을 때**만** 이유와 Files 탭 안내를 담아 실패를 돌려준다. 그 외 경로는 upstream 문구를 유지한다.
2. **프론트엔드**: 해당 경로의 이미지·링크를 로고나 깨진 링크 대신 안내 문구로 보여준다.
3. **회귀 방지**: 로직은 fork 전용 파일에 두고 upstream 파일에는 호출 몇 줄만 넣는다. upstream 파일에서 호출이 빠지면 실패하는 연결 테스트를 fork 전용 CI에 둔다.
4. `docs/manual/kwh-release-routine.md` §12 fork 수정 목록에 항목을 추가한다.

범위 밖: 서버 파일 등록(B안), 릴리스 루틴 확인 단계 추가, upstream PR(외부 PR 수용 사례가 없어 제외).

## 수용 기준

- 터미널이 없을 때 `display_file("/mnt/uploads/x.svg")`는 `exists:false`와 Files 탭 안내를 돌려주고, 표시했다고 말하지 말라고 지시한다.
- 터미널이 선택된 경우 `display_file` 동작은 바뀌지 않는다.
- `![x](sandbox:/mnt/...)`나 `![x](/mnt/...)`는 안내로 보인다. 저장된 채팅을 다시 열어도 같다.
- 일반 이미지(`data:`, `/api/v1/files/...`, 외부 URL)와 다른 `display_file` 실패 문구는 바뀌지 않는다. 실패 JSON의 `exists:false`, `error` 키를 유지한다.
- upstream 파일에서 fork 연결 코드가 빠지면 fork 가드 CI가 실패한다. PR(`main`, `integration/v*`)과 `integration/**` push에서 실행된다.
- RC 로컬 게이트 PASS와 브라우저 확인.

**한계**: "실패를 성공으로 말하지 않음"은 모델이 프롬프트와 도구 오류를 따라야 성립한다. UI가 보장하는 것은 이미지·링크 안내뿐이다.

## 설계

| 위치                                                     | 내용                                                                                                                   |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `backend/open_webui/utils/kwh_browser_sandbox.py` (fork) | `PYODIDE_FILE_DISPLAY_GUIDANCE`, `is_browser_sandbox_ref`, `browser_sandbox_display_error`. open_webui import 없음     |
| `backend/open_webui/config.py` (hook)                    | `CODE_INTERPRETER_PYODIDE_PROMPT += PYODIDE_FILE_DISPLAY_GUIDANCE`                                                     |
| `backend/open_webui/tools/builtin.py` (hook)             | `display_file`의 파일 ID 형식 실패 분기에서 브라우저 경로일 때만 helper 결과 반환                                      |
| `src/lib/utils/kwh/browserSandboxRef.ts` (fork)          | `isBrowserSandboxRef(href)`: 공백 제거, 대소문자 무시                                                                  |
| `MarkdownInlineTokens.svelte` (hook)                     | image 분기는 machine(구 terminal) 문서 분기 **뒤**, link 분기는 note 링크 분기 뒤에 `{:else if}` 안내                  |
| `src/lib/i18n/locales/*` (hook)                          | 안내 문구는 Svelte 안 `$i18n.t('...')` 리터럴. `i18n:parse` 산출물과 ko-KR 번역 커밋                                   |
| `src/lib/utils/kwh/browserSandboxRefCases.json` (fork)   | 백엔드·프론트 공통 판정 예시                                                                                           |
| `.github/workflows/kwh-fork-guards.yaml` (fork)          | job `kwh-guard-frontend`(vitest), `kwh-guard-backend`(pytest). paths 필터 없음. upstream 소유 workflow는 수정하지 않음 |

연결 테스트는 공백을 허용하는 정규식으로 hook의 import와 호출 위치를 확인한다(prettier·ruff 재포맷 내성). `main` ruleset 22414966에는 가드 job 2개만 required status check로 등록한다(`strict_required_status_checks_policy: false`, `integration_id: 15368`, 소유자 결정 2026-11-25).

## 구현 중 계획과 달라진 점

- 백엔드 가드 테스트 위치: `backend/open_webui/test/kwh/` → `backend/kwh_guard_tests/`. pytest 9가 상위 패키지 `open_webui`를 import해 pytest만 설치한 CI에서 실패했다.
- frontend job의 `npm ci`에 `--onnxruntime-node-install-cuda=skip`을 추가했다. CUDA 바이너리 다운로드 404 때문이다.
- svelte-check는 로컬 메모리 부족으로 중단돼, 소유자 결정에 따라 CI 빌드(RC GHCR, PR Format & Build)로 대체했다.
- 릴리스: `v0.13.4-kwh.2`는 `main`까지만 병합(PR #82)하고 최종 태그·배포 없이 upstream v0.13.5와 함께 `v0.13.5-kwh.1`로 배포한다(소유자 결정). Issue #78(`v0.13.4-kwh.1`)은 대체된다.
- v0.13.5 병합 후 upstream이 `terminalDocument`를 `machineDocument`로 바꿔 가드가 실패했다(RC.1). hook은 제자리에 남아 있었고, 테스트 기준점을 두 이름 모두 허용하도록 고쳤다(`339f2c32b`). 가드가 의도대로 동작한 사례다.
