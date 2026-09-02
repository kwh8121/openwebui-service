# Production Deployment Guide — `v0.11.3-kwh.1`

이 가이드는 프로덕션 배포 에이전트가 실행하는 유일한 명령 소스다. 정상 상태에서는
`Deploy approved production release` workflow(`.github/workflows/deploy-approved-production-release.yaml`)가
§4~§6을 자동 수행하며, 이 문서는 그 입력값·기대 결과·수동 fallback(interim mode) 절차를 규정한다.

읽는 순서: §1 → §2 → §3 → §4 → §5 → §6 → §7. §3에서 실제 상태가 이 문서의 전제와
다르면 §4 이전에 중단하고 에스컬레이션한다.

---

## 1. Release identifiers

| 항목                            | 값                                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Version                         | **v0.11.3-kwh.1**                                                                                     |
| Main tip SHA (40자)             | `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`                                                            |
| GHCR image tag (배포 대상)      | `ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1`                                                     |
| OCI index digest                | `sha256:5a08d0a9a7a3ea22134e84f8a5d9b950654103aa3f60bcdcb60f72a1d5c403b3`                             |
| linux/amd64 digest              | `sha256:20445c5a562910c7900c8f6b2e15645e7f1a90fc3754b026e2ebdaad55966bb6`                             |
| GHCR short-SHA parity tag       | `ghcr.io/kwh8121/openwebui-service:git-af4f111`                                                       |
| GH Actions build Run            | https://github.com/kwh8121/openwebui-service/actions/runs/33588400126                                 |
| Base upstream                   | Open WebUI `v0.11.3` (v0.11.2 건너뜀 — §2 참조)                                                       |
| Fork carryovers                 | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `insertSuggestionPrompt=true` 기본, local-test 도구 |
| Rollback target (현재 프로덕션) | `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.2`                                                     |

> **`latest`·`main`·RC 태그를 배포하지 않는다.** immutable 최종 태그 또는 git-SHA parity
> 태그만 유효한 배포 대상이다. compose 파일은 `OPENWEBUI_IMAGE_TAG` 없이 기동을 거부한다(의도된 동작).

parity 태그가 동일 digest로 해석됨은 로컬에서 확인 완료(§3 재확인 대상).

---

## 2. Deployment overview

**변경 내용:** `v0.11.1-kwh.2` → `v0.11.3-kwh.1`. upstream `v0.11.2` + `v0.11.3` 두 릴리스를
한 번에 흡수한다 (185 files, +6866/-4501).

주요 변경:

- **`internal/db.py` (+40)** — SQLite `LIKE` 연산자를 Python UDF로 교체 등록
  (`create_function('like', 2/3, ..., deterministic=True)`). 14개 model 파일의 모든
  `LIKE`/`ILIKE` 경로에 영향. **검색 정확도·지연 회귀의 1순위 감시 대상** (§7.5).
- **`utils/middleware.py` (+163/-…)** — 필터 파이프라인 재구성. pipelines 연동 경로 포함.
- **`routers/pipelines.py` (+6)** — pipelines 라우터 변경.
- **`models/users.py` (+6/-…)** — OAuth `sub` 조회 시 SQLite 정수 오버플로 가드.
  upstream `17cc5667`이 fork의 `v0.11.1-kwh.2` 핫픽스를 대체하며, `str(sub_int) == sub`
  검사를 추가해 **엄격히 더 강하다**. (Stage 2 verifier PASS 판정.)
- `routers/images.py` (+47), `socket/main.py`, `utils/ask_user.py`, `models/calendar.py` 등
  다수 기능 개선. 상세는 `docs/plan/v0.11.3-integration.md` §3.

### 실행될 Alembic 마이그레이션: **0건 (완전 no-op)**

프로덕션은 `v0.11.1-kwh.1` 배포 이후 이미 revision **`d4c1a8e37b62`**이며, 이는 v0.11.3의
head와 동일하다. `v0.11.1-kwh.2 → v0.11.3-kwh.1` 사이에 추가·삭제·변경된 마이그레이션
파일이 **없음**을 git으로 확인했다:

