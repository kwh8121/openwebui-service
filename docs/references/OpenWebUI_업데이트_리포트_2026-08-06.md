# OpenWebUI 프로젝트 가이드

## 버전업 변경사항 분석 및 업데이트 리포트

- **분석 기준**: OpenWebUI v0.9.x ~ v0.11.0 (2026-07-27)
- **작성일**: 2026-08-06
- **용도**: Multi-AI Desk 프로젝트 참조용

---

## 0. 리포트 개요

이 리포트는 프로젝트에 등록된 OpenWebUI 가이드 파일(01~08.md)과 MVP 계획 문서(보완본 V1, 개선안)를 기준으로, 최신 OpenWebUI 공식 문서(docs.openwebui.com)와 GitHub 릴리스(v0.9.x ~ v0.11.0)를 비교하여 발견한 주요 변경사항을 정리합니다.

각 변경사항에 대해 (1) 무엇이 변했는지, (2) 기존 프로젝트 파일에 어떤 영향이 있는지, (3) MVP 계획에 반영할 사항이 있는지를 분석합니다.

---

## 1. 핵심 변경사항 요약

아래 표는 프로젝트에 가장 큰 영향을 미치는 변경사항을 우선순위순으로 정리한 것입니다.

| # | 변경 사항 | 영향도 | 해당 파일 |
|---|---------|--------|---------|
| **1** | **Sub-agents (v0.11.0 신규)** | **높음** | 03-models, MVP 보완본 |
| **2** | **Calendar 기능 (신규 섹션)** | **높음** | 가이드 신규 파일 필요 |
| **3** | **MCP: Streamable HTTP 전용 + OAuth 2.1** | **높음** | 03-models, 07-deploy |
| 4 | Ecosystem 섹션 (Computer, oikb) | 중간 | 06-terminal, README |
| 5 | Fully Async 백엔드 전환 | 중간 | 03-models, MVP 보완본 |
| 6 | Knowledge: 13 VDB + 8 엔진 + Agentic | 중간 | 02-knowledge |
| 7 | Chat: Fork, Timer, Queue, Variables | 중간 | 01-chat |
| 8 | UI 전면 재설계 (v0.11.0) | 낮음 | CSS 커스터마이징 재검증 |
| 9 | LDAP 그룹 동기화 강화 | 낮음 | 05-auth |
| 10 | 성능 최적화 대량 적용 | 낮음 | 07-deploy |

---

## 2. 신규 기능 상세 분석

### 2-1. Sub-agents (v0.11.0)

모델이 작업의 일부를 백그라운드 헬퍼 에이전트에게 위임할 수 있는 기능입니다. 각 헬퍼는 자체적인 도구 기반 대화를 실행하고 결과를 메인 채팅으로 보고합니다.

**주요 특징:**

- 관리자가 Admin Settings에서 활성화해야 사용 가능 (기본 비활성)
- 동시 실행 수, 반복 횟수, 출력 상한, 공유 시스템 프롬프트 설정 가능
- 각 서브에이전트는 완전한 도구 접근 권한을 가진 별도 채팅으로 실행
- 추가 LLM 호출 비용 발생

**MVP 영향:** 보도자료 파이프라인(SG3)에서 요약→번역→저장 단계를 서브에이전트로 분산 처리하는 패턴을 고려할 수 있음. 다만 비용 증가를 감안하여 Phase 4 이후 검토 권장.

### 2-2. Calendar (신규 기능 섹션)

OpenWebUI에 내장된 개인 캘린더 기능입니다. 기존 가이드 파일에는 전혀 없는 완전 신규 기능 영역입니다.

**핵심 기능:**

- 월/주/일 뷰 지원, 색상 코딩, RRULE 반복 일정
- AI 에이전트 자율 관리: 모델이 자연어로 이벤트 생성/수정/삭제/검색 가능
- Automation 통합: 활성 Automation이 '예약 작업' 캘린더에 가상 이벤트로 표시
- 캘린더 공유: 사용자/그룹 단위 읽기/쓰기 권한 부여
- 참석자 RSVP 추적 (pending/accepted/declined/tentative)
- 리마인더 알림: Toast, 브라우저 알림, Webhook 지원
- `ENABLE_CALENDAR` 환경변수로 전역 제어 (기본 활성)

