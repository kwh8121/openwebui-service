# 플랜: 로컬 사전 배포 검증 워크플로 (개정 v4)

## Context

현재 릴리스 흐름의 **스테이징 검증 단계는 운영 서버와 동일 호스트 위에 compose 격리(포트/데이터 dir/network)로만 병렬 기동되는 구조**임이 확인됐다. 물리 격리가 없어 이미지 결함이 자원 경합·커널·네트워크 경로를 통해 프로덕션 컨테이너에 파급될 리스크가 있다. 이를 회피하기 위해 로컬 검증을 **추가 방어선(v3)에서 스테이징 게이트 대체(v4)로 승격**하고, 데이터를 릴리스 간에 축적해 실제 마이그레이션 경로까지 로컬에서 검증한다.

- 로컬: Docker 29.1.3 + Docker Compose 2.40.3 설치 완료 (WSL2 Ubuntu)
- ghcr.io 인증 없음 → 설정 필요 (최초 1회)
- `.env.local-test` 없음 → 프로덕션 미러 템플릿 신규 생성 필요
- 기존 `docker-compose.staging.yaml`은 운영 호스트 병렬 기동용이므로 로컬용 별도 파일 필요 (프로덕션 미러 스코프)

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

### 검토 반영 (v4 개정 — 스테이징 대체 승격)
현행 스테이징이 운영 호스트에 co-located된 논리 격리만 제공한다는 사실을 근거로 도구 성격을 재정의:

- **포지셔닝 승격**: "추가 방어선(v3)" → **"릴리스 게이트로서의 스테이징 대체(v4)"**. `docker-compose.staging.yaml`이 제공하던 검증 스코프를 모두 흡수.
- **env 프로덕션 미러**: `.env.local-test.template`을 프로덕션(`docker-compose.deploy.yaml` + `.env.openwebui.oauth`) 구조와 동일 형태로 재작성. OAuth on, Google OIDC 자격 증명 자리 표시자, 로컬 redirect URI 등록 안내 포함.
- **데이터 보존 기본화**: 데이터 디렉터리 defaults reverse — 기본은 **보존**(프로덕션 upgrade 시뮬레이션), `--fresh` 플래그로만 empty 강제(신규 설치 마이그레이션 검증). 릴리스 간 데이터 축적으로 실제 마이그레이션 경로가 로컬에서 항상 검증됨.
- **자동 백업/롤백**: 이미지 pull 후 컨테이너 up 이전에 WAL-safe SQLite 백업(컨테이너 stop → tar) 자동 수행. `${OPENWEBUI_LOCAL_TEST_DATA}.backups/YYYYMMDD-HHMMSS-<tag>/`. `--restore <timestamp>` 플래그로 즉시 롤백. 기본 유지 개수 5, `--prune-backups` 옵션으로 정리.
- **pipelines 서비스 편입**: `docker-compose.local-test.yaml`에 `pipelines` 서비스 추가 (프로덕션과 동일 이미지 `ghcr.io/open-webui/pipelines:main`, 포트 9099 localhost bind). RAG/pipelines 검증까지 로컬 스코프에 포함.
- **staging compose 폐기 경로 명시**: 향후 `docker-compose.staging.yaml` 사용 중단 예정, deprecation notice를 §4에 기재. 삭제는 별도 세션에서 판단.

---

## 검증 범위 및 한계 (v4 재작성)

### 이 도구가 검증하는 것 (프로덕션 미러 스코프)
- 이미지 pull 및 컨테이너 기동 성공 여부
- **누적 데이터에 대한 마이그레이션 무오류** (기본 모드, 릴리스 간 데이터 보존)
- 신규 설치 마이그레이션 (`--fresh` 모드, 빈 DB 검증)
- **OAuth 전체 흐름** (Google OIDC 리디렉트, 계정 매칭, 세션 유지) — 로컬 redirect URI `http://127.0.0.1:8082/oauth/google/callback` 사전 등록 필요
- **pipelines 서비스 연결 및 모델 요청 응답** — compose에 pipelines 서비스 포함
- **RAG 문서 업로드/인용 정확성**
- 브랜드 자산 정합성 (로고, splash 라이트/다크, `WEBUI_NAME=Koreatimes` 접미사 없음)
- 헬스체크 200 응답