```
git diff --name-status v0.11.1-kwh.2 v0.11.3-kwh.1 -- backend/open_webui/migrations/versions/
→ (출력 없음)
```

따라서 기동 시 alembic 로그는 다음 2줄만 남고 `Running upgrade` 라인은 **나오지 않는 것이 정상**이다:

```
INFO  [alembic.runtime.migration] Context impl SQLiteImpl.
INFO  [alembic.runtime.migration] Will assume non-transactional DDL.
```

> **upstream #29280 관련**: v0.11.3은 마이그레이션 실패를 삼키지 않고 `raise`한다.
> 프로덕션은 `ENABLE_DB_MIGRATIONS`를 설정하지 않아 기본값 `True`로 마이그레이션 경로에
> 진입하지만, 실행할 마이그레이션이 0건이므로 `raise`가 도달할 실패 지점이 없다.
> 로컬 게이트는 오히려 더 긴 경로(`f0bd01a18a3d` → `d4c1a8e37b62`, 3건 실행)를 예외 없이
> 통과시켜 이 경로의 안전성을 실증했다.

**Fork carryovers (재적용 불필요, 병합 트리에 보존 확인됨):**

- `backend/open_webui/env.py`: `WEBUI_NAME`에 `' (Open WebUI)'` 접미사 강제 없음.
- `Chat.svelte` / `Settings/InterfaceSettings.svelte`: `insertSuggestionPrompt ?? true`
  (제안 카드 클릭 → 입력란만 채움, 자동 전송 안 함).
- 정적 자산(`static/static/*`, `backend/open_webui/static/*`): Koreatimes favicon / logo /
  splash(라이트·다크) / manifest.

**변경하지 않는 것:** pipelines 이미지(`ghcr.io/open-webui/pipelines:main`), pipelines 포트,
`.env.openwebui.oauth` 구조.

**배포 전략:** `openwebui` 서비스만 rolling replace (`--no-deps`). `pipelines` 컨테이너는 유지.

---

## 3. Prerequisites verification (§4 이전에 수행)

workflow의 `Validate tag format` / `Validate release evidence and deploy guide` /
`Validate deploy environment` 스텝이 자동 수행한다. interim mode에서는 아래를 수동 실행한다.

### 3.1 경로와 파일

```bash
cd /home/ubuntu/openwebui
test -f docker-compose.deploy.yaml || { echo "MISSING compose file"; exit 1; }
test -f .env.openwebui.oauth      || { echo "MISSING env file"; exit 1; }
test -d openwebui                 || { echo "MISSING data dir"; exit 1; }
test -f openwebui/webui.db        || { echo "MISSING sqlite DB"; exit 1; }
ls -la openwebui/webui.db openwebui/webui.db-wal openwebui/webui.db-shm 2>&1
```

### 3.2 Compose project name

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui ps
```

기대: `openwebui-openwebui-1` (running healthy), `openwebui-pipelines-1` (running).
prefix가 다르면 project name이 `openwebui`가 아니므로 중단.

### 3.3 현재 실행 이미지 (rollback anchor)

```bash
CURRENT_IMAGE=$(docker inspect $(docker compose -f docker-compose.deploy.yaml -p openwebui ps -q openwebui) --format '{{.Config.Image}}')
echo "Currently running: $CURRENT_IMAGE"
```

기대: `ghcr.io/kwh8121/openwebui-service:v0.11.1-kwh.2`.
다르면 실제 값을 기록 — 그 값이 rollback target이 된다.

### 3.4 GHCR 인증과 이미지 존재 + parity

```bash
docker pull ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1
NEW_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1)
echo "New image digest: $NEW_DIGEST"

