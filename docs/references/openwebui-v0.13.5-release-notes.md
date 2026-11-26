# Open WebUI v0.13.5 업스트림 변경 참고

기준: [공식 v0.13.5 릴리스](https://github.com/open-webui/open-webui/releases/tag/v0.13.5) (`926f826eaef6179c092a936eede6c7363e425975`, 2026-11-25). 이 문서는 upstream 변경과 알려진 위험만 기록한다. fork의 통합·배포 판정은 별도 증적을 따른다.

## 업그레이드에 영향을 주는 변경

- **채팅 메시지 저장 방식이 바뀐다.** 메시지를 하나씩 따로 저장하므로, 업그레이드할 때 기존 DB의 대화 기록을 변환한다(`5e7a2c9d4b13_move_chat_history_to_chat_message`). 변환은 배치로 실행되며 중단 후 재개할 수 있다. upstream은 DB와 관련 데이터를 먼저 백업하고, 구·신 버전의 형식이 호환되지 않으므로 모든 worker와 서버를 함께 올리라고 안내한다. 따라서 **이미지만 이전 태그로 되돌리는 롤백은 불가능하고, DB 복원이 필요하다.**
- `v0.13.4` 대비 새 Alembic revision은 4개다: 위 메시지 변환, `b7d4f1a2c960_add_resource_tag`, `c4e1a7d93b20_rename_terminal_grants_to_machine`, `d2f86c0b41ae_add_folder_view_state`. `migrations/env.py`도 수정됐다.
- Terminals가 **Machines**로 이름이 바뀐다. 기존 권한은 유지된다. API 클라이언트는 `/api/v1/machines`, `/api/v1/configs/machines`와 `MACHINE_CONNECTIONS` 응답 키로 옮겨야 한다. 환경 변수 `MACHINE_CONNECTIONS`, `MACHINE_PROXY_HEADERS`, `AIOHTTP_CLIENT_TIMEOUT_MACHINE`이 추가됐고, 기존 terminal 이름도 계속 동작한다. 프론트엔드 내부 이름도 `terminalDocument` → `machineDocument` 등으로 바뀌었다.
- 채팅을 고정·이동·보관·공유하는 API가 더 이상 전체 대화를 함께 반환하지 않는다. 메시지는 채팅 자체를 조회해 `chat.history`에서 읽어야 한다. 이전의 평탄화된 메시지 목록을 읽는 외부 클라이언트는 수정이 필요하다.
- 저장된 Arena 구성은 무작위 router로 전환된다. All 또는 제외 목록을 쓴 경우 업그레이드 당일의 모델 목록으로 고정된다. 환경 변수로만 정의한 구성은 `ROUTER_MODELS`로 옮겨야 한다.
- Docling 문서 변환이 백그라운드 job 방식으로 바뀐다. Docling을 쓰는 설치는 업그레이드 전에 서버가 job 제출·진행 조회·결과 다운로드를 지원하는지 확인해야 한다.
- 연결 편집기에 OpenAI API 주소를 입력하면 기본값이 Responses API가 된다. Chat Completions를 전제로 한 연동은 편집기에서 명시적으로 선택해야 한다.
- 자동화가 채널에 올리는 답글은 기본적으로 스레드로 달린다. RAG 기본 프롬프트는 근거 문서 번호를 주장마다 붙이고 모델 자체 지식을 쓸 때 밝히도록 바뀌었다. OLED Dark 테마는 Dark 테마의 사용자 지정 색으로 전환된다.
- 새 설정: `TOOL_OUTPUT_MAX_CHARS`, `RAG_FULL_TEXT_THRESHOLD`/`RAG_FULL_TEXT_THRESHOLD_TYPE`(파일당 기본 50,000자), `AUTOMATION_MAX_CONCURRENT`, `SUBAGENTS_MAX_ASYNC`.

## 알려진 upstream 위험

- 2026-11-26 기준, 메시지 저장 변환과 관련한 열린 upstream 이슈는 확인되지 않았다. 변환 시간은 대화 기록 크기에 비례하므로 축적 데이터에서 실측해야 한다.
- fork 영향: `MarkdownInlineTokens.svelte`의 이미지 분기 이름 변경(`machineDocument`) 때문에 KOR-71 wiring 테스트의 기준점이 바뀌었다. 병합 자체는 충돌이 없었고, fork guard CI가 이를 잡아냈다.

## 검증 초점

1. 축적 데이터에서 메시지 저장 변환의 소요 시간, `alembic current == heads`, 변환 후 기존 채팅 열람·이어쓰기, 백업·복구 절차.
2. OAuth, 일반 채팅, 파일 업로드·RAG(새 인용 프롬프트), 기존 Pipe와 도구 연결.
3. KOR-71 브라우저 샌드박스 안내 문구, Koreatimes 브랜드 등 fork carryover.
4. Machines·Arena·Docling·Responses API는 현재 프로덕션 사용 여부를 확인하고, 사용 중이면 개별 검증한다.