### 이 도구가 검증하지 못하는 것
- **프로덕션 사용자 실사용 부하** (동시 세션 규모, 실제 트래픽 패턴)
- **프로덕션 하드웨어 특성** (GPU 유형, 디스크 IO 특성) — 로컬 WSL2 환경 특성으로 완전 재현 불가
- **네트워크 경로별 이슈** (프로덕션의 리버스 프록시·방화벽·SSL 종단 특성)
- 프로덕션 실제 데이터 (프라이버시/보안상 로컬 반입하지 않음, 로컬 축적 데이터로 대리 검증)

### 결론 (v4)
로컬 검증은 **릴리스 게이트로서의 스테이징 대체**이다.
`docker-compose.staging.yaml`을 사용한 운영 호스트 병렬 기동 검증은 폐기 경로. 프로덕션 배포 전 필수 관문은:

```
feature/* → integration/vX.Y.Z → RC 태그 → GH Actions 빌드 → 로컬 검증(scripts/local-test.sh) → PR → main → 최종 태그 → GH Actions 프로덕션 빌드 → 프로덕션 SSH 배포
```

로컬 검증은 §3.9(최종 태그) 이전에 RC 이미지에 대해 실행되고(스테이징 대체), 최종 태그 빌드 후 프로덕션 배포 직전에 다시 실행된다(배포 직전 재검증).

---

## 신규/수정 파일 목록 (v4 재정리)

| 파일 | 상태 | 작업 |
|---|---|---|
| `docker-compose.local-test.yaml` | v3 존재, v4 수정 | pipelines 서비스 추가, restart 정책 유지 |
| `.env.local-test.template` | v3 존재, v4 재작성 | OAuth 우회 → 프로덕션 미러(OAuth on + Google OIDC 자리 표시자) |
| `.env.local-test.fresh.template` | v4 신규 | v3 스타일(OAuth off, 패스워드 로그인)의 fresh 모드 참조용 템플릿 |
| `.gitignore` | v3 존재, v4 확장 | `!.env.local-test.fresh.template` 예외 규칙 추가 |
| `scripts/local-test.sh` | v3 존재, v4 대폭 수정 | defaults reverse(데이터 보존 기본), 백업/롤백/prune 하위 명령 추가, pipelines 성공 조건 확장 |
| `docs/manual/kwh-release-routine.md` | v3 §3.9-b 존재, v4 재작성 | 도구를 스테이징 대체 게이트로 재기술, §3.6(스테이징 SSH) deprecation notice, §3.9-b를 §3.6-b로 위치 이동 검토 |
| `docs/plan/local-test-workflow.md` | v3 존재, v4 개정 | 본 문서 |

**참고**: `docker-compose.staging.yaml`은 v4에서 유지하되 deprecation notice 추가. 실제 삭제는 별도 세션에서 판단(운영 서버 관행 확인 후).

---

## 구현 상세

### 1. `docker-compose.local-test.yaml` (v4 수정)

`docker-compose.deploy.yaml` 구조를 기반으로 WSL2 로컬용 조정 (프로덕션 미러):

```yaml
services:
  openwebui:
    image: ghcr.io/kwh8121/openwebui-service:${OPENWEBUI_LOCAL_TEST_TAG:?Set OPENWEBUI_LOCAL_TEST_TAG (must be v-prefixed, e.g., v0.10.2-kwh.3-rc.1)}
    env_file:
      - ${OPENWEBUI_LOCAL_TEST_ENV_FILE:-./.env.local-test}
    ports:
      - '127.0.0.1:${OPENWEBUI_LOCAL_TEST_PORT:-8082}:8080'
    volumes:
      - ${OPENWEBUI_LOCAL_TEST_DATA:?Set OPENWEBUI_LOCAL_TEST_DATA (persistent data dir)}:/app/backend/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Asia/Seoul
      - ENABLE_PERSISTENT_CONFIG=true
      - ENABLE_OAUTH_PERSISTENT_CONFIG=true
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    restart: 'no'
    networks:
      - openwebui_local_test_network

  pipelines:
    image: ghcr.io/open-webui/pipelines:main
    ports:
      - '127.0.0.1:${PIPELINES_LOCAL_TEST_PORT:-9099}:9099'
    volumes:
      - ${PIPELINES_LOCAL_TEST_DATA:?Set PIPELINES_LOCAL_TEST_DATA (persistent pipelines dir)}:/app/pipelines
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    restart: 'no'
    networks:
      - openwebui_local_test_network

networks:
  openwebui_local_test_network:
    driver: bridge
```