**MVP 영향:** 편집회의 일정 관리, 보도자료 마감 추적 등에 활용 가능. MVP 개선안의 편집회의 브리핑(Feature F)과 연계하면 시너지 가능. 가이드 파일 신규 작성 필요.

### 2-3. MCP: Streamable HTTP 전용 + OAuth 2.1

v0.6.31부터 네이티브 MCP 지원이 추가되었으며, Streamable HTTP 트랜스포트만 지원합니다. SSE/stdio 방식의 MCP 서버는 mcpo 프록시를 통해 변환해야 합니다.

**변경 요약:**

- MCP 서버 등록은 관리자 전용 (Admin Settings → External Tools)
- 인증 모드: None, Bearer, OAuth 2.1 (DCR), OAuth 2.1 (Static)
- 사용자 정의 헤더에 `{{USER_ID}}`, `{{USER_EMAIL}}` 등 템플릿 토큰 지원
- OpenAPI와 MCP 도구를 혼용 가능
- OpenAPI가 여전히 권장 통합 경로 (엔터프라이즈 준비도, 운영 탄력성, 관측 가능성)

**MVP 영향:** 기존 보완본의 MCP 관련 내용을 업데이트해야 합니다. FastAPI 서비스를 OpenAPI Tool Server로 등록하는 것이 기본 경로이며, MCP는 필요시 보조 수단으로 사용합니다.

### 2-4. Ecosystem 섹션 (신규)

OpenWebUI 코어 외부의 공식 프로젝트를 묶는 새로운 문서 섹션입니다.

**포함 프로젝트:**

- **Open Terminal & Terminals**: 기존 Open Terminal의 확장. 기업용 오케스트레이터로 사용자별 워크스페이스 프로비저닝, 정책(이미지/도구/리소스/보안/정리) 관리
- **Open WebUI Computer**: 브라우저에서 전체 컴퓨터 환경 제공 (파일, 터미널, git, 에디터). 자체 에이전트 런타임 포함. OpenAI 호환 게이트웨이를 통해 OpenWebUI에 연결
- **Knowledge Base Sync (oikb)**: 폴더, 리포, 버킷, 위키 등의 소스를 Knowledge Base에 증분 동기화

**MVP 영향:** oikb를 활용하면 사내 스타일 가이드(AP Style, Elements of Style)의 Knowledge 동기화를 자동화할 수 있습니다. Phase 5(SG9) 작업 시 검토 권장.

### 2-5. Fully Async 백엔드

OpenWebUI 백엔드가 완전 비동기(fully async)로 전환되었습니다. 동기/CPU 바운드 플러그인 코드는 워커 스레드 풀(`THREAD_POOL_SIZE`)로 오프로드됩니다.

**실무 의미:**

- 장시간 실행 Tool/Function(외부 API 대기, 느린 쿼리 등)이 다른 사용자를 차단하지 않음
- GPU 접근, 대규모 의존성, 격리/독립 스케일링이 필요한 경우에만 외부 서비스 분리 필요
- 기존 보완본의 '외부 서비스 우선' 원칙은 여전히 유효하나, 경량 작업은 인프로세스 Function으로도 충분

**MVP 영향:** 번역/요약 같은 경량 Tool은 인프로세스에서 실행해도 성능 문제가 없습니다. 교정/이미지 생성처럼 무거운 작업만 외부 FastAPI로 분리하는 하이브리드 전략이 합리적입니다.

---

## 3. 기존 기능 영역별 변경사항

### 3-1. Chat & Conversations (01-chat-and-conversations.md)

**추가/변경된 기능:**

