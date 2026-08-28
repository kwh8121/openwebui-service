# OpenCode NotebookLM 네이티브 도구

## 목적

이 통합은 설치 및 인증된 `notebooklm` CLI를 OpenCode의 네이티브 도구로 노출합니다.

설치된 `notebooklm-py` v0.7.3에는 upstream `notebooklm-mcp` 실행 파일이 없으므로, MCP 대신 OpenCode local plugin을 사용합니다.

## 설치 위치

global plugin 경로:

```text
~/.config/opencode/plugins/notebooklm.js
```

OpenCode는 시작할 때 이 디렉터리의 JavaScript 파일을 자동으로 로드합니다. plugin을 변경한 뒤에는 OpenCode를 재시작하세요.

plugin이 호출하는 CLI:

```text
~/.local/bin/notebooklm
```

기존 NotebookLM CLI profile 및 `~/.notebooklm/` 의 저장된 인증 정보를 재사용합니다.

## 네이티브 도구

| 도구 | 목적 |
| --- | --- |
| `notebooklm_list_notebooks` | 접근 가능한 모든 NotebookLM 노트북을 나열합니다. |
| `notebooklm_list_sources` | 지정 노트북의 인덱싱된 source를 나열합니다. |
| `notebooklm_list_saved` | 지정 노트북에 저장된 note를 나열합니다. |
| `notebooklm_search_saved` | 제목 또는 미리보기 텍스트로 저장된 note를 찾습니다. |
| `notebooklm_read` | 저장된 note 또는 인덱싱된 source 텍스트를 읽습니다. |
| `notebooklm_save` | 저장된 note를 생성하거나 수정합니다. |
| `notebooklm_search` | 인덱싱된 source를 대상으로 근거 및 citation이 포함된 NotebookLM 질문을 실행합니다. |

## 일반적인 네이티브 흐름

1. `notebooklm_list_notebooks` 를 호출해 전체 notebook ID를 얻습니다.
2. `notebooklm_list_saved` 또는 `notebooklm_list_sources` 로 콘텐츠를 찾습니다.
3. `item_type: "note"` 또는 `item_type: "source"` 로 `notebooklm_read` 를 호출합니다.
4. notebook ID, title, content를 넣어 `notebooklm_save` 를 호출하면 note를 생성합니다.
5. 기존 note를 수정할 때는 `notebooklm_save` 에 `note_id` 를 함께 넣습니다.
6. 제목이나 미리보기 텍스트로 note를 찾으려면 `notebooklm_search_saved` 를 호출합니다.
7. 인덱싱된 source를 대상으로 citation 포함 의미 검색을 하려면 `notebooklm_search` 를 호출합니다.

## 필수 인자

notebook을 다루는 모든 도구에는 전체 `notebook_id` 가 필요합니다.

`notebooklm_read` 필수 인자:

```json
{
  "notebook_id": "<full notebook UUID>",
  "item_id": "<full note or source UUID>",
  "item_type": "note"
}
```

인덱싱된 source 텍스트를 읽으려면 `"item_type": "source"` 를 사용합니다.

`notebooklm_save` 로 새 note를 만들 때는 `content` 외에 `title` 도 필요합니다. title은 생성 뒤 plugin이 note ID를 검증하는 데 사용합니다.

## 알려진 제약 사항

- 내부 NotebookLM 통합은 비공식이며 Google web-session 인증을 사용합니다.
- `notebooklm-py` v0.7.3은 note 생성 성공 시에도 `id: null` 을 잘못 반환합니다. plugin은 생성 전후 saved-note 목록을 비교해 실제 ID를 반환합니다.
- source 읽기는 plain indexed text를 사용합니다. Markdown 출력에는 현재 CLI 환경에 설치되지 않은 선택 의존성 `notebooklm-py[markdown]` 이 필요합니다.
- `notebooklm_search_saved` 는 제목/미리보기 텍스트를 대소문자 구분 없이 찾는 로컬 검색입니다. 저장된 모든 note 본문을 full-text 검색하지는 않습니다.
- `notebooklm_search` 는 citation 기반 의미 검색 경로이지만, saved-note 본문이 아닌 NotebookLM indexed source를 검색합니다.
- 이 plugin은 OpenCode 전용입니다. released `notebooklm-py` 가 실제 `notebooklm-mcp` 를 제공할 때에만 upstream MCP server로 전환하세요.