**v4 설계 근거:**
- **pipelines 서비스 편입** — 프로덕션 compose 미러링, RAG/pipelines 검증까지 스코프 포함
- `restart: 'no'` — 테스트 후 자동 재기동 방지 유지 (프로덕션은 `unless-stopped`, 로컬은 게이트 목적이므로 무한 재기동 불필요)
- 별도 네트워크 `openwebui_local_test_network` — 운영 `shared_bridge_network`와 격리
- 포트 `8082`(openwebui), `9099`(pipelines) — 프로덕션(80, 9099)과 로컬 병존 안전. pipelines는 localhost bind로 외부 노출 차단
- `ENABLE_OAUTH_PERSISTENT_CONFIG=true` — 프로덕션과 동일. v4에서는 OAuth on이 기본이므로 실제 유효 플래그
- 데이터 dir 두 개(openwebui + pipelines) 모두 host bind mount — 릴리스 간 보존

### 2. `.env.local-test.template` (v4 재작성 — 프로덕션 미러)

```env
# 로컬 테스트 전용 — 프로덕션 미러 모드 (OAuth on, Google OIDC)
# 이 파일을 .env.local-test 로 복사 후 실제 자격 증명으로 채워 사용 (git 비추적)

# ─── 브랜드 ────────────────────────────────────────────────────────
WEBUI_NAME=Koreatimes

# ─── 로컬 URL (OAuth redirect 구성용) ────────────────────────────
WEBUI_URL=http://127.0.0.1:8082

# ─── OAuth (Google OIDC) ─────────────────────────────────────────
# 사전 준비: Google Cloud Console → OAuth 클라이언트 → Authorized redirect URIs
# 아래 로컬 콜백 URI를 반드시 추가:
#   http://127.0.0.1:8082/oauth/google/callback
ENABLE_OAUTH_SIGNUP=true
ENABLE_LOGIN_FORM=false            # OAuth 전용, 프로덕션과 동일
GOOGLE_CLIENT_ID=<프로덕션과 동일 or 로컬 전용 클라이언트 ID>
GOOGLE_CLIENT_SECRET=<대응 시크릿>
GOOGLE_OAUTH_SCOPE="openid email profile"
GOOGLE_REDIRECT_URI=http://127.0.0.1:8082/oauth/google/callback

# ─── pipelines 연결 (로컬 compose의 pipelines 서비스와 통신) ─────
# openwebui 컨테이너에서 서비스명으로 접근 가능
OPENAI_API_BASE_URL=http://pipelines:9099
OPENAI_API_KEY=0p3n-w3bu!

# ─── 최초 관리자 (fresh 모드 첫 사용자 자동 admin) ───────────────
DEFAULT_USER_ROLE=admin

# ─── 프로덕션과 동일하게 유지할 추가 변수 (필요 시 프로덕션 env에서 복사) ─
# ENABLE_RAG_WEB_SEARCH=...
# ENABLE_IMAGE_GENERATION=...
# ... 등 프로덕션에서 사용 중인 값을 그대로 반영
```

**보안 주의:**
- 실 `GOOGLE_CLIENT_SECRET`은 절대 커밋 금지. 템플릿은 자리 표시자만.
- 로컬 전용 별도 OAuth 클라이언트를 만들어 프로덕션 시크릿 로컬 반입을 피하는 것이 더 안전 (권장).
- 프로덕션 클라이언트를 재사용해도 redirect URI 화이트리스트 관리가 명확하면 리스크 통제 가능.

### 2-b. `.env.local-test.fresh.template` (v4 신규 — fresh 모드 참조용)

`--fresh` 모드에서 사용할 v3 스타일 템플릿 (신규 설치 마이그레이션 전용):

```env
# 로컬 fresh 모드 — OAuth 우회, 패스워드 로그인 (빈 DB 신규 마이그레이션 검증)
WEBUI_NAME=Koreatimes
ENABLE_LOGIN_FORM=true
ENABLE_SIGNUP=true
ENABLE_OAUTH_SIGNUP=false
DEFAULT_USER_ROLE=admin
```