| 기능 | 설명 | 버전 |
|------|------|------|
| **Chat Fork** | 대화의 특정 지점에서 분기하여 별도 채팅으로 복사. 원본 유지 | v0.11.0 |
| **Chat Timer** | 모델이 타이머를 설정하여 지정 시간 후 프롬프트 재진입 | v0.11.0 |
| **Chat Variables** | 시스템 프롬프트에서 텍스트박스/드롭다운 필드 선언, 대화별 값 저장 | v0.11.0 |
| **Message Queue** | AI 응답 중에도 계속 타이핑 가능, 메시지 자동 전송 | v0.10+ |
| **Chat Compact 명령** | 긴 대화를 수동으로 즉시 요약 (자동 임계치 대기 불필요) | v0.11.0 |
| **공개 채팅 공유** | 로그인 없이 링크로 채팅 열람 가능 (관리자 허용 필요) | v0.11.0 |
| **Chat Preview** | 사이드바에서 채팅 호버 시 최근 메시지 미리보기 | v0.11.0 |
| **읽지 않음 표시** | 폴더에 읽지 않은 채팅 수 배지, 읽음 표시 관리 | v0.11.0 |
| **Folder Pages** | 폴더를 열면 전용 페이지에서 채팅 정렬/페이징 | v0.11.0 |
| **Context Status** | 슬래시 메뉴에서 컨텍스트 윈도우 사용량 확인 | v0.11.0 |
| **User Variables** | 계정 설정에서 개인 변수 저장, 시스템 프롬프트에 삽입 | v0.11.0 |
| **Agentic File 검색** | 모델이 첨부 파일을 의미/텍스트 검색으로 자율 탐색 | v0.11.0 |

### 3-2. Knowledge & RAG (02-knowledge-and-rag.md)

**주요 변경:**

- 벡터 데이터베이스: 13종 지원 (ChromaDB, PGVector 공식 유지 + Qdrant, Milvus, Elasticsearch 등 비코어 통합)
- 하이브리드 검색: BM25 + 벡터 검색 + Cross-encoder 리랭킹
- 추출 엔진: 8종 (Tika, Docling, Azure, Mistral OCR, Datalab Marker, MinerU, PaddleOCR, Custom loaders)
- Agentic Retrieval: 모델이 문서를 자율적으로 검색하고 읽기
- Knowledge Base Sync (oikb): 외부 소스와 증분 동기화 도구 (Ecosystem)
- Knowledge 도구 제한: 검색 반환량, 스캔 파일 수, 매칭 수 제한 설정 가능

### 3-3. Models, Workspace & Extensibility (03-models-workspace-and-extensibility.md)

**주요 변경:**

- Skills: 슬래시 명령에서 선택 가능한 독립 기능으로 승격. 마크다운 기반 작업 지침 세트
- Prompts: 타입이 지정된 입력 변수 + 버전 관리 지원
- Memory: 모델별 On/Off 설정 가능 (일상 어시스턴트는 ON, 특수 모델은 OFF)
- Sub-agents: 모델이 서브에이전트에게 작업 위임 (2-1장 참조)
- 플러그인 비활성화: `ENABLE_PLUGINS`로 Tool/Function 전체 비활성화 가능
- Function 이벤트: 활성/비활성 시 이벤트 발생 (setup/teardown 지원)
- 다중 선택 설정: Tool/Function에서 여러 옵션을 체크박스로 선택 가능
- OpenAPI Tool Server: 사용자별 직접 추가 가능 (Direct Tool Servers 권한)
- LiteLLM 커넥션 타입 추가, Anthropic 네이티브 passthrough 지원

### 3-4. Notes, Channels & Collaboration (04-notes-channels-and-collaboration.md)

**주요 변경:**

- Notes: 파일 첨부 지원, 텍스트/마크다운 파일 임포트, 노트와 채팅 간 전환 강화
- Notes Agentic: 모델이 노트를 자율적으로 검색/읽기/업데이트
- Channels: AI가 채널 전체를 자율적으로 검색·종합 (AI channel awareness)
- Channels: 답글 위치 선택 (스레드 vs 채널 직접), 전체 응답 저장 개선
- Shared Folders: 공유 폴더 협업 (읽기/쓰기 권한별 파일·시스템 프롬프트 활용)

### 3-5. Auth, Access & Administration (05-auth-access-and-administration.md)

**주요 변경:**

- LDAP 그룹 동기화: LDAP 그룹을 OpenWebUI 그룹에 매핑, 자동 생성 옵션
- OAuth/OIDC On/Off 스위치: 설정 삭제 없이 SSO 활성/비활성 토글
- PKCE: Google, Microsoft, GitHub 포함 모든 SSO 프로바이더에 적용
- OAuth Token Exchange: 신뢰 클라이언트 목록 + 속도 제한 설정
- 그룹 공유 제한: 리소스의 그룹 공유 제한 권한 추가
- 감사 로그 개선: 응답 본문 저장, 성능 최적화
- Webhook 알림 목표: 여러 webhook 목적지, 이벤트별 필터링
- 개인 Usage 대시보드: 토큰 히트맵, 스트릭, 최다 사용 모델/도구 통계

