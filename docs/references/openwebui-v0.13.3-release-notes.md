# Open WebUI v0.13.3 업스트림 변경 참고

기준: [v0.13.0](https://github.com/open-webui/open-webui/releases/tag/v0.13.0), [v0.13.1](https://github.com/open-webui/open-webui/releases/tag/v0.13.1), [v0.13.2](https://github.com/open-webui/open-webui/releases/tag/v0.13.2), [v0.13.3](https://github.com/open-webui/open-webui/releases/tag/v0.13.3). 이 문서는 upstream 변경만 기록하며 fork 배포 판정은 릴리스별 배포 가이드와 GitHub Actions 증적을 따른다.

## 업그레이드에 영향을 주는 변경

- v0.13.0과 v0.13.1은 DB 스키마 변경을 포함한다. 여러 worker·서버·로드 밸런서 구성에서는 인스턴스를 동시에 올려야 하며 롤링 업데이트는 지원하지 않는다. 업그레이드 전 데이터 백업과 마이그레이션 확인이 필요하다.
- v0.13.0은 탭형 작업공간, 사이드 채팅, 관리자 분석과 Responses API 경로를 확장한다. 채팅·화면·권한 흐름의 회귀 검사가 필요하다.
- v0.13.1부터 native function calling의 첨부 파일은 기본적으로 자동 선적재되지 않고 파일 도구를 통해 읽는다. 도구를 쓸 수 없는 모델은 `Preload files`를 켜야 한다. 기본 RAG 검색 수와 새 파일의 청크 크기도 바뀐다.
- v0.13.1은 메모리·스킬 목록·첨부 지식 목록을 숨겨진 tool result로 전달한다. 커스텀 Pipe는 마지막 메시지가 tool 메시지일 수 있음을 고려해야 한다. 도구 권한의 Auto 모드는 기본적으로 꺼져 있다.
- v0.13.2는 일반 HTTP 주소에서 채팅과 댓글·Markdown 편집이 실패하던 UUID 문제를 고쳤다. 로컬 테스트의 HTTP 접속 경로를 확인한다.
- v0.13.3은 Open Terminal의 coding agent 자동화와 채팅 중 터미널·폴더 변경 기능을 추가하고, 터미널 전환 뒤 파일 탭과 agent 목록이 이전 터미널을 가리키던 문제를 고쳤다.

## fork 검증 초점

1. 마이그레이션 로그와 `alembic current == heads`, 기존 데이터 보존, 롤백 시 백업 복원 경로.
2. OAuth 로그인·재시작, 일반 채팅·모델 전환·사이드 채팅, 관리자 분석 화면.
3. 파일 업로드와 RAG: 도구 지원 모델의 파일 읽기 및 도구 미지원 모델의 `Preload files` 설정.
4. Pipe의 마지막 메시지 형태와 기존 도구 호출 계약, Koreatimes 브랜드·추천 프롬프트 기본값.
5. 로컬 HTTP 주소의 채팅·댓글·Markdown 편집, 터미널이 연결된 환경의 전환 동작.
