# Open WebUI: 관리, 평가, API, 배포

## 관리자 기능

Admin Panel은 메시지 수, 토큰 소비, 모델별 사용량, 사용자 활동을 기간·그룹별로 분석한다. 모델 평가는 일반 대화의 좋아요/싫어요와 블라인드 Arena 비교를 사용하며, ELO 리더보드와 평가된 대화 스냅샷을 제공한다. 배너는 공지·점검·장애 알림에, 웹훅은 신규 가입·장기 실행 대화 완료·외부 시스템의 채널 메시지 전달에 쓴다.

## 편집 품질 평가 운영

1. 기자와 데스크가 검수한 실제 업무를 비식별화해 대표 평가 세트를 만든다.
2. 정확성, 출처 충실도, 인용 보존, 스타일 준수, 수정 시간, 환각 심각도를 별도 점수로 정의한다.
3. 모델 Arena 결과는 선택 근거 중 하나로 쓰되, 과제·언어·모델 파라미터·프롬프트가 다른 점을 기록한다.
4. 프롬프트, KB, Tool 변경은 기준 세트 재평가 후 승격한다.
5. 발행 후 정정 사례를 평가 세트에 반영해 반복 오류를 추적한다.

## API와 자동화

REST API는 Bearer 토큰/JWT를 사용하며 OpenAI 호환 채팅 완료(`POST /api/chat/completions`), Anthropic 호환 메시지, Ollama 프록시, 파일과 지식베이스 관리 경로를 제공한다. API 키는 사용자 권한을 상속하므로 자동화 계정과 리소스 권한을 분리한다.

자동화 예시는 매일 새벽 뉴스 브리프를 생성해 뉴스룸 채널로 전송하고, 결과물의 출처·실행 모델·프롬프트 버전을 함께 보관하는 방식이다. 자동화 결과는 기사 초안이며 직접 게시하면 안 된다.

## 배포와 관측성

Docker/Compose, Kubernetes/Helm, pip 설치를 지원한다. 파일은 로컬, S3, GCS, Azure Blob에 저장할 수 있고, DB는 SQLite 또는 PostgreSQL을 선택한다. 수평 확장은 Redis 기반 세션과 다중 워커·노드 구성을 사용한다. OpenTelemetry로 trace, metric, log를 OTLP 호환 관측 시스템에 전송할 수 있다.

프로덕션 체크리스트:

- 백업은 DB, 업로드 파일/객체 저장소, 벡터 데이터, 환경 설정을 함께 포함하고 정기 복구 시험을 한다.
- 모델 API 장애, KB 처리 지연, 저장소 용량, 인증 실패, Tool 오류에 대한 알림을 둔다.
- 개발용 `:dev` 태그 대신 검증한 버전을 고정하고 변경 전 스테이징 환경에서 KB·권한·플러그인을 검증한다.
- 라이선스와 브랜드 요건은 저장소의 최신 `LICENSE`와 `LICENSE_HISTORY`를 법무 검토 대상으로 둔다.

## 관련 공식 문서

- <https://docs.openwebui.com/features/administration/>
- <https://docs.openwebui.com/reference/api-endpoints>
- <https://docs.openwebui.com/reference/env-configuration>
- <https://docs.openwebui.com/reference/monitoring/>
- <https://docs.openwebui.com/tutorials/maintenance/backups>