### 3-6. Open Terminal & Code Execution (06-open-terminal-and-code-execution.md)

**주요 변경:**

- Open Terminal이 Ecosystem 섹션으로 확장: 독립 프로젝트로 분리
- Terminals (오케스트레이터): 사용자별 거버넌스 워크스페이스 프로비저닝, 정책 관리
- Open WebUI Computer: 브라우저에서 전체 컴퓨터 환경 (파일, 터미널, git, 에디터)
- 파일 브라우저: 드래그앤드롭 이동, HTML 파일 미리보기, WebSocket 프록시
- 실시간 정책/지침 갱신: 서버 재시작 없이 정책 변경 즉시 반영

### 3-7. Deployment, Integrations & Operations (07-deployment-integrations-and-operations.md)

**주요 변경:**

- v0.11.0 UI 전면 재설계: CSS 커스터마이징이 영향받을 수 있음 (패치 재검증 필요)
- Cloud Storage: S3, GCS, Azure Blob 공식 지원 (Stateless 인스턴스용)
- Redis 대폭 개선: hiredis 파서 내장, Sentinel failover 수정, 클러스터 모드 지원
- `ENABLE_ORJSON`: 고속 JSON 인코더 선택 옵션
- OpenTelemetry: traces, metrics, logs 내보내기 공식 지원
- OpenSERP: API 키 없이 자체 호스팅 검색 엔진 연동
- Anthropic 네이티브 API 호환 추가 (reasoning, structured output, token counting)
- Sovereign AI / Enterprise 섹션 신설

---

## 4. MVP 계획 영향 분석

### 4-1. 보완본 V1 수정 필요 사항

| 항목 | 현재 내용 | 수정 방향 |
|------|---------|---------|
| 1-3 확장 수단표 | Event Function 미포함 | Event Function 행 추가 (on_enable/on_disable 이벤트) |
| MCP 관련 | 미언급 | MCP Streamable HTTP + mcpo 프록시 설명 추가 |
| 3장 업그레이드 안전성 | CSS 오버라이드 언급 | v0.11.0 UI 재설계로 CSS 패치 재검증 필수 명시 |
| 5-1 보도자료 파이프라인 | Pipe Function 권장 | Async 백엔드 활용 가능성 언급 (인프로세스 장시간 작업 가능) |
| 5-4 Automation | 주기/트리거 연결 | Calendar 통합 설명 추가 (Scheduled Tasks 가상 캘린더) |
| 6장 SG9 RAG | Knowledge 바인딩 권장 | Agentic Retrieval + oikb 동기화 도구 언급 |

### 4-2. 개선안 수정 필요 사항

| 항목 | 현재 내용 | 수정 방향 |
|------|---------|---------|
| 1-1 타임라인 | v0.10.x 기준 | v0.11.0 UI 재설계 반영 (브랜딩/CSS Phase 7 리스크 증가) |
| 3-1 테스트 전략 | 기능 테스트 중심 | v0.11.0 보안 수정사항 반영한 보안 테스트 항목 추가 |
| 4. 편집국 기능 | 6종 제안 | Calendar 연동 기능 추가 제안 가능 |
| 5-1 운영 체계 | 기본 모니터링 | OpenTelemetry + ENABLE_ORJSON 활용 언급 |
| 8-1 시스템 프롬프트 | 모델별 관리 | User Variables + Chat Variables 활용 방안 추가 |
| 8-2 비용 관리 | 모델 티어링 | Sub-agents 비용 고려사항 추가 |

### 4-3. 신규 활용 기회

**1. Calendar + Automation 연계**

편집회의 일정을 Calendar에 등록하고, Automation으로 회의 전 자동 브리핑 생성 → Calendar의 Scheduled Tasks로 통합 관리. 개선안 Feature F(편집회의 브리핑)의 구현 난이도를 낮출 수 있습니다.

**2. Agentic File 검색 + 보도자료**

보도자료를 첨부하면 모델이 자율적으로 파일 내용을 검색·분석하는 패턴. 기존 Pipe Function 방식보다 유연하지만, 결정적 실행이 필요한 뉴스룸 워크플로우에는 Pipe Function이 여전히 적합합니다.

**3. oikb로 스타일 가이드 자동 동기화**

