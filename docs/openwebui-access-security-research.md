# Open WebUI: 인증, 권한, 보안

## 인증과 프로비저닝

로컬 계정 외에 OIDC/SSO, LDAP, SCIM 2.0을 지원한다. 조직 환경에서는 IdP를 인증의 기준 시스템으로 두고 SSO를 먼저 구성한 뒤 SCIM으로 사용자·그룹 입퇴사를 동기화하는 구성이 적합하다. SSO 전용이라면 `ENABLE_PASSWORD_AUTH=false`로 로컬 비밀번호 인증을 끌 수 있다.

## RBAC 모델

기본 역할은 Admin, User, Pending이다. Admin은 전체 시스템 접근 권한을 가지며 Pending은 승인 전까지 접근하지 못한다. 권한은 역할 기본값과 모든 그룹 멤버십의 합집합으로 계산되는 가산(additive) 방식이다. 한 그룹에서 권한을 제거한다고 다른 그룹 또는 역할이 준 권한은 제거되지 않는다.

모델, Knowledge Base, Tools, Skills는 리소스별 접근 제어를 제공한다. 기본적으로 Private이며 Public, 사용자 단위, 그룹 단위 읽기/쓰기 권한을 선택할 수 있다.

## 편집국 그룹 설계 예시

| 그룹 | 허용 리소스 | 금지 또는 제한 |
| --- | --- | --- |
| Reporters | 일반 모델, 공개 KB, 원고 초안 Tool | 기밀 KB, CMS 발행, 플러그인 관리 |
| Editors | Stylebook, 기사 아카이브, 검수 모델 | 관리자 설정, 비밀 Tool 설정 |
| Investigations | 별도 기밀 KB와 제한 채널 | 공개 채널, 외부 웹 전송 도구 |
| Research Desk | 조사 KB, 팩트체크 Tool | 원고 발행, 취재원 식별 KB |
| AI Platform Admins | 설정, 모델·도구 등록 | 일상 취재 작업, 불필요한 채팅 열람 |

권한은 가산 방식이므로 민감 집단에는 "차단 그룹"을 추가하는 대신, 별도 최소 권한 그룹과 전용 리소스로 설계한다.

## API 키와 관리자 보호

API 키는 만든 사용자의 권한을 상속한다. 자동화용 키는 개인 관리자 키를 재사용하지 말고, 필요한 모델·KB·API 경로만 가진 서비스 계정을 만든다. 키를 비밀 저장소에 보관하고 만료·교체·폐기 절차를 둔다.

관리자 채팅 접근과 내보내기가 필요하지 않은 경우 `ENABLE_ADMIN_CHAT_ACCESS=false`, `ENABLE_ADMIN_EXPORT=false`, `BYPASS_ADMIN_ACCESS_CONTROL=false`를 검토한다. 실제 설정값과 버전 호환성은 배포 전 공식 환경변수 참조에서 확인한다.

## 필수 보안 통제

1. HTTPS와 신뢰할 수 있는 역방향 프록시를 사용하고, 인터넷 공개보다 사내 VPN/제로트러스트 접근을 우선한다.
2. 프로덕션은 PostgreSQL, 객체 저장소, 백업·복구 훈련, 감사 로그 보존을 계획한다.
3. 문서, 채팅, 로그, 외부 모델 전송의 보존 기간과 데이터 분류 정책을 명시한다.
4. 플러그인과 Tools는 임의 코드 실행 경로이므로 관리자만 설치·수정하게 한다.
5. 외부 SaaS 모델로 보내는 원고·제보·개인정보의 범위를 계약, 법무, 개인정보 정책에 맞게 제한한다.

## 관련 공식 문서

- <https://docs.openwebui.com/features/authentication-access/>
- <https://docs.openwebui.com/features/authentication-access/rbac/>
- <https://docs.openwebui.com/features/authentication-access/api-keys>
- <https://docs.openwebui.com/security/>
- <https://docs.openwebui.com/reference/https/>
