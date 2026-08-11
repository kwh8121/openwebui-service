# Open WebUI: 확장과 통합

## 확장 방식 선택

| 요구                                      | 권장 방식        | 적용 예                           |
| ----------------------------------------- | ---------------- | --------------------------------- |
| 모델이 비밀정보를 보지 않고 서버 API 호출 | Tool             | CMS 초안 생성, 기사 DB 조회       |
| 새로운 모델 공급자를 모델 선택기에 추가   | Pipe Function    | 사내 추론 서버, 특수 번역 모델    |
| 입력/출력 메시지를 일괄 변환 또는 검사    | Filter Function  | 개인정보 가림, 출처 형식 강제     |
| 특정 메시지의 사용자 클릭 작업            | Action Function  | CMS로 내보내기, 검수 패킷 생성    |
| 기존 외부 HTTP 서비스 연결                | OpenAPI 또는 MCP | DAM, 번역 메모리, 팩트체크 서비스 |

Tools와 Functions는 Open WebUI 프로세스 안에서 임의의 Python을 실행한다. API 키는 Tool 내부 서버 측에 두고 모델/사용자에게 노출하지 않는 용도에 적합하다. GPU, 대용량 의존성, 독립 확장, 강한 격리가 필요한 작업은 외부 OpenAPI 또는 MCP 서비스로 분리한다.

## 편집국 통합 후보

- CMS Tool: 기사 초안을 `draft` 상태로 생성하고, 공개·예약 발행 API는 호출하지 않는다. 실행자, 원고 ID, 모델, 프롬프트 버전을 감사 로그에 남긴다.
- 아카이브 검색 Tool: 기사 ID, 제목, 날짜, 섹션, 정정 이력을 반환한다. 원문 전문은 필요한 권한이 있는 사용자에게만 제공한다.
- 팩트체크 Tool: 주장, 근거 URL, 검증 날짜, 판정 상태를 구조화해 반환한다. 모델 판정을 사실의 최종 판정으로 취급하지 않는다.
- 인물·용어 Tool: 사내 표기와 직함, 고유명사 변경 이력을 조회해 일관된 기사 표기를 돕는다.
- 출력 Filter: 비공개 제보 식별자, 이메일, 전화번호 등 민감 패턴을 탐지해 차단 또는 가림 처리한다. 정규식만으로 완전한 개인정보 보호를 보장할 수 없으므로 별도 DLP와 사람 검토가 필요하다.

## MCP와 OpenAPI

네이티브 MCP는 Streamable HTTP 전송을 지원한다. stdio 또는 SSE 기반 MCP 서버는 `mcpo` 변환 프록시를 사용한다. OpenAPI/MCP 서버에는 읽기 전용과 쓰기 권한을 분리하고, 사용자 또는 역할별 노출을 제한한다. 외부 서비스 호출은 시간 제한, 재시도, 감사 이벤트, 승인 단계를 설계한다.

## Community 반입 원칙

Community의 인기/Featured 표시는 보안·품질 심사가 아니다. 가져오기 전 소스 전체, 네트워크 호출 주소, 환경변수·비밀 처리, 파일/쉘 접근, 라이선스를 검토한다. 운영 인스턴스에는 검증된 내부 포크 또는 승인 레지스트리를 사용한다.

## Pipelines 상태

별도 워커 프레임워크인 Pipelines는 레거시이며 Functions와 Tools가 이를 대체한다. 신규 기능은 특별한 호환 요구가 없으면 Tools/Functions 또는 외부 MCP/OpenAPI로 구현한다.

## 관련 공식 문서

- <https://docs.openwebui.com/features/extensibility/>
- <https://docs.openwebui.com/features/extensibility/plugin/>
- <https://docs.openwebui.com/features/extensibility/mcp>
- <https://docs.openwebui.com/features/extensibility/community>