`--fresh` 실행 시 스크립트가 이 파일을 자동 참조하거나, 사용자가 `OPENWEBUI_LOCAL_TEST_ENV_FILE`로 명시 전달.

### 3. `scripts/local-test.sh` (v4 대폭 수정)

**하위 명령 구조 (v4):**

```
scripts/local-test.sh <tag> [flags]                   # 검증 실행 (기본: 데이터 보존, 프로덕션 미러)
scripts/local-test.sh --down                          # 컨테이너 중지 (데이터 dir 유지)
scripts/local-test.sh --list-backups                  # 백업 히스토리 조회
scripts/local-test.sh --restore <timestamp>           # 백업으로 롤백
scripts/local-test.sh --prune-backups [--keep N]      # 오래된 백업 정리 (기본 N=5)
```

**검증 실행 순서 (v4):**

1. **인수 파싱** — `<image-tag>` 필수 (검증 모드), 플래그: `--fresh`, `--no-backup`, `--allow-rc`, `--restore <ts>`, `--list-backups`, `--prune-backups`, `--keep <N>`, `--down`
2. **태그 형식 검증** — v3와 동일 (기본 최종 태그만, `--allow-rc` 시 RC 허용). "RC 태그는 스테이징 게이트에서 검증" 문구는 v4에서 "RC 태그는 정식 로컬 검증 이전의 pull-only 사전 확인용"으로 재해석
3. **`--down` / `--list-backups` / `--restore` / `--prune-backups` 단축 명령** — 각 하위 명령을 처리 후 종료. `--down`은 태그 인수 불필요하도록 v4에서 개선 (플레이스홀더 태그 자동 주입해 compose 보간 충족)
4. **전제 조건 확인:**
   - ghcr.io 인증 여부 (`~/.docker/config.json`)
   - `OPENWEBUI_LOCAL_TEST_DATA` 미지정 시 `$HOME/openwebui-local-test-data` 자동 사용
   - `PIPELINES_LOCAL_TEST_DATA` 미지정 시 `$HOME/openwebui-local-test-pipelines` 자동 사용 (v4 신규)
   - **`.env.local-test` 존재 여부 검증:**
     - 없음 → template 복사 안내 후 중단
     - 있음 & 기본 모드 → 프로덕션 미러 필수 변수(`GOOGLE_CLIENT_ID`, `GOOGLE_REDIRECT_URI` 등) 존재 확인, 미지정 시 경고 + `--fresh` 사용 권장 안내
5. **데이터 디렉터리 상태 검증 (v4 defaults reverse):**
   - **기본 모드(데이터 보존, 프로덕션 미러 upgrade 시뮬레이션):**
     - openwebui + pipelines 데이터 dir 모두 검사
     - 디렉터리 없음 → 자동 생성 + 안내: "최초 실행입니다. 로컬 스테이징 데이터를 새로 생성합니다."
     - 디렉터리 존재 (비어있든 아니든) → 그대로 사용
   - **`--fresh` 모드 (v3 스타일):**
     - 디렉터리 없음 → 자동 생성
     - 디렉터리 존재 & 비어있음 → 그대로 사용
     - 디렉터리 존재 & 비어있지 않음 → **abort**: "fresh 모드는 빈 DB 대상. 옵션: (a) 삭제 후 재실행 (b) 기본 모드로 재실행"
6. **자동 백업 (v4 신규, 기본 수행, `--no-backup` 시 skip):**
   - 데이터 dir이 비어있지 않은 경우만 실행 (empty면 백업 대상 없음)
   - 순서: `docker compose down` → SQLite WAL 커밋 강제 → `tar -czf <backups>/YYYYMMDD-HHMMSS-<tag>.tar.gz -C <data-dir> .` → 성공 시 크기 리포트
   - 백업 위치: `${OPENWEBUI_LOCAL_TEST_DATA%/}.backups/` (openwebui), `${PIPELINES_LOCAL_TEST_DATA%/}.backups/` (pipelines)
   - 실패 시 abort + "데이터 손실 방지를 위해 검증 중단. 원인 확인 후 재시도 또는 `--no-backup` 명시(주의)"