docker pull ghcr.io/kwh8121/openwebui-service:git-af4f111
PARITY_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/kwh8121/openwebui-service:git-af4f111)
[[ "$NEW_DIGEST" == "$PARITY_DIGEST" ]] && echo "digest match OK" || { echo "DIGEST MISMATCH — halt"; exit 1; }
```

기대: `NEW_DIGEST` =
`ghcr.io/kwh8121/openwebui-service@sha256:5a08d0a9a7a3ea22134e84f8a5d9b950654103aa3f60bcdcb60f72a1d5c403b3`.
불일치 시 중단.

### 3.5 환경 파일 sanity

```bash
grep -E '^(WEBUI_NAME|ENABLE_OAUTH_SIGNUP|ENABLE_LOGIN_FORM|ENABLE_OAUTH_PERSISTENT_CONFIG|GOOGLE_CLIENT_ID|ENABLE_DB_MIGRATIONS|ENABLE_IMAGE_GENERATION)=' \
  .env.openwebui.oauth
```

2026-09-02 확인된 기대 상태:

- `WEBUI_NAME=Koreatimes`
- `ENABLE_OAUTH_SIGNUP=true`
- `ENABLE_OAUTH_PERSISTENT_CONFIG=true`
- `GOOGLE_CLIENT_ID=...` (존재)
- `ENABLE_LOGIN_FORM` **미설정** — 백엔드 기본 `True`. 단 PersistentConfig이므로 DB 값이 우선(§7.1).
- `ENABLE_DB_MIGRATIONS` **미설정** — 기본 `True`. §2의 no-op 판단은 이 전제 위에 성립한다.
- `ENABLE_IMAGE_GENERATION` **미설정** — PersistentConfig이며 로컬 게이트에서 실효값 `false` 확인.

`WEBUI_NAME`이 없거나 `Koreatimes`가 아니면 §4 이전에 수정한다.

### 3.6 Pipelines 기동 확인 — **이번 릴리스 필수**

이번 배포는 `check_pipelines=true`로 dispatch한다(§5). workflow는
`http://localhost:9099/openapi.json`이 200을 반환해야 통과시킨다.

```bash
curl -sf --max-time 5 http://localhost:9099/openapi.json >/dev/null && echo "pipelines OK" || echo "PIPELINES DOWN — dispatch 전에 기동 필요"
```

pipelines가 중지된 상태로 dispatch하면 배포가 실패로 판정된다. **dispatch 이전에 기동시킨다.**

### 3.7 디스크 공간 (백업 + 신규 이미지 모두 필요)

```bash
df -h /home/ubuntu
du -sh /home/ubuntu/openwebui/openwebui
```

백업 tar 크기 ≈ 데이터 디렉터리 크기. 이미지는 약 5~6 GB. 여유가 부족하면 중단.

---

## 4. Pre-deployment backup — **MANDATORY**

workflow의 `Stop openwebui and back up data` 스텝이 자동 수행한다.
interim mode 수동 절차:

```bash
export TS=$(date +%Y%m%d-%H%M%S)
export OPENWEBUI_IMAGE_TAG=v0.11.1-kwh.2   # stop 단계에서는 현재 태그 유지
export OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
export OPENWEBUI_DEPLOY_ENV_FILE=/home/ubuntu/openwebui/.env.openwebui.oauth
export PIPELINES_LOCAL_DATA=/app/pipelines

# openwebui만 중지 (pipelines는 계속 실행)
docker compose -f docker-compose.deploy.yaml -p openwebui stop openwebui

# WAL-safe tar (SQLite가 정지돼 WAL이 안전하게 롤업된 상태)
tar -czf ~/prod-backup-preupgrade-${TS}-v0.11.1-kwh.2.tar.gz \
  -C /home/ubuntu/openwebui openwebui

# 무결성 검증 + 크기 기록
ls -lh ~/prod-backup-preupgrade-${TS}-v0.11.1-kwh.2.tar.gz
tar -tzf ~/prod-backup-preupgrade-${TS}-v0.11.1-kwh.2.tar.gz | head -5
tar -tzf ~/prod-backup-preupgrade-${TS}-v0.11.1-kwh.2.tar.gz | wc -l
```

