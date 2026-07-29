# 플랜: 로컬 사전 배포 검증 워크플로 (개정 v3)

## Context

현재 릴리스 흐름은 `feature → integration → RC 태그 → GH Actions 빌드 → 스테이징 서버 검증 → PR → main → 최종 태그 → 프로덕션 배포`이다.
사용자는 **최종 태그 빌드 후 프로덕션 SSH 배포 직전**에 로컬 WSL2 환경에서 GHCR 이미지를 pull해 빠르게 검증하는 단계를 추가하고 싶다.

- 로컬: Docker 29.1.3 + Docker Compose 2.40.3 설치 완료 (WSL2 Ubuntu)
- ghcr.io 인증 없음 → 설정 필요 (최초 1회)
- `.env.local-test` 없음 → 템플릿 신규 생성 필요
- 기존 `docker-compose.staging.yaml`은 스테이징 서버 전용이므로 로컬용 별도 파일 필요

### 검토 반영 (v2 개정)
검토 결과 필수 3건 + 권장 4건을 반영. 주요 변경:
- `.gitignore` 예외 규칙 명시
- **로컬 검증은 스테이징 게이트를 대체하지 않고 추가 방어선으로 기능**함을 명시
- 스크립트 성공 조건 강화 (`docker compose ps` + `logs`)
- 태그 형식 정규식 검증
- `ENABLE_OAUTH_PERSISTENT_CONFIG` 유지 결정 및 근거 명시

### 검토 반영 (v3 개정)
2차 검토 결과 3건을 반영해 "빈 DB 검증 목표 달성"과 "immutable 태그 원칙 준수"를 강화:
- **데이터 디렉터리 empty 강제**: 기본은 비어있지 않으면 abort, `--reuse-data` 플래그로만 재사용 허용 (신규 마이그레이션 검증이 false-positive로 통과하는 것을 방지)
- **최종 태그 불변성 규칙 명시**: §3.9-b 도입부에 로컬 검증 실패 시 같은 태그 재빌드 금지 · 다음 kwh 번호로 스테이징부터 재진행 원칙 삽입
- **태그 정규식 엄격화**: 기본은 최종 태그만 허용, `--allow-rc` 플래그로만 RC 태그 허용 (스테이징 게이트 대체 오용 방지)

---

## 검증 범위 및 한계 (신규 섹션)

### 이 도구가 검증하는 것
- 이미지 pull 및 컨테이너 기동 성공 여부
- 신규 설치(빈 DB)의 마이그레이션 무오류
- 브랜드 자산 정합성 (로고, `WEBUI_NAME=Koreatimes` 접미사 없음)
- 최소 UI 기동 (로그인 폼, 기본 UX 커밋 반영 여부)
- 헬스체크 200 응답

### 이 도구가 검증하지 못하는 것 (스테이징 게이트가 담당)
- OAuth 전체 흐름 (Google OIDC 리디렉트, 계정 매칭, 세션 유지)
- 파이프라인 서비스 연결 및 모델 요청 응답
- RAG 문서 업로드/인용 정확성
- **운영 데이터 마이그레이션 호환성** — 빈 DB는 신규 설치 마이그레이션만 검증. 기존 운영 데이터 마이그레이션은 스테이징 복제본 필수

### 결론
로컬 검증은 **최종 태그 배포 직전 이미지 정합성 사전 확인용 추가 방어선**이다.
**기존 RC → 스테이징 검증 → PR → main → 최종 태그 흐름은 어떤 단계도 대체·생략되지 않는다.**
로컬 검증은 §3.9(최종 태그) 완료 후 §3.10(프로덕션 배포) 사이에 삽입되는 옵셔널 추가 단계.

---

## 신규/수정 파일 목록

| 파일 | 작업 |
|---|---|
| `docker-compose.local-test.yaml` | 신규 — 로컬 WSL2 테스트 전용 compose |
| `.env.local-test.template` | 신규 — OAuth 우회 설정 템플릿 (git 추적 대상) |
| `.gitignore` | 수정 — `.env.local-test` ignore + `!.env.local-test.template` 예외 규칙 |
| `scripts/local-test.sh` | 신규 — pull → 기동 → 헬스체크 → 상태/로그 확인 → 결과 보고 |
| `docs/manual/kwh-release-routine.md` | 수정 — §3.9-b 로컬 사전 검증 단계 및 검증 범위/한계 문단 삽입 |

---

## 구현 상세

### 1. `docker-compose.local-test.yaml`

`docker-compose.staging.yaml` 구조를 기반으로 WSL2 로컬용 조정:

```yaml
services:
  openwebui:
    image: ghcr.io/kwh8121/openwebui-service:${OPENWEBUI_LOCAL_TEST_TAG:?Set OPENWEBUI_LOCAL_TEST_TAG (must be v-prefixed, e.g., v0.10.2-kwh.2)}
    env_file:
      - ${OPENWEBUI_LOCAL_TEST_ENV_FILE:-./.env.local-test}
    ports:
      - '127.0.0.1:${OPENWEBUI_LOCAL_TEST_PORT:-8082}:8080'
    volumes:
      - ${OPENWEBUI_LOCAL_TEST_DATA:?Set OPENWEBUI_LOCAL_TEST_DATA (isolated data dir)}:/app/backend/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Asia/Seoul
      - ENABLE_PERSISTENT_CONFIG=true
      - ENABLE_OAUTH_PERSISTENT_CONFIG=true   # staging/prod와 동일 유지 (OAuth off 상태에서 무효 플래그이나 compose 간 diff 최소화 목적)
    extra_hosts:
      - host.docker.internal:host-gateway
    restart: 'no'
    networks:
      - openwebui_local_test_network

networks:
  openwebui_local_test_network:
    driver: bridge
```

**설계 근거:**
- `pipelines` 서비스 제외 — 로컬 검증 목적은 이미지 정합성이며 파이프라인은 스테이징에서 검증
- `restart: 'no'` — 테스트 후 자동 재기동 방지
- 별도 네트워크 — 운영 `shared_bridge_network`와 격리
- 포트 `8082` — 운영(80), 스테이징(8081)과 충돌 없음
- `ENABLE_OAUTH_PERSISTENT_CONFIG=true` **유지** — OAuth 비활성 상태에서 무효 플래그지만 스테이징/운영 compose와 diff 최소화. 향후 환경 간 일관성 유지를 위해 의도적 유지 (주석으로 명시)

### 2. `.env.local-test.template`

```env
# 로컬 테스트 전용 — OAuth 우회, 패스워드 로그인 허용
# 이 파일을 .env.local-test 로 복사 후 사용 (git 비추적)

WEBUI_NAME=Koreatimes

# OAuth 비활성화 + 로컬 로그인 폼 활성화
ENABLE_LOGIN_FORM=true
ENABLE_SIGNUP=true
ENABLE_OAUTH_SIGNUP=false

# 최초 가입 사용자를 admin으로 설정 (빈 DB 기준)
DEFAULT_USER_ROLE=admin
```

### 3. `scripts/local-test.sh`

주요 기능 (순서):

1. **인수 파싱** — `<image-tag>` 필수, 플래그 옵션 `--down`, `--reuse-data`, `--allow-rc`
2. **태그 형식 검증 (v3 엄격화):**
   - 기본 정규식: `^v[0-9]+\.[0-9]+\.[0-9]+-kwh\.[0-9]+$` (최종 태그 전용)
   - `--allow-rc` 지정 시 정규식: `^v[0-9]+\.[0-9]+\.[0-9]+-kwh\.[0-9]+(-rc\.[0-9]+)?$`
   - 최종 정규식 미매치 시 에러: "이 스크립트는 최종 태그(v0.10.2-kwh.N) 검증용. RC 태그는 스테이징 게이트에서 검증. RC를 로컬에서 pull-only 사전 확인용으로 실행하려면 `--allow-rc` 명시"
   - v 접두사 없는 태그는 GHCR에 없음
3. **`--down` 모드** — `<image-tag>` 인수의 값을 Compose 필수 변수에도 전달한 뒤 종료: `OPENWEBUI_LOCAL_TEST_TAG="$tag" docker compose -f docker-compose.local-test.yaml down`. `docker-compose.local-test.yaml`의 image 보간식이 `OPENWEBUI_LOCAL_TEST_TAG`를 `:?`로 요구하므로, `down`에서도 반드시 전달해야 한다. bind mount 데이터 디렉터리는 유지.
4. **전제 조건 확인:**
   - ghcr.io 인증 여부 (`~/.docker/config.json` 확인) → 미인증 시 `docker login ghcr.io -u kwh8121` 안내 후 중단
   - `OPENWEBUI_LOCAL_TEST_DATA` 미지정 시 `$HOME/openwebui-local-test-data` 자동 사용
   - **데이터 디렉터리 상태 검증 (v3 신규):**
     - 디렉터리 없음 → 자동 생성 (신규 검증 진행)
     - 디렉터리 존재 & 비어있음 → 그대로 사용
     - 디렉터리 존재 & 비어있지 않음 & `--reuse-data` 미지정 → **abort**, 다음 안내 출력:
       > "데이터 디렉터리 `<path>`에 기존 파일이 있습니다. 빈 DB 신규 마이그레이션 검증이 목표이므로 기본 동작은 중단입니다. 옵션: (a) 삭제 후 재실행: `rm -rf <path>/*` (b) 기존 상태 위에서 검증(주의): `--reuse-data`"
     - `--reuse-data` 지정 시 → 경고 출력 후 진행: "경고: 기존 데이터 재사용 모드. 신규 마이그레이션 검증은 스킵됩니다."
   - `.env.local-test` 없으면 `.env.local-test.template` 복사 안내 후 중단