7. **이미지 pull** — openwebui + pipelines 두 이미지 모두
8. **컨테이너 기동** — `docker compose up -d` (두 서비스 동시)
9. **성공 조건 4중 확인 (v4 확장):**
   - openwebui state = `running`
   - pipelines state = `running`
   - openwebui logs `--tail 100` 오류 키워드 스캔 (`Traceback`, `ERROR`, `Failed to start`)
   - `/health` 60초 폴링
   - (선택) pipelines 응답 확인: `curl -sf http://127.0.0.1:9099/`
10. **결과 보고:**
    - 통과: 접속 URL + 수동 체크리스트 안내 (OAuth 로그인 포함)
    - 실패: **롤백 안내 출력** —
      > "검증 실패. 아래 명령으로 백업 이전 상태로 롤백 가능:
      >   `./scripts/local-test.sh --list-backups`
      >   `./scripts/local-test.sh --restore <timestamp>`"
    - 최종 태그 실패 시 immutable 태그 규칙 리마인더 (같은 태그 재빌드 금지, 다음 kwh 번호로 재진행)

**`--restore <timestamp>` 동작:**
1. `docker compose down`
2. 현재 데이터 dir 이동: `mv <data-dir> <data-dir>.rolled-back-<now>` (안전용, 나중 수동 삭제 가능)
3. `mkdir <data-dir>` + `tar -xzf <backups>/<ts>.tar.gz -C <data-dir>` (openwebui + pipelines 모두)
4. 재실행 안내 출력

**`--list-backups` 출력 형식:**
```
백업 (${OPENWEBUI_LOCAL_TEST_DATA%/}.backups/):
  20260729-152230-v0.10.2-kwh.3-rc.1   45.2 MB
  20260810-091500-v0.10.2-kwh.4-rc.1   47.8 MB
  ...
백업 (${PIPELINES_LOCAL_TEST_DATA%/}.backups/):
  20260729-152230-v0.10.2-kwh.3-rc.1    2.1 MB
  ...
```

**`--prune-backups`:** 최신 `--keep N` (default 5)개 유지, 나머지 삭제 전 목록 출력 및 대화형 확인 (`--yes` 없으면).

### 4. `.gitignore` 수정 (v4 확장)

기존 `.env.*` 라인 이후, `!.env.example` 예외 패턴 아래에 다음 순서로 추가 (v3 규칙 유지 + v4 신규):

```
!.env.local-test.template
!.env.local-test.fresh.template
```

**주의:** `.env.*`가 이미 두 template 파일을 매치하므로 반드시 `!` 예외 규칙 명시 필요. 실제 사용 파일 `.env.local-test`(자격 증명 포함)는 무시 유지 → **절대 커밋 금지**.

### 5. `docs/manual/kwh-release-routine.md` 수정 (v4 재작성)

**§3.6 (기존 스테이징 SSH 배포) 처리:** deprecation notice 추가 —
> "**Deprecated (v4):** 이 절차는 프로덕션과 동일 호스트 위 compose 격리에 의존하는 검증으로, 물리 격리가 없어 리스크를 프로덕션에 노출합니다. §3.6-b(로컬 프로덕션 미러 검증)로 대체됐습니다. 예외적 사유(로컬 환경 이슈 등)로 사용할 때만 실행하고, 그 사유를 릴리스 노트에 기록하세요."

**§3.6-b (신규, v4)**: `로컬 프로덕션 미러 검증 (기본 릴리스 게이트)` — §3.5(RC 태그) 후 §3.7(PR) 이전에 삽입.

내용:
- 도입 문단: 이 단계는 **스테이징을 대체하는 릴리스 게이트**. `docker-compose.local-test.yaml` + `scripts/local-test.sh`가 프로덕션 compose를 미러링(pipelines 포함, OAuth on). 로컬 데이터는 릴리스 간 축적되어 실제 upgrade 마이그레이션이 매번 검증됨.
- **immutable 태그 실패 처리 규칙 (v3 유지):** 검증 실패 시 같은 태그 재빌드 금지. 다음 kwh 번호로 새 RC 발행 후 재검증.
- 검증 범위/한계 요약 (본 계획의 "검증 범위 및 한계" 섹션 참조)
- 최초 설정 (1회):
  ```bash
  docker login ghcr.io -u kwh8121                                        # PAT: read:packages
  cp .env.local-test.template .env.local-test
  # .env.local-test 편집: GOOGLE_CLIENT_ID/SECRET 등 실제 값 채움
  # Google Cloud Console → 로컬 redirect URI 추가:
  #   http://127.0.0.1:8082/oauth/google/callback
  ```