**백업 경로를 기록한다** — §8.2 롤백에 정확히 필요하다.

> 이번 릴리스는 스키마 변경이 없어(§2) 이론상 백업 없이도 이미지 롤백만으로 복구 가능하지만,
> 백업은 정책상 **무조건 수행**한다. 이전 백업을 재사용하지 않는다.

---

## 5. Deployment execution

### 5.1 Workflow dispatch (정상 경로)

GitHub workflow `Deploy approved production release`를 다음 입력으로 dispatch:

| 입력              | 값                                                   |
| ----------------- | ---------------------------------------------------- |
| `tag`             | `v0.11.3-kwh.1`                                      |
| `issue_number`    | 이 릴리스의 Production deployment request Issue 번호 |
| `guide_commit`    | 이 가이드를 담은 `main` 커밋의 전체 SHA              |
| `check_pipelines` | **`true`**                                           |

> **`check_pipelines=true`가 필수인 이유**: 이 릴리스는 `routers/pipelines.py`와
> `utils/middleware.py`를 변경한다. `v0.11.1-kwh.2`가 `false`였던 것은 `users.py`-only
> 핫픽스라 리스크 프로파일이 달랐기 때문이며, 이번에 승계하면 안 된다.
> 사전 조건은 §3.6.

`production` Environment 보호 규칙에 따라 관리자 승인 이후에만 실행된다.

### 5.2 Interim mode 수동 절차

```bash
export OPENWEBUI_IMAGE_TAG=v0.11.3-kwh.1
export OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
export OPENWEBUI_DEPLOY_ENV_FILE=/home/ubuntu/openwebui/.env.openwebui.oauth
export PIPELINES_LOCAL_DATA=/app/pipelines

# 해석된 compose 확인 (부작용 없음)
docker compose -f docker-compose.deploy.yaml -p openwebui config \
  | grep -E 'image:|source:|env_file:' | head -20

docker compose -f docker-compose.deploy.yaml -p openwebui pull openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui ps
```

`--no-deps` 없이 `up`을 실행하지 않는다 — pipelines가 불필요하게 재생성된다.

---

## 6. Migration monitoring

```bash
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 200 -f openwebui
```

### 정상 기대 로그

1. `Generating new WEBUI_SECRET_KEY` 라인이 **나오면 안 된다**. 나오면 bind mount가
   깨졌거나 잘못된 경로를 가리킨다 → 중단하고 §8 롤백.
2. alembic은 다음 2줄만 출력한다:
   ```
   INFO  [alembic.runtime.migration] Context impl SQLiteImpl.
   INFO  [alembic.runtime.migration] Will assume non-transactional DDL.
   ```
   **`Running upgrade` 라인이 나오지 않는 것이 정상이다** (§2, 신규 마이그레이션 0건).
   만약 `Running upgrade`가 나온다면 프로덕션 DB revision이 `d4c1a8e37b62`가 아니었다는
   뜻이므로, 이 가이드의 전제가 깨진 것이다 → 즉시 중단하고 에스컬레이션.
3. `Uvicorn running on http://0.0.0.0:8080`.
4. `Traceback`, `Failed to start`, `sqlalchemy.exc` **0건**.

### /health 폴링

workflow는 `HEALTH_TIMEOUT_SECONDS=300`(5분), 폴링 간격 5초로 대기한다.

```bash
curl -sf http://localhost/health && echo "health OK"
```

> **기동 시간 참고**: 로컬 게이트(7 GB RAM, 축적 데이터)에서는 PyTorch 로딩 중 디스크
> I/O 병목으로 `/health` 200까지 **520초**가 걸렸다. 이는 로컬 머신의 메모리 부족에서
> 기인한 것이며 이미지 결함이 아니다(마이그레이션 no-op, Traceback 0건, digest 일치 확인).
> 프로덕션 호스트에서 300초를 초과한다면 이미지 문제로 단정하지 말고, 먼저
> `docker inspect --format '{{.State.Health}}'`와 `free -m`으로 자원 상태를 확인한 뒤
> §8 판단을 내린다.

