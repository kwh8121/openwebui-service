# Open WebUI 기능 리서치

작성일: 2026-07-15

## 목적

이 문서는 Open WebUI를 영자 언론사 편집국의 자체 호스팅 AI 작업 환경으로 확장하기 위한 기능 조사 색인이다. 현재 기능, 사용 방식, 운영상 주의점을 기능별 문서로 분리했다. 제품의 빠른 변경을 고려하여 실제 도입 또는 개발 전에는 연결된 공식 문서를 다시 확인한다.

## 기능별 문서

- [채팅, 조사, 멀티모달](openwebui-chat-research.md): 모델 대화, 파일, 웹 검색, 음성, 이미지, 메모리
- [지식베이스와 RAG](openwebui-knowledge-rag-research.md): 기사 아카이브와 스타일 가이드의 검색 기반 활용
- [워크스페이스와 협업](openwebui-workspace-collaboration-research.md): 전용 에이전트, 프롬프트, 노트, 채널, 일정
- [확장과 통합](openwebui-extensibility-research.md): Tools, Functions, MCP, OpenAPI, Pipelines
- [인증, 권한, 보안](openwebui-access-security-research.md): SSO, SCIM, RBAC, 데이터 보호 원칙
- [관리, 평가, 배포](openwebui-operations-research.md): 분석, 모델 평가, API, 저장소, 관측성
- [편집국 적용 청사진](openwebui-newsroom-blueprint.md): 단계별 활용 시나리오와 확장 우선순위

## 조사 범위와 출처

아래의 1차 자료를 기준으로 작성했다.

- Open WebUI 공식 저장소: <https://github.com/open-webui/open-webui>
- 기능 문서: <https://docs.openwebui.com/features/>
- 튜토리얼: <https://docs.openwebui.com/tutorials/>
- 기술 참조: <https://docs.openwebui.com/reference/>
- Community 탐색: <https://openwebui.com/home?sort=hot>

Community의 플러그인이나 프리셋은 인기 또는 추천 표시만으로 신뢰하거나 운영 환경에 바로 반입하면 안 된다. 코드, 호출 대상, 권한, 비밀정보 취급을 검토한 뒤 격리된 환경에서 시험한다.

## 플랫폼 요약

Open WebUI는 Ollama, OpenAI 호환 API 및 여러 모델 공급자를 한 UI에서 사용하도록 하는 자체 호스팅 AI 플랫폼이다. 대화, RAG 기반 지식, 모델 프리셋, 팀 협업, 확장 도구, 권한 관리, 운영 분석을 통합한다. 기본 플랫폼만으로도 편집 보조가 가능하지만, 기사 발행이나 사실 판정의 최종 권한은 사람에게 남겨야 한다.

## 읽는 순서

1. `knowledge-rag`와 `access-security`로 신뢰 가능한 문서 경계와 접근 경계를 먼저 설계한다.
2. `workspace-collaboration`에서 기자, 데스크, 사진, 번역 등 역할별 모델 프리셋과 채널을 만든다.
3. `chat`에서 웹 조사, 출처 제시, 초안, 요약의 표준 작업법을 정한다.
4. `extensibility`로 CMS, 기사 DB, 사진 DAM, 팩트체크 API를 최소 권한으로 연결한다.
5. `operations`의 평가와 분석으로 모델/프롬프트의 품질 및 비용을 지속적으로 측정한다.