- RC 검증 실행 (기본 = 데이터 보존):
  ```bash
  ./scripts/local-test.sh v0.10.2-kwh.N-rc.M --allow-rc
  # → http://127.0.0.1:8082 에서 프로덕션 미러 체크리스트
  ```
- 최종 태그 재검증 (§3.9 후, 프로덕션 배포 직전):
  ```bash
  ./scripts/local-test.sh v0.10.2-kwh.N
  # → 최종 태그 이미지에 대해 동일 검증 반복
  ```
- 옵션 플래그:
  - `--fresh` : 데이터 dir 비우고 신규 설치 마이그레이션 검증 (upgrade 흐름과 별도로 필요 시)
  - `--no-backup` : 자동 백업 skip (주의, 데이터 손실 리스크)
  - `--allow-rc` : RC 태그 허용 (RC 로컬 검증 시 필수)
- 백업/롤백:
  ```bash
  ./scripts/local-test.sh --list-backups
  ./scripts/local-test.sh --restore <timestamp>
  ./scripts/local-test.sh --prune-backups --keep 5
  ```
- 종료:
  ```bash
  ./scripts/local-test.sh --down
  ```
- **명시적 경고:** 통과가 곧 프로덕션 무결점 보장은 아님. 실사용 부하·프로덕션 하드웨어 특성·리버스 프록시 이슈 등은 검증 범위 밖. 프로덕션 배포 후 §6 스모크 및 모니터링 필수.

---

## 로컬 수동 검증 체크리스트 (v4 프로덕션 미러 스코프)

스크립트가 확인하는 항목 (자동, v4 4중 확인):
- [x] openwebui 컨테이너 상태 `running`
- [x] pipelines 컨테이너 상태 `running` (v4 신규)
- [x] logs에 startup 오류 키워드 없음
- [x] `/health` 200 응답

브라우저 수동 확인 항목:

**인증 (v4 신규 — 프로덕션 미러)**
- [ ] Google OAuth 버튼 클릭 → Google 리디렉트 성공
- [ ] Google 계정 선택 후 로컬로 redirect back 성공 (`http://127.0.0.1:8082/oauth/google/callback`)
- [ ] 세션이 새로고침 후에도 유지됨
- [ ] fresh 모드(`--fresh`) 경우: 로그인 폼으로 계정 생성 및 로그인 성공

**브랜드**
- [ ] 좌상단 로고 = Koreatimes
- [ ] 사이드바 하단 인스턴스명 = `Koreatimes` (접미사 없음)
- [ ] 브라우저 탭 제목 = Koreatimes
- [ ] `/manifest.json` `name`/`short_name` = `Koreatimes`
- [ ] **로딩 스플래시 = Koreatimes (라이트)** — 첫 로드/새로고침 시 표시 (`static/static/splash.png`)
- [ ] **로딩 스플래시 다크 모드 = Koreatimes splash-dark** — 다크 테마 전환 후 새로고침 시 표시 (`static/static/splash-dark.png`)

**UX**
- [ ] 제안 카드 클릭 → 입력란 채워지고 자동 전송 안 됨 (kwh.2 변경사항)