5. **이미지 pull** — `docker pull ghcr.io/kwh8121/openwebui-service:<tag>`
6. **컨테이너 기동** — `OPENWEBUI_LOCAL_TEST_TAG=<tag> docker compose -f docker-compose.local-test.yaml up -d`
7. **성공 조건 3중 확인:**
   - `docker compose -f docker-compose.local-test.yaml ps openwebui` 상태 확인 (`running` 확인)
   - `docker compose -f docker-compose.local-test.yaml logs --tail 100 openwebui` 출력 후 시작 오류 스캔 (`Traceback`, `ERROR`, `Failed to start` 키워드)
   - 최대 60초 폴링 (5초 간격) `curl -sf http://127.0.0.1:8082/health` 200 대기
8. **결과 보고:**
   - 3중 확인 모두 통과 시: 접속 URL(`http://127.0.0.1:8082`) 및 수동 체크리스트 안내
   - 실패 시: 로그 위치 및 재시도/디버깅 안내. 최종 태그 검증 실패라면 §3.9-b의 "immutable 태그 규칙"(같은 태그 재빌드 금지) 리마인더 출력
9. **종료 안내** — `./scripts/local-test.sh <tag> --down`

### 4. `.gitignore` 수정

기존 `.env.*` 라인(9) 이후, `!.env.example` 예외 패턴(10) 아래에 다음 순서로 추가:

```
.env.local-test
!.env.local-test.template
```

**주의:** `.env.*`가 이미 `.env.local-test.template`을 매치하므로 반드시 `!` 예외 규칙 명시 필요. `!.env.example`과 동일한 패턴을 따름.

### 5. `docs/manual/kwh-release-routine.md` 수정

§3.9(최종 태그)와 §3.10(프로덕션 배포) 사이에 `§3.9-b 로컬 사전 검증 (선택)` 삽입.

내용:
- 도입 문단: 이 단계는 스테이징 게이트를 **대체하지 않으며**, 최종 태그 배포 직전 이미지 정합성 확인 목적의 **옵셔널 방어선**
- **immutable 태그 실패 처리 규칙 (v3 신규):** 로컬 검증에서 실패 발견 시 최종 태그는 immutable이므로 같은 태그로 재빌드/덮어쓰기 금지. 원인 수정 후 다음 kwh 번호(예: `kwh.N+1`)로 스테이징(§3.5)부터 재진행. 프로덕션 배포는 중단.
- 검증 범위/한계 요약 (본 계획의 "검증 범위 및 한계" 섹션 참조)
- 최초 설정 (1회):
  ```bash
  docker login ghcr.io -u kwh8121   # read:packages 권한 PAT 필요
  cp .env.local-test.template .env.local-test
  ```
- 검증 실행 (기본은 빈 데이터 디렉터리):
  ```bash
  ./scripts/local-test.sh v0.10.2-kwh.N   # 반드시 v 접두사, 최종 태그만
  # → http://127.0.0.1:8082 에서 UI + 브랜드 확인
  ```
- 옵션 플래그:
  - `--reuse-data` : 데이터 디렉터리 재사용 (신규 마이그레이션 검증 스킵됨, 주의)
  - `--allow-rc` : RC 태그도 pull-only 사전 확인용으로 허용 (스테이징 게이트 대체 아님)
- 종료:
  ```bash
  ./scripts/local-test.sh v0.10.2-kwh.N --down
  ```
- **명시적 경고:** 로컬 검증 통과가 곧 배포 준비 완료 판정이 아님. RC → 스테이징 검증이 이미 통과된 최종 태그에 한해 실행

---

## 로컬 수동 검증 체크리스트 (스크립트 자동 확인 항목 이후)

스크립트가 확인하는 항목 (자동):
- [x] 컨테이너 상태 `running`
- [x] logs에 startup 오류 키워드 없음
- [x] `/health` 200 응답

브라우저 수동 확인 항목:
- [ ] 로그인 폼으로 계정 생성 및 로그인 성공
- [ ] 좌상단 로고 = Koreatimes
- [ ] 사이드바 하단 인스턴스명 = `Koreatimes` (접미사 없음)
- [ ] 제안 카드 클릭 → 입력란 채워지고 자동 전송 안 됨 (kwh.2 변경사항)
- [ ] 브라우저 탭 제목 = Koreatimes
- [ ] `/manifest.json` `name`/`short_name` = `Koreatimes`
- [ ] **로딩 스플래시 = Koreatimes (라이트)** — 첫 로드/새로고침 시 잠깐 표시 (`static/static/splash.png`, kwh.3 이후 예정)
- [ ] **로딩 스플래시 다크 모드 = Koreatimes splash-dark** — OS/앱 다크 테마로 전환 후 새로고침 시 표시 (`static/static/splash-dark.png`)

