# OpenCode NotebookLM 최소 워크플로

이 문서는 현재 이 환경에서 OpenCode로 NotebookLM을 사용하는 가장 작고 안정적인 방법을 정리합니다.

의도적으로 MCP 기반이 아니라 CLI 기반으로 작성했습니다.

이유:
- 이 환경에는 `notebooklm` 이 이미 설치되어 있고 인증도 완료되어 있습니다.
- 현재 설치된 CLI는 실제 NotebookLM 작업을 정상적으로 수행합니다.
- 현재 설치된 `notebooklm-py` 릴리스는 이 환경에서 동작하는 `notebooklm mcp` 명령이나 `notebooklm-mcp` 엔트리포인트를 아직 제공하지 않습니다.

## 이 워크플로의 목적

다음처럼 OpenCode에서 NotebookLM을 최소한의 구성으로 호출하고 싶을 때 사용합니다:
- 인증 확인
- 노트북 생성
- 소스 추가
- 인덱싱 대기
- 질문 실행
- 필요 시 리포트 생성

## 전제 조건

현재 환경에서는 이미 충족되어 있으며, 이 워크플로는 아래만 가정합니다:
- `notebooklm` 이 `PATH` 에 있음
- NotebookLM 인증이 유효함
- 작은 JSON 파싱용 `python3` 가 있음

## OpenCode에서의 권장 사용 방식

OpenCode에서는 아래 명령을 `bash` 도구로 한 단계씩 실행하세요.

반복 자동화에서는 NotebookLM의 암묵적 active context에 의존하지 말고, 가능한 한 명시적인 ID를 사용하세요.

## 0. 먼저 인증 상태 확인

```bash
notebooklm auth check --test --json
```

성공 기준:
- `"status": "ok"`
- `"token_fetch": true`

## 1. 노트북을 생성하고 ID를 캡처

```bash
NOTEBOOK_JSON=$(notebooklm create "OpenCode NotebookLM Workflow Test" --json) && python3 -c 'import json,os; print(json.loads(os.environ["NOTEBOOK_JSON"])["notebook"]["id"])'
```

같은 명령 세션 안에서 shell 변수로 저장하고 싶다면:

```bash
NOTEBOOK_ID=$(notebooklm create "OpenCode NotebookLM Workflow Test" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["notebook"]["id"])') && printf '%s\n' "$NOTEBOOK_ID"
```

## 2. 소스 하나를 추가하고 source ID를 캡처

URL을 사용하는 예시:

```bash
SOURCE_ID=$(notebooklm source add "https://docs.openwebui.com/" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["source"]["id"])') && printf '%s\n' "$SOURCE_ID"
```

로컬 파일을 사용하는 예시:

```bash
SOURCE_ID=$(notebooklm source add ./README.md --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["source"]["id"])') && printf '%s\n' "$SOURCE_ID"
```

## 3. 해당 소스의 처리 완료까지 대기

```bash
notebooklm source wait "$SOURCE_ID" --timeout 600 --json
```

성공 기준:
- timeout이 발생하지 않음
- 반환된 source 상태가 ready 임

## 4. 근거 기반 질문 실행

NotebookLM 채팅은 인덱싱이 끝난 뒤에 가장 잘 동작합니다.

```bash
notebooklm ask "Summarize the main purpose of this source and list the top three important details." --json
```

특정 소스 하나로만 답변 범위를 제한하고 싶다면:

```bash
notebooklm ask "Summarize this one source only." -s "$SOURCE_ID" --json
```

## 5. 선택 사항: 오디오 대신 리포트 생성

최소 안정 워크플로에서는 `audio` 나 `video` 보다 `report` 를 우선 권장합니다.

```bash
notebooklm generate report --format briefing-doc --json
```

그다음 artifact를 확인합니다:

```bash
notebooklm artifact list --json
```

필요하면 artifact 완료까지 기다린 뒤 다운로드합니다:

```bash
ARTIFACT_ID=$(notebooklm artifact list --json | python3 -c 'import json,sys; data=json.load(sys.stdin)["artifacts"]; print(data[0]["id"] if data else "")') && printf '%s\n' "$ARTIFACT_ID"
```

```bash
notebooklm artifact wait "$ARTIFACT_ID" --timeout 900 --json
```

```bash
notebooklm download report ./notebooklm-report.md -a "$ARTIFACT_ID"
```

## 최소 스모크 테스트 흐름

OpenCode가 이 환경에서 실제로 NotebookLM을 사용할 수 있는지만 가장 짧게 검증하고 싶다면, 아래 순서만 실행하면 됩니다.

```bash
notebooklm auth check --test --json
```

```bash
NOTEBOOK_ID=$(notebooklm create "OpenCode NotebookLM Smoke Test" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["notebook"]["id"])') && printf '%s\n' "$NOTEBOOK_ID"
```

```bash
SOURCE_ID=$(notebooklm source add ./README.md --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["source"]["id"])') && printf '%s\n' "$SOURCE_ID"
```

```bash
notebooklm source wait "$SOURCE_ID" --timeout 600 --json
```

```bash
notebooklm ask "Give me a concise summary of this repository from the indexed source." -s "$SOURCE_ID" --json
```

이것이 현재 기준의 최소 실제 워크플로입니다.

## 지금은 피해야 할 것

현재 OpenCode 자동화에서는 아래 방식은 피하세요:
- 현재 shell Python에서 `python3 -c 'import notebooklm'` 를 직접 실행하는 방식
- OpenCode에 이미 NotebookLM용 native MCP tool surface가 있다고 가정하는 방식
- 여러 자동화 단계에서 암묵적 notebook context에 의존하는 방식

## 왜 explicit ID가 중요한가

설치된 CLI는 active notebook context를 지원하지만, OpenCode 자동화에서는 각 단계가 명시적으로 ID를 넘기는 편이 더 안전합니다.

기본 규칙은 다음과 같습니다:
- 노트북 생성 시 notebook ID를 바로 캡처
- 소스 추가 시 source ID를 바로 캡처
- wait/download 전에 artifact ID를 먼저 캡처

## 이 워크플로 다음 단계

이 CLI 기반 워크플로로 충분하다면 그대로 계속 사용해도 됩니다.

NotebookLM을 CLI 시퀀스가 아니라 OpenCode의 native tool처럼 사용하려면, 현재 설정된 global local plugin을 사용하면 됩니다.

현재 설정된 OpenCode native plugin 도구 사용법은 [OpenCode NotebookLM Native Tools](./opencode-notebooklm-native-tools.md)를 참고하세요.