300초 내 200이 오지 않고 로그에 예외도 없으면 → 자원 병목 가능성을 먼저 조사한다.
로그에 예외가 있으면 → §8 롤백.

---

## 7. Post-deployment smoke checklist

**반드시 새 시크릿 창 또는 하드 리프레시**(Ctrl+Shift+R, DevTools → Application → Clear site
data)로 수행한다. 정적 자산과 PWA가 공격적으로 캐시된다.

### 7.1 Authentication

프로덕션 `.env.openwebui.oauth`는 `ENABLE_LOGIN_FORM`을 설정하지 않는다. 백엔드 기본은
`True`지만 `ENABLE_OAUTH_PERSISTENT_CONFIG=true`이므로 DB에 저장된 값이 우선한다.
**실제 로그인 화면에서 확인**한다.

- [ ] 랜딩 페이지에 이메일/비밀번호 폼과 "Sign in with Google" 버튼이 기대대로 표시
- [ ] **기존 Google 계정 OAuth 로그인 성공** — `Python int too large to convert to SQLite INTEGER` 재발 없음
      (upstream `17cc5667` 로직 검증. 21자리 `sub` 케이스)
- [ ] 로그인 후 새로고침 → 세션 유지, 재로그인 요구 없음
- [ ] 로그아웃 정상 동작

### 7.2 Data integrity

스키마 변경이 없으므로 데이터 손실 위험은 낮지만 반드시 확인한다.

- [ ] 배포 전 채팅 이력이 그대로 조회·열람 가능
- [ ] 사용자 설정(테마, 인터페이스 환경설정) 보존
- [ ] Workspace → Knowledge의 업로드 파일·지식베이스 목록 유지
- [ ] alembic revision이 여전히 `d4c1a8e37b62`
- [ ] SQLite `PRAGMA integrity_check` = `ok`

### 7.3 Fork carryovers

- [ ] 좌상단 사이드바 로고 = Koreatimes
- [ ] 브라우저 탭 제목 = `Koreatimes`
- [ ] 인스턴스명 = `Koreatimes`, `(Open WebUI)` 접미사 **없음**
- [ ] 로딩 스플래시(라이트) = Koreatimes splash
- [ ] 로딩 스플래시(다크) = Koreatimes splash-dark (OS/앱 테마 다크 전환 후 reload)
- [ ] `/manifest.json`의 `name`·`short_name` = `Koreatimes`
- [ ] 제안 카드 클릭 → 입력란이 채워지고 **자동 전송되지 않음**

### 7.4 Functional smoke

- [ ] 기본 모델에 메시지 전송 → 응답 수신
- [ ] **Workspace → Pipelines에 pipelines 컨테이너(9099) 연결 상태 표시**
      (`middleware.py` +163 회귀 확인 — 이번 릴리스 핵심 감시 대상)
- [ ] pipelines 경유 모델로 대화 1건 성공
- [ ] 소형 텍스트 문서 업로드 후 질의 → 인용 포함 응답 (RAG)

### 7.5 v0.11.3 version-specific spot check

- [ ] **검색 정확도 (SQLite LIKE UDF, `internal/db.py` +40)** — 채팅 검색에서 한글·영문
      키워드 결과가 정확한가
- [ ] **검색 지연** — 워크스페이스/knowledge 검색, 파일 검색의 체감 지연이 배포 전과
      차이 없는가. **유의미한 지연 발생 시 기록하고 에스컬레이션** (§8 롤백 트리거 후보)
