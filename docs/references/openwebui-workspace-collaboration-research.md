# Open WebUI: 워크스페이스와 협업

## 워크스페이스 구성요소

Workspace는 모델 프리셋, 프롬프트, Knowledge, Skills를 관리한다. 모델 프리셋은 기본 모델에 시스템 지침, 파라미터, 도구, 지식베이스를 묶어 특정 업무용 에이전트를 만든다. 동적 변수로 사용자명과 현재 날짜 등을 주입할 수 있고, 사용자·그룹별 접근 제한도 가능하다.

## 편집국 모델 프리셋 예시

- `News Briefing`: 승인된 웹 검색과 조사 KB를 사용한다. 사실, 불확실성, 출처, 추가 확인 항목을 분리해 출력한다.
- `Copy Editor`: 사내 Stylebook만 사용한다. 원고를 재작성하기 전에 오류 목록과 수정 근거를 먼저 제시한다.
- `Headline Desk`: 제목, 부제, SEO 설명, 소셜 문구를 생성하되 확인되지 않은 표현과 선정성을 금지한다.
- `Translation Desk`: 용어집 KB와 번역 지침을 사용한다. 직역/의역 판단과 고유명사 검증 목록을 함께 출력한다.
- `Data Reporter`: 데이터 사전 KB와 승인된 분석 도구만 연결한다. 계산식, 데이터 기간, 결측 처리와 재현 절차를 반드시 보고한다.

## Notes, Channels, Calendar, Automations

- Notes: 리치 텍스트/Markdown 원고를 작성하고, 선택 문장을 AI로 개선하며, 채팅에 전체 문맥으로 첨부한다. 기사 초안과 편집 메모의 작업 공간으로 적합하다.
- Channels: 사람과 모델이 실시간으로 함께 대화하는 공유 공간이다. `@모델`로 초안과 비평을 요청하고 스레드, 반응, 고정, 공개/비공개/그룹/DM 접근 제어를 사용한다.
- Calendar와 Automations: 반복 프롬프트를 일정 실행하고 결과 대화로 연결한다. 아침 뉴스 브리프, 주간 경쟁사 모니터, 정정 기사 점검 등에 활용할 수 있다.

## 협업 운영 규칙

1. 채널을 Desk, Story, Restricted 세 층으로 분리하고 공개 범위를 최소화한다.
2. 원고 확정과 발행 승인 상태는 채널 반응에만 의존하지 말고 CMS의 워크플로우를 기준 시스템으로 둔다.
3. 전용 모델은 일반 채팅과 분리하고, 소유자와 프롬프트 버전을 기록한다.
4. 공용 프롬프트와 Skills는 코드 리뷰에 준해 검토한다. 모델 지침도 데이터 유출이나 편향된 출력을 유발할 수 있다.

## 관련 공식 문서

- <https://docs.openwebui.com/features/workspace/models>
- <https://docs.openwebui.com/features/workspace/prompts>
- <https://docs.openwebui.com/features/notes/>
- <https://docs.openwebui.com/features/channels/>
- <https://docs.openwebui.com/features/calendar/>