AP Style Guide, Korea Times House Style 문서를 Git 리포나 공유 폴더에서 Knowledge Base로 자동 동기화. SG9의 '지식 RAG 안정화'에 직접 기여합니다.

**4. Chat Variables로 기사 메타데이터 입력**

기사 작성 모델 프리셋에서 Chat Variables로 섹션(정치/경제/사회), 기사 유형(스트레이트/기획), 우선순위 등을 선언하면 대화 시작 시 구조화된 입력을 받을 수 있습니다.

**5. Sub-agents로 팩트체크 + 번역 동시 실행**

기사 작성 시 서브에이전트가 동시에 팩트체크(웹 검색)와 번역을 실행하는 패턴. 다만 비용과 결정성 면에서 MVP 이후 검토 대상입니다.

---

## 5. 가이드 파일 업데이트 권고

| 파일 | 업데이트 유형 | 주요 내용 |
|------|------------|---------|
| 01-chat-and-conversations.md | **수정** | Fork, Timer, Queue, Variables, Compact, Sub-agents 추가 |
| 02-knowledge-and-rag.md | **수정** | 13 VDB, 8 엔진, Agentic Retrieval, Hybrid Search, oikb 추가 |
| 03-models-workspace-and-extensibility.md | **수정** | Skills, Sub-agents, MCP Streamable HTTP, Memory toggle 추가 |
| 04-notes-channels-and-collaboration.md | **수정** | Agentic access, Shared Folders, 채널 AI awareness 추가 |
| 05-auth-access-and-administration.md | **수정** | LDAP 그룹 동기화, OAuth toggle, PKCE, Usage 대시보드 추가 |
| 06-open-terminal-and-code-execution.md | **수정** | Ecosystem 분리, Computer, Terminals orchestrator 추가 |
| 07-deployment-integrations-and-operations.md | **수정** | Cloud Storage, Redis 개선, OTEL, orjson, Sovereign AI 추가 |
| 08-tutorial-map.md | **수정** | Ecosystem, Calendar, MCP 관련 튜토리얼 참조 추가 |
| **09-calendar.md** | **신규** | Calendar 기능 전체 가이드 (신규 파일) |
| **10-ecosystem.md** | **신규** | Ecosystem (Terminal, Computer, oikb) 가이드 |
| README.md | **수정** | 가이드 맵에 09, 10번 추가, 버전 정보 업데이트 |

---

## 6. 버전 호환성 및 업그레이드 주의사항

**v0.11.0은 Breaking Changes를 포함합니다.**

**1. UI 전면 재설계**

CSS 오버라이드/정적 파일 교체 방식의 브랜딩 커스터마이징이 깨질 수 있습니다. Phase 7(브랜딩) 작업 시 v0.11.0 기준으로 재작업이 필요합니다.

**2. 보안 수정 다수 포함**

v0.11.0에는 30건 이상의 보안/접근제어 수정이 포함되어 있습니다. 운영 배포에 가능한 빨리 업데이트할 것을 권고합니다.

**3. DB 마이그레이션**

PostgreSQL에서의 채팅 검색이 메시지 테이블 기반으로 변경되었습니다. 기존 v0.10.x에서 업그레이드 시 스테이징에서 먼저 검증해야 합니다.

**4. 플러그인 마이그레이션**

v0.9.0 마이그레이션 가이드(docs.openwebui.com/features/extensibility/plugin/migration/to-0.9.0)를 확인하여 기존 Function/Tool 호환성을 검증해야 합니다.

**5. MCP 서버 연결**

v0.9.6에서 MCP 커스텀 헤더 템플릿 보간이 수정되었습니다. 이전 버전에서는 저장만 되고 실제 보간이 안 되었으므로 주의가 필요합니다.

---

## 7. 권장 다음 단계

1. 가이드 파일 01~08.md를 이 리포트의 변경사항을 반영하여 업데이트
2. 09-calendar.md, 10-ecosystem.md 신규 파일 작성
3. 보완본 V1과 개선안의 수정 사항을 통합한 V2 문서 작성
4. 현재 운영 중인 OpenWebUI 버전 확인 후 v0.11.0 업그레이드 계획 수립
5. v0.11.0 UI 재설계에 대비한 CSS 커스터마이징 재검증 테스트
6. Calendar 기능의 뉴스룸 활용 방안 PoC

*— 끝 —*