**기능 스모크 (v4 신규 — 프로덕션 미러)**
- [ ] 모델 요청: 메시지 전송 → 응답 수신 (OPENAI_API_BASE_URL=http://pipelines:9099 경유)
- [ ] pipelines 서비스가 워크스페이스 UI에 리스팅되고 연결 가능
- [ ] RAG: 문서 업로드 → 질의 → 인용(citation) 표시
- [ ] 이전 릴리스에서 축적한 채팅/설정/문서가 로그인 후 그대로 조회됨 (**upgrade 무결성**)

**한계 (검증 대상 아님)**
- 프로덕션 실제 트래픽 부하
- 프로덕션 GPU/디스크/네트워크 특성
- 프로덕션 리버스 프록시/SSL 종단 이슈

---

## 브랜치 전략 및 재빌드 정책 (v4 갱신)

### v4 도구 개선 도입
- 브랜치: `feature/local-test-workflow-v4` → `integration/v0.10.2` `--no-ff` → PR → `main`
- **이 커밋 자체는 이미지 재빌드 불필요** — compose 파일·템플릿·스크립트·문서만 변경, 이미지 콘텐츠 무변경
- 새 git 태그 불필요

### 향후 릴리스에서의 사용 (v4 워크플로)
1. **RC 태그 생성** (`v0.10.2-kwh.N-rc.M`) → GH Actions RC 이미지 빌드
2. **로컬 검증 실행** (`./scripts/local-test.sh v0.10.2-kwh.N-rc.M --allow-rc`) — RC로 프로덕션 미러 검증. 자동 백업 후 이전 릴리스의 데이터 위에서 마이그레이션 확인.
3. **통과 시 PR** `integration/v0.10.2` → `main`
4. **최종 태그 생성** (`v0.10.2-kwh.N`) → GH Actions 프로덕션 빌드
5. **최종 태그 재검증** (`./scripts/local-test.sh v0.10.2-kwh.N`) — 프로덕션 배포 직전 재확인 (2단계 게이트)
6. **프로덕션 SSH 배포**

**데이터 축적 흐름:**
- 최초 릴리스: `--fresh` 또는 첫 실행에서 빈 dir 자동 초기화 → 실제 사용 시나리오로 데이터 populate
- 이후 릴리스: 매번 축적 데이터 위에서 검증 → 실제 마이그레이션 경로 반복 확인
- 실패 시: `--restore <timestamp>`로 이전 상태 복구, 원인 수정, 재시도

---

## 구현 완료 후 검증 절차 (v4)

```bash
# 1. compose 파일 문법 확인 (dry-run) — openwebui + pipelines 서비스
OPENWEBUI_LOCAL_TEST_TAG=v0.10.2-kwh.3-rc.1 \
OPENWEBUI_LOCAL_TEST_DATA=~/openwebui-local-test-data \
PIPELINES_LOCAL_TEST_DATA=~/openwebui-local-test-pipelines \
OPENWEBUI_LOCAL_TEST_ENV_FILE=./.env.local-test.template \
docker compose -f docker-compose.local-test.yaml config | grep -E 'image:|ports:|volumes:' | head -20

# 2. 스크립트 태그 검증 로직 (v3에서 유지)
./scripts/local-test.sh invalid-tag                    # 실패 예상 (형식)
./scripts/local-test.sh v0.10.2-kwh.3-rc.1             # 실패 예상 (RC 기본 차단)
./scripts/local-test.sh v0.10.2-kwh.3-rc.1 --allow-rc  # 통과 예상 (opt-in)

# 3. .gitignore 예외 규칙 (v4: 두 template 모두)
git check-ignore -v .env.local-test.template         # 무시 안 됨 기대
git check-ignore -v .env.local-test.fresh.template   # 무시 안 됨 기대
git check-ignore -v .env.local-test                  # 무시됨 기대

# 4. 데이터 디렉터리 defaults reverse 검증 (v4 신규)
mkdir -p ~/openwebui-local-test-data && touch ~/openwebui-local-test-data/dirty
./scripts/local-test.sh v0.10.2-kwh.3-rc.1 --allow-rc         # 통과 예상 (기본 = 보존)
./scripts/local-test.sh v0.10.2-kwh.3-rc.1 --allow-rc --fresh # abort 예상 (fresh + dirty dir)
rm -rf ~/openwebui-local-test-data/*
./scripts/local-test.sh v0.10.2-kwh.3-rc.1 --allow-rc --fresh # 통과 예상 (fresh + empty)

# 5. 자동 백업 검증 (v4 신규)
# (첫 실행 후) 이후 재실행 시 backup 디렉터리 확인
./scripts/local-test.sh --list-backups
ls ~/openwebui-local-test-data.backups/

# 6. 롤백 검증 (v4 신규)
./scripts/local-test.sh --list-backups           # 백업 타임스탬프 확인
./scripts/local-test.sh --restore <timestamp>    # 롤백
# 후 재실행하여 이전 상태 복원 여부 확인

# 7. 실제 프로덕션 미러 검증 (수동)
docker login ghcr.io -u kwh8121                                    # 최초 1회
cp .env.local-test.template .env.local-test                        # 자격 증명 채워야 함
# .env.local-test 편집 — GOOGLE_CLIENT_ID/SECRET 등 실제 값 삽입
# Google Cloud Console → OAuth 클라이언트 → redirect URI 추가:
#   http://127.0.0.1:8082/oauth/google/callback
./scripts/local-test.sh v0.10.2-kwh.3-rc.1 --allow-rc              # 실제 실행

# 8. 브라우저 프로덕션 미러 체크리스트 실행
#    - OAuth 로그인
#    - 브랜드/splash
#    - RAG/pipelines/모델 응답
#    - 이전 축적 데이터 조회

# 9. 정리
./scripts/local-test.sh --down
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
- **v3** (2차 검토 반영):
  - 권장 1: 데이터 디렉터리 empty 강제 (기본 abort + `--reuse-data` opt-in) — 빈 DB 신규 마이그레이션 검증 false-positive 방지
  - 권장 2: §3.9-b 도입부에 immutable 최종 태그 실패 처리 규칙(같은 태그 재빌드 금지, 다음 kwh 번호로 스테이징부터 재진행) 삽입
  - 권장 3: 태그 정규식 엄격화 — 기본은 최종 태그 전용, `--allow-rc` 명시 시에만 RC 태그 허용 (스테이징 게이트 대체 오용 방지)
  - "구현 완료 후 검증 절차"에 태그 엄격 케이스 및 empty-dir abort 검증 케이스 추가
- **v4** (스테이징 대체 승격):
  - 발견: 기존 스테이징(`docker-compose.staging.yaml`)은 프로덕션과 동일 호스트에 compose 레벨 격리만 되어 물리 격리 없음 → 검증 리스크가 실질적으로 프로덕션에 노출됨
  - 포지셔닝: "추가 방어선(v3)" → **"릴리스 게이트로서의 스테이징 대체(v4)"**
  - env: `.env.local-test.template`을 프로덕션 미러(OAuth on, Google OIDC, pipelines URL)로 재작성. 별도 fresh 모드용 `.env.local-test.fresh.template` 신규
  - compose: `pipelines` 서비스 편입 (프로덕션과 동일 이미지, 로컬 9099 bind)
  - 스크립트 defaults reverse: 기본은 데이터 보존(프로덕션 upgrade 시뮬레이션), `--fresh`로 empty 강제
  - 백업/롤백: 자동 WAL-safe 백업 (컨테이너 stop → tar), `--restore`/`--list-backups`/`--prune-backups` 하위 명령 추가
  - 검증 스코프: OAuth 전체 흐름·pipelines·RAG·upgrade 마이그레이션 모두 로컬 커버
  - 워크플로: RC로 로컬 검증 → PR → 최종 태그 → 로컬 재검증 → 프로덕션 배포 (2단계 게이트)
  - `docker-compose.staging.yaml`은 유지하되 deprecation notice 예정
- **v4.1** (본 문서, 첫 실행 지연 해소):
  - 발견: fork의 GHCR 이미지는 non-slim(`USE_SLIM=false`)이라 embedding/whisper/tiktoken 모델이 이미지의 `/app/backend/data/cache/*`에 baked-in되지만, `docker-compose.local-test.yaml`이 빈 host 디렉터리를 `/app/backend/data`에 bind mount하여 baked-in cache를 완전히 가림 → 컨테이너 첫 실행 시 HuggingFace에서 ~250 MB 재다운로드 발생
  - 스크립트 추가: 이미지 pull 직후, compose up 이전에 **cache seed** 단계 삽입. 첫 실행(또는 `--reseed-cache` 지정) 시 `docker create` + `docker cp`로 이미지의 `/app/backend/data/cache`를 host bind mount에 복사
  - 신규 플래그: `--reseed-cache` (다음 릴리스 이미지에 새 baked-in 모델이 추가된 경우 강제 재복사)
  - fallback: 이미지가 USE_SLIM=true로 빌드되어 cache가 없으면 경고 후 진행 (기존 runtime 다운로드 동작 유지)
  - 재빌드 불필요 — script-only 변경. compose·env·이미지 무변경