---

## 브랜치 전략 및 재빌드 정책 (개정 명확화)

### 이 도구 도입 자체
- 브랜치: `feature/local-test-workflow` → `integration/v0.10.2` `--no-ff` → PR → `main`
- **이 커밋 자체는 이미지 재빌드 불필요** — compose 파일·템플릿·스크립트·문서만 변경, 이미지 콘텐츠 무변경
- 새 git 태그 불필요

### 향후 릴리스에서의 사용
- 도구 도입 이후 릴리스에서는 **매번 새 최종 태그 이미지를 pull해 검증**
- 예: `v0.10.2-kwh.3` 태그 생성 → GH Actions 빌드 → `./scripts/local-test.sh v0.10.2-kwh.3` → 통과 시 프로덕션 배포
- 도구 자체 변경 없이 태그만 바꿔 재사용

---

## 구현 완료 후 검증 절차

```bash
# 1. compose 파일 문법 확인 (dry-run)
OPENWEBUI_LOCAL_TEST_TAG=v0.10.2-kwh.2 \
OPENWEBUI_LOCAL_TEST_DATA=~/openwebui-local-test-data \
docker compose -f docker-compose.local-test.yaml config

# 2. 스크립트 태그 검증 로직 테스트 (v3 엄격화)
./scripts/local-test.sh invalid-tag             # 실패 예상 (형식)
./scripts/local-test.sh 0.10.2-kwh.2            # 실패 예상 (v 없음)
./scripts/local-test.sh v0.10.2-kwh.2-rc.1      # 실패 예상 (RC 기본 차단)
./scripts/local-test.sh v0.10.2-kwh.2-rc.1 --allow-rc  # 통과 예상 (opt-in)
./scripts/local-test.sh v0.10.2-kwh.2           # 통과 예상 (최종 태그)

# 3. .gitignore 예외 규칙 동작 확인
git check-ignore -v .env.local-test.template   # 무시 안 됨(no output) 기대
git check-ignore -v .env.local-test            # 무시됨 기대

# 4. 데이터 디렉터리 empty 강제 검증 (v3 신규)
mkdir -p ~/openwebui-local-test-data && touch ~/openwebui-local-test-data/dirty
./scripts/local-test.sh v0.10.2-kwh.2                 # abort 예상 (비어있지 않음)
./scripts/local-test.sh v0.10.2-kwh.2 --reuse-data    # 경고 후 진행 예상
rm -rf ~/openwebui-local-test-data/*
./scripts/local-test.sh v0.10.2-kwh.2                 # 통과 예상 (비어있음)

# 5. 실제 pull + 기동 (신규 마이그레이션 검증)
rm -rf ~/openwebui-local-test-data/*
./scripts/local-test.sh v0.10.2-kwh.2

# 6. 수동 브라우저 체크

# 7. 정리
./scripts/local-test.sh v0.10.2-kwh.2 --down
```

---

## 개정 이력

- **v1** (초안): 기본 compose + 템플릿 + 스크립트
- **v2** (검토 반영):
  - 필수 1: `.gitignore` `!.env.local-test.template` 예외 규칙 추가
  - 필수 2: "검증 범위 및 한계" 섹션 신설 및 스테이징 게이트 유지 명시
  - 필수 3: 운영 데이터 마이그레이션 검증 불가 명시
  - 권장 a: 스크립트에 `docker compose ps` + `logs --tail 100` + 오류 키워드 스캔 추가
  - 권장 b: 태그 형식 정규식 검증 및 v 접두사 오류 메시지
  - 권장 c: `ENABLE_OAUTH_PERSISTENT_CONFIG=true` 유지 결정 및 근거 주석
  - 권장 d: "도구 자체 재빌드 불필요"와 "향후 릴리스에서 새 태그로 검증"을 분리 서술
- **v3** (본 문서, 2차 검토 반영):
  - 권장 1: 데이터 디렉터리 empty 강제 (기본 abort + `--reuse-data` opt-in) — 빈 DB 신규 마이그레이션 검증 false-positive 방지
  - 권장 2: §3.9-b 도입부에 immutable 최종 태그 실패 처리 규칙(같은 태그 재빌드 금지, 다음 kwh 번호로 스테이징부터 재진행) 삽입
  - 권장 3: 태그 정규식 엄격화 — 기본은 최종 태그 전용, `--allow-rc` 명시 시에만 RC 태그 허용 (스테이징 게이트 대체 오용 방지)
  - "구현 완료 후 검증 절차"에 태그 엄격 케이스 및 empty-dir abort 검증 케이스 추가