- [ ] 추론 모델 스트리밍이 첫 단어 후 멈추지 않고 완료 (upstream #29053)
- [ ] 툴 사용 후 reasoning이 Thoughts에 접힘 (#29052)
- [ ] 채팅 브랜치 reload 후 연결 유지 (#29299)
- [ ] 설정 화면에 "Accessibility Mode" 항목 표기 (동작 변경 없음)

---

## 8. Rollback procedure

**트리거 조건:**

- §6 로그에 `Traceback` / `sqlalchemy.exc` / `Failed to start` 발생
- §6에서 `Running upgrade` 라인 출현 (이 가이드의 전제 위반 — 즉시 중단)
- `/health`가 자원 병목으로 설명되지 않는 이유로 계속 비정상
- §7.1이 전 사용자 로그인을 막는 회귀를 보임
- §7.2 데이터 무결성 실패
- §7.5 검색 지연이 운영에 지장을 줄 수준

> workflow는 컨테이너 기동 **이전** 실패에만 이전 서비스를 자동 복구한다
> (`Restore previous service after pre-start failure`). 기동 이후 실패는
> **자동 롤백하지 않고** 컨테이너·로그·DB·백업을 보존한 채 관리자 판단을 기다린다.

### 8.1 이미지 롤백 (데이터 유지) — **이번 릴리스의 기본 복구 경로**

이번 릴리스는 **스키마 변경이 0건**이므로 이미지만 되돌리면 완전 복구된다.
`v0.11.1-kwh.2`는 동일한 revision `d4c1a8e37b62`에서 정상 동작한다.

```bash
export OPENWEBUI_IMAGE_TAG=v0.11.1-kwh.2
export OPENWEBUI_LOCAL_DATA=/home/ubuntu/openwebui/openwebui
export OPENWEBUI_DEPLOY_ENV_FILE=/home/ubuntu/openwebui/.env.openwebui.oauth
export PIPELINES_LOCAL_DATA=/app/pipelines

docker compose -f docker-compose.deploy.yaml -p openwebui pull openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 50 openwebui
curl -sf http://localhost/health && echo OK
```

### 8.2 Full 롤백 (이미지 + 백업 복원)

§8.1로 복구되지 않을 때만 사용한다.

```bash
export OPENWEBUI_IMAGE_TAG=v0.11.1-kwh.2

docker compose -f docker-compose.deploy.yaml -p openwebui stop openwebui

# 현재 데이터를 포렌식용으로 이동
mv /home/ubuntu/openwebui/openwebui \
   /home/ubuntu/openwebui/openwebui.failed-upgrade-$(date +%Y%m%d-%H%M%S)

# 배포 전 백업 복원
mkdir /home/ubuntu/openwebui/openwebui
tar -xzf ~/prod-backup-preupgrade-<TS>-v0.11.1-kwh.2.tar.gz \
  -C /home/ubuntu/openwebui openwebui

test -f /home/ubuntu/openwebui/openwebui/webui.db || { echo "restore failed"; exit 1; }

docker compose -f docker-compose.deploy.yaml -p openwebui up -d --no-deps openwebui
docker compose -f docker-compose.deploy.yaml -p openwebui logs --tail 50 openwebui
curl -sf http://localhost/health && echo OK
```

롤백 성공 후:

- **동일 태그를 재빌드·덮어쓰지 않는다.** immutable 원칙이 적용된다.
- 수정 경로: 로컬 재현 → 패치 → `v0.11.3-kwh.2` 발행 → RC 및 최종 태그 로컬 게이트
  재검증 → 배포 재요청.

### 8.3 Failed-upgrade 디렉터리 보존

`openwebui.failed-upgrade-*`를 최소 7일 보존한다. 근본 원인 문서화 후 삭제한다.

---

## 9. Success markers to record

배포 성공 시 프로덕션 에이전트가 Issue 코멘트에 기록할 값:

| 필드                 | 기록할 값                                                                 |
| -------------------- | ------------------------------------------------------------------------- |
| Deploy start / end   | UTC 타임스탬프 (health OK 시각)                                           |
| Old image digest     | §3.3 배포 전 컨테이너의 digest                                            |
| New image digest     | `sha256:5a08d0a9a7a3ea22134e84f8a5d9b950654103aa3f60bcdcb60f72a1d5c403b3` |
| Backup path + size   | `~/prod-backup-preupgrade-<TS>-v0.11.1-kwh.2.tar.gz` + `du -h`            |
| Alembic 결과         | `Running upgrade` **0건** (예상대로), revision `d4c1a8e37b62` 유지        |
| `/health`            | HTTP 200, 도달까지 소요 시간                                              |
| `/_app/version.json` | `af4f111d140a2ae9ccd02643f5bbc45ea3742e11`                                |
| `/manifest.json`     | `name` = `short_name` = `Koreatimes`                                      |
| Pipelines            | `check_pipelines=true` → **PASS** 여야 함                                 |
| 로그인 화면 상태     | OAuth-only / OAuth+password (§7.1)                                        |
| 전체 스모크 결과     | §7 하위 절별 pass / fail                                                  |

---

## Appendix A. Environment variable reference

`docker-compose.deploy.yaml` 보간 변수 (모든 compose 호출에서 export 필요):

| 변수                        | 이번 배포 값                                    | 용도                                    |
| --------------------------- | ----------------------------------------------- | --------------------------------------- |
| `OPENWEBUI_IMAGE_TAG`       | `v0.11.3-kwh.1` (배포) / `v0.11.1-kwh.2` (롤백) | 이미지 태그, `:?` 가드로 미설정 시 실패 |
| `OPENWEBUI_LOCAL_DATA`      | `/home/ubuntu/openwebui/openwebui`              | openwebui 데이터 bind mount             |
| `OPENWEBUI_DEPLOY_ENV_FILE` | `/home/ubuntu/openwebui/.env.openwebui.oauth`   | env_file 경로                           |
| `PIPELINES_LOCAL_DATA`      | `/app/pipelines`                                | pipelines 데이터 bind mount             |

compose 호출은 항상 `-p openwebui`를 사용한다.

`.env.openwebui.oauth`에서 이번 릴리스와 관련된 항목:

| 변수                             | 프로덕션 상태 | 영향                                                              |
| -------------------------------- | ------------- | ----------------------------------------------------------------- |
| `WEBUI_NAME`                     | `Koreatimes`  | §7.3 브랜드 확인 기준                                             |
| `ENABLE_OAUTH_SIGNUP`            | `true`        | §7.1                                                              |
| `ENABLE_OAUTH_PERSISTENT_CONFIG` | `true`        | DB 저장 config가 env를 override — §7.1 실화면 확인 필요           |
| `ENABLE_LOGIN_FORM`              | 미설정        | 기본 `True`, 단 PersistentConfig 우선                             |
| `ENABLE_DB_MIGRATIONS`           | 미설정        | 기본 `True` → 마이그레이션 경로 진입 (실행 대상 0건, §2)          |
| `ENABLE_IMAGE_GENERATION`        | 미설정        | PersistentConfig, 로컬 게이트 실효값 `false` → 이미지 스모크 생략 |

## Appendix B. External references (충돌 시 권위 순서)

1. `docs/manual/github-control-plane-local-agent-handoff.ko.md` (Protocol v1.2) — **최상위 권위**.
   릴리스·배포 협업에 관한 모든 충돌에서 이 문서가 이긴다.
2. `docs/manual/github-actions-ghcr-release-deployment.md` — CI/CD 메커니즘 권위
   (태그 규칙, GHCR 관례, 이미지 빌드 정책).
3. `docs/manual/kwh-release-routine.md` — 실무 릴리스 루틴.
4. 이 가이드 — 릴리스별 오버레이.

이 가이드의 명령이 (1)~(3)과 충돌하면 (1)~(3)이 이긴다. 중단하고 재확인한다.

관련 문서:

- `docs/plan/v0.11.3-integration.md` — 이번 통합의 계획·검증 기록 (§8.1 RC 게이트, §8.2 최종 태그 게이트)
- `docs/plan/local-test-workflow.md` — 로컬 프로덕션 미러 게이트 절차
