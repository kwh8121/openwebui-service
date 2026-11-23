# Open WebUI v0.13.4 업스트림 변경 참고

기준: [공식 v0.13.4 릴리스](https://github.com/open-webui/open-webui/releases/tag/v0.13.4) (`0666e59d26a4d056e0bacee41742486badd71cf8`, 2026-11-17). 이 문서는 upstream 변경과 알려진 위험만 기록한다. fork의 통합·배포 판정은 별도 증적을 따른다.

## 업그레이드에 영향을 주는 변경

- Tether를 통해 사용자 자신의 모델·도구 서버·터미널을 연결한다. Direct Connections와 Direct Integrations 설정 및 관련 권한·환경 변수가 제거됐다. 기존 개인 연결은 Tether에서 다시 구성해야 한다.
- Terminals 서버 연결에는 0.4.0 이상이 필요하다. 기존 0.3.x 구성은 수동 마이그레이션 대상이며, 저장된 모델·폴더·자동화·채팅의 터미널 선택도 다시 확인해야 한다. Open Terminal/Tether의 터미널 연결에는 이 요구가 적용되지 않는다.
- 첫 기동 시 이미지 생성·편집 설정이 image connection으로 전환된다. 이후 `ENABLE_PERSISTENT_CONFIG`가 켜져 있으면 기존 이미지 관련 환경 변수를 읽지 않는다. 이미지 기능을 사용하는 설치에서는 전환 전 백업과 연결·권한 검수가 필요하다.
- 표준·slim Docker 이미지의 Python 의존성이 해시가 고정된 `backend/requirements.lock` 및 `requirements-slim.lock`으로 설치된다. `requirements.txt`를 수정하는 파생 이미지는 잠금 파일도 갱신해야 한다.
- 코딩 에이전트 모델 ID 형식이 바뀐다. 이전 ID를 가리키는 고정 모델·기본 모델·자동화는 다시 선택해야 한다. 이전 버전의 에이전트 채팅은 첫 후속 메시지에서 새 세션으로 시작한다.
- 채팅, 탭, 사이드 채팅, 큐에 넣은 메시지와 Visualizations 기능이 확장됐다. 소켓 이벤트 이름, `share_mode`/`write_access` API 응답 및 터미널 업로드 기본 동작도 달라져 외부 클라이언트와 터미널 연동을 확인해야 한다.
- `v0.13.3` 대비 새 Alembic 마이그레이션 파일은 없다. 그러나 이미지 설정의 앱 수준 전환은 데이터에 영향을 주므로 업그레이드 전 백업이 필요하다.

## 알려진 upstream 위험

- [터미널 프록시의 대형 채팅 성능 문제 #34646](https://github.com/open-webui/open-webui/issues/34646)는 2026-11-23 기준 열려 있다. 보고자는 PostgreSQL, 대형 도구 출력과 터미널 패널을 함께 사용할 때 매 요청이 전체 채팅·메시지를 읽어 DB 연결 풀이 고갈되고 다른 요청도 실패한다고 재현했다. 해당 조합을 사용하는 설치에서는 별도 검증이 필요하다. 이 보고를 모든 데이터베이스·채팅 크기에 일반화하지 않는다.

## 검증 초점

1. 기존 데이터에서 첫 기동 및 이미지 연결 전환, `alembic current == heads`, 백업·복구 가능성.
2. OAuth, 일반 채팅, 파일 업로드·RAG, 기존 Pipe와 도구 연결, 탭·사이드 채팅·큐 메시지.
3. Terminals/Tether를 사용하는 환경의 연결 버전·권한·업로드와 대형 채팅 성능.
4. Koreatimes 브랜드, 추천 프롬프트 기본값, 빌드 채널 등 fork carryover.
