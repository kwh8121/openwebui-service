# kwh 릴리스 루틴 — 프로덕션 운영 가이드

> **범위**: 이 fork의 일상 릴리스 루틴을 세션 간에 참조하기 위한 실무 문서. 2026-07-22 `main` 직접 커밋 사고와 `v0.10.2-kwh.2`(Koreatimes 브랜드) 롤아웃 이후 정착된 워크플로를 명문화했습니다.
>
> **권위 순서**: 충돌 시 ① `docs/manual/github-control-plane-local-agent-handoff.ko.md`(Protocol v1.2, 릴리스·배포 협업 규약의 **최상위 권위**) → ② `docs/manual/github-actions-ghcr-release-deployment.md`(CI/CD 메커니즘) → ③ 본 문서(실무 절차) 순으로 우선합니다. 상위 문서와 어긋나면 본 문서를 고쳐 맞춥니다.

## 1. 저장소 및 리모트 구성

| 항목                    | 값                                                                    |
| ----------------------- | --------------------------------------------------------------------- |
| 로컬 작업 디렉터리      | `~/projects/openwebui-service`                                        |
| `origin` (push 대상)    | `https://github.com/kwh8121/openwebui-service.git`                    |
| `upstream` (fetch 전용) | `https://github.com/open-webui/open-webui.git` (push URL: `DISABLED`) |
| 컨테이너 레지스트리     | `ghcr.io/kwh8121/openwebui-service`                                   |
| 협업 규약 (최상위)      | `docs/manual/github-control-plane-local-agent-handoff.ko.md`          |
| CI/CD 권위 문서         | `docs/manual/github-actions-ghcr-release-deployment.md`               |
| 세션·작업 로그          | `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (날짜별, 같은 날은 append)   |

## 2. 브랜치 및 태그 규약

### 브랜치

| 패턴                 | 목적                                    | 규칙                                                                                                                 |
| -------------------- | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `main`               | 배포 진실 소스                          | **직접 커밋 금지.** `integration/*`에서 PR로만 반영.                                                                 |
| `integration/vX.Y.Z` | 특정 upstream 버전용 커스텀 변경 집합소 | feature 병합은 `--no-ff`. upstream 버전당 하나로 장기 유지.                                                          |
| `feature/<slug>`     | 논리적 커스터마이징 단위 하나           | 현재 `integration/*`에서 분기. `--no-ff`로 `integration/*`에 병합. **문서 변경도 예외 없이 동일 경로** (2026-07-31). |

feature 브랜치는 추적성을 위해 병합 후에도 `origin`에 남깁니다. 다음 릴리스 사이클이 안정적임이 확인된 뒤에만 삭제합니다.

### 태그

| 패턴                | 예시                 | 의미                                                                       |
| ------------------- | -------------------- | -------------------------------------------------------------------------- |
| `vX.Y.Z-kwh.N`      | `v0.11.1-kwh.2`      | 최종 릴리스. `main`의 병합 커밋에서 발행. 프로덕션 이미지 빌드 트리거.     |
| `vX.Y.Z-kwh.N-rc.M` | `v0.11.1-kwh.2-rc.1` | 릴리스 후보. `integration/vX.Y.Z` tip에서 발행. 검증용 이미지 빌드 트리거. |

워크플로(`.github/workflows/docker.yaml`)는 태그 패턴 `v*-kwh.*`에 반응합니다.

### GHCR 이미지 태그 형식 (2026-07-22 검증)

`docker.yaml`의 `docker/metadata-action@v5`가 생성하는 것:

- `type=ref,event=tag` — **git 태그를 `v` 접두사 포함해 그대로 보존**
- `type=sha,prefix=git-` — **7자리 short SHA** (예: `git-42681f0`), 40자 전체 SHA 아님

**올바른** 배포 변수:

```bash
export OPENWEBUI_IMAGE_TAG=v0.11.1-kwh.2       # 'v' 접두사 필수
```

접두사 없는 `0.11.1-kwh.2`나 40자 전체 SHA는 **GHCR에 존재하지 않으며** `docker pull`이 실패합니다.

## 3. 전체 루틴 (커스텀 변경 1건 기준)

### 3.1 작업 시작

```bash
cd ~/projects/openwebui-service
git fetch origin
git checkout integration/vX.Y.Z
git pull --ff-only
git checkout -b feature/<slug>
```

### 3.2 변경 커밋

작고 초점이 분명한 커밋으로 나눕니다. 자산 교체 단계와 코드 단계가 함께 있으면, 리뷰 가능성을 위해 feature 브랜치 안에서 별도 커밋으로 유지합니다.

### 3.3 integration에 병합

```bash
git checkout integration/vX.Y.Z
git merge --no-ff feature/<slug> \
  -m "merge: feature/<slug> into integration/vX.Y.Z"
```

### 3.4 push

```bash
git push -u origin feature/<slug>
git push origin integration/vX.Y.Z
```

### 3.5 RC 태그 발행 → 검증용 이미지 빌드

다음 RC 번호 확인:

```bash
git fetch --tags
git tag -l 'vX.Y.Z-kwh.*' | sort -V
```

발행 및 push:

```bash
git tag -a vX.Y.Z-kwh.N-rc.M <integration-tip-sha> -m "vX.Y.Z-kwh.N-rc.M ..."
git push origin vX.Y.Z-kwh.N-rc.M
```

모니터링:

```bash
gh run list --repo kwh8121/openwebui-service --workflow=docker.yaml --limit 3
gh run watch <run-id> --repo kwh8121/openwebui-service --interval 45 --exit-status
```

결과 이미지: `ghcr.io/kwh8121/openwebui-service:vX.Y.Z-kwh.N-rc.M`

### 3.6 스테이징 SSH 배포 — **폐기됨 (v4)**

> **폐기 사유**: 이 절차는 RC 이미지를 프로덕션 호스트 위에 compose 수준 격리(포트·데이터 디렉터리·네트워크 분리)만으로 기동합니다. 물리 격리가 없어 이미지 결함이 자원 경합이나 커널·네트워크 경로를 통해 같은 호스트의 프로덕션 컨테이너에 파급될 수 있습니다.
>
> **§3.6-b(로컬 프로덕션 미러 검증)로 대체됐습니다.** 로컬 환경 장애 등 예외 상황에서만 사용하고, 사용했다면 그 사유를 릴리스 노트와 관련 Issue에 기록합니다. 명령은 `docker-compose.staging.yaml`과 `OPENWEBUI_STAGING_*` 변수를 참조하십시오.

### 3.6-b 로컬 프로덕션 미러 검증 (v4 기본 릴리스 게이트)

**§3.6을 대체합니다.** RC 이미지를 프로덕션을 미러링한 격리 compose(openwebui + pipelines)로 로컬 기동하고, 릴리스 간 보존된 축적 데이터 위에서 실행합니다. 이미지 무결성·upgrade 마이그레이션·OAuth·pipelines·RAG·브랜드 자산·`/health`를 검증합니다.

**immutable 최종 태그 규칙**: 검증에서 결함을 발견하면 같은 태그를 **재빌드하거나 덮어쓰지 않습니다.** 다음 kwh 번호(`kwh.N+1`)를 새 RC로 발행해 재실행합니다.

**최초 1회 설정:**

```bash
docker login ghcr.io -u kwh8121                    # PAT: read:packages
cp .env.local-test.template .env.local-test
# .env.local-test 편집: GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET 채움
# Google Cloud Console → OAuth 클라이언트 → Authorized redirect URIs:
#   http://127.0.0.1:8082/oauth/google/callback
```

**RC 검증 (기본 = 축적 데이터 보존):**

```bash
./scripts/local-test.sh vX.Y.Z-kwh.N-rc.M --allow-rc
# 브라우저: http://127.0.0.1:8082 — 프로덕션 미러 체크리스트 수행
#          (docs/plan/local-test-workflow.md §"로컬 수동 검증 체크리스트")
```

**옵션 플래그:**

- `--fresh` — 데이터 디렉터리가 비어 있어야 함 (신규 설치 마이그레이션 검증, upgrade 경로와 별개)
- `--no-backup` — upgrade 전 자동 백업 생략 (데이터 손실 위험)
- `--allow-rc` — RC 태그에 필수 (릴리스 게이트 혼동 방지용 기본 가드)
- `--reseed-cache` — 이미지에 baked-in된 모델 캐시를 강제 재복사. bind mount가 이미지의 `/app/backend/data/cache/*`를 가려 발생하는 약 250 MB HuggingFace 재다운로드를 피하기 위해 첫 실행 시 자동 seed되며, 릴리스에 새 번들 모델이 추가됐을 때 이 플래그를 사용합니다.

**백업 / 롤백:**

```bash
./scripts/local-test.sh --list-backups
./scripts/local-test.sh --restore <timestamp>
./scripts/local-test.sh --prune-backups --keep 5
```

**종료 (데이터 디렉터리 보존):**

```bash
./scripts/local-test.sh --down
```

백업 위치: `${OPENWEBUI_LOCAL_TEST_DATA}.backups/`, `${PIPELINES_LOCAL_TEST_DATA}.backups/` (기본값: `$HOME/openwebui-local-test-data.backups`, `$HOME/openwebui-local-test-pipelines.backups`).

### 3.7 PR 열기 (integration → main)

```bash
gh pr create --repo kwh8121/openwebui-service \
  --base main \
  --head integration/vX.Y.Z \
  --title "Merge integration/vX.Y.Z (kwh.N): <summary>" \
  --body-file <path-to-body.md>
```

PR 본문에는 로컬 게이트(§3.6-b) 검증 체크리스트를 완료 항목으로 포함합니다.

### 3.8 PR 병합 (`--merge` 방식)

```bash
gh pr merge <N> --merge --repo kwh8121/openwebui-service
git fetch origin && git checkout main && git pull --ff-only
```

`--squash`나 `--rebase`가 아닌 `--merge`를 씁니다. 이전 kwh 릴리스들과 정렬된 병합 커밋 구조를 보존하기 위함입니다.

### 3.9 최종 태그 발행 → 프로덕션 이미지 빌드

```bash
git tag -a vX.Y.Z-kwh.N <main-tip-sha> -m "..."
git push origin vX.Y.Z-kwh.N
```

빌드를 모니터링하고, 성공을 확인한 뒤에만 프로덕션을 건드립니다.

### 3.9-b 최종 태그 로컬 재검증 (v4)

같은 축적 로컬 데이터에 대해 최종 태그로 **§3.6-b**를 재실행합니다. 이것이 2차 게이트입니다 — RC 이미지는 병합 전 §3.6-b에서 이미 검증됐고, 이 실행은 최종 이미지(내용은 동일하나 새 immutable 태그)가 여전히 통과함을 확인합니다.

```bash
./scripts/local-test.sh vX.Y.Z-kwh.N        # 최종 태그에는 --allow-rc 불필요
```

실패 시 동일한 immutable 태그 규칙이 적용됩니다(재빌드 금지, `kwh.N+1`로 §3.5부터 재시작). 프로덕션 배포는 중단합니다.

### 3.10 프로덕션 배포

§7 참조 (GitHub Issue 핸드오프).

## 4. Docker Compose 파일

| 파일                             | 용도                                    | `build:` | 데이터 마운트                                                 |
| -------------------------------- | --------------------------------------- | -------- | ------------------------------------------------------------- |
| `docker-compose-build.yaml`      | 개발 빌드 전용                          | ✅ 있음  | 개발 데이터                                                   |
| `docker-compose.local-test.yaml` | **로컬 프로덕션 미러 검증**             | ❌ 없음  | 별도 로컬 테스트 데이터 디렉터리, localhost 전용 포트         |
| `docker-compose.deploy.yaml`     | 프로덕션                                | ❌ 없음  | `/app/backend/data`, `/app/pipelines` 보존                    |
| `docker-compose.staging.yaml`    | **폐기됨 (v4)** — 운영 호스트 병렬 기동 | ❌ 없음  | 예외 상황 전용. 프로덕션 데이터 디렉터리 마운트 **절대 금지** |

## 5. 배포 환경 변수

모두 `docker-compose.deploy.yaml`이 읽습니다. 조용한 기본값 fallback을 피하려면 명시적으로 설정합니다.

| 변수                        | compose 기본값             | 용도                                             |
| --------------------------- | -------------------------- | ------------------------------------------------ |
| `OPENWEBUI_IMAGE_TAG`       | 필수 (없으면 compose 실패) | GHCR 이미지 태그, 예: `v0.11.1-kwh.2` (`v` 포함) |
| `OPENWEBUI_LOCAL_DATA`      | `/app/backend/data`        | 사용자 데이터·DB의 bind-mount 소스               |
| `OPENWEBUI_DEPLOY_ENV_FILE` | `./.env.openwebui.oauth`   | OAuth·브랜드 설정이 든 env_file 경로             |
| `PIPELINES_LOCAL_DATA`      | `/app/pipelines`           | pipelines 컨테이너 bind-mount                    |

Koreatimes 브랜드에 필요한 env 파일 내용:

```env
WEBUI_NAME=Koreatimes
# ... 기존 OAuth 변수들 ...
```

추가 방법:

```bash
grep -q '^WEBUI_NAME=' <env-file> \
  && sed -i 's|^WEBUI_NAME=.*|WEBUI_NAME=Koreatimes|' <env-file> \
  || echo 'WEBUI_NAME=Koreatimes' >> <env-file>
```

**참고**: 이 fork는 `backend/open_webui/env.py`(현재 936행 직후)에서 upstream의 `WEBUI_NAME != 'Open WebUI'` 접미사 강제 로직을 제거했습니다(커밋 `4cbd9a061`). 따라서 `WEBUI_NAME=Koreatimes`는 `Koreatimes (Open WebUI)`가 아니라 `Koreatimes` 문자열 그대로가 됩니다.

## 6. 검증 체크리스트

로컬 게이트 또는 프로덕션 배포 후:

**컨테이너 상태**

- [ ] `docker compose ... ps openwebui`가 `running (healthy)` 또는 동등한 상태
- [ ] `docker compose ... logs --tail 100 openwebui`에 기동 오류 없음
- [ ] `curl -sf http://<host>/health`가 200 반환

**인증**

- [ ] 로그인 페이지 로드
- [ ] OAuth 제공자 흐름이 끝까지 완료
- [ ] 새로고침 후에도 사용자 세션 유지

**기능 스모크**

- [ ] 모델 요청: 메시지 전송 → 응답 수신
- [ ] 파일 업로드 / RAG: 문서 업로드 → 질의 → 인용 확인
- [ ] Pipelines: 워크스페이스 UI에 pipeline 서비스가 목록에 뜨고 연결 가능

**브랜드 (Koreatimes 교체 이후)**

- [ ] 좌상단 사이드바 로고 = Koreatimes
- [ ] 사이드바 하단 인스턴스명 = `Koreatimes` (` (Open WebUI)` 접미사 없음)
- [ ] 로그인 페이지 + 온보딩 로고 = Koreatimes
- [ ] 브라우저 탭 favicon + 제목 = Koreatimes
- [ ] `/manifest.json`의 `name` / `short_name` = `Koreatimes`
- [ ] `/opensearch.xml`의 ShortName / Description = `Koreatimes`
- [ ] 다크 모드 로고 정상 렌더링

**제안 프롬프트 동작 (kwh.2 이후)**

- [ ] 제안 카드 클릭 시 자동 전송이 아니라 입력란이 채워짐 (설정을 명시하지 않은 사용자 기준)

## 7. 프로덕션 배포 — GitHub Issue 핸드오프

프로덕션 배포는 **GitHub를 통제 평면으로 삼아** 수행합니다. 로컬 에이전트가 프로덕션에 직접 SSH로 배포하지 않습니다.

1. 로컬 에이전트가 릴리스별 배포 가이드 `docs/manual/kwh-deploy-guide-vX.Y.Z-kwh.N.md`를 작성해 커밋합니다. 템플릿 실례: `docs/manual/kwh-deploy-guide-v0.11.1-kwh.2.md`.
2. `Production deployment request` Issue를 제출합니다 (스키마는 `docs/manual/github-control-plane-local-agent-handoff.ko.md` §"배포 요청 계약", Protocol v1.2).
3. 관리자가 `Environment` 승인을 수행합니다.
4. opencode 프로덕션 에이전트가 `deploy-approved-production-release.yaml` 워크플로를 실행합니다. 이 워크플로가 자동 수행하는 것:
   - 태그 형식·계보·가이드·경로·현재 DB 상태 검증
   - 직전 릴리스 이미지를 롤백 대상으로 확보
   - 이미지 pull 및 digest pin (다운타임 이전)
   - Open WebUI만 중지 후 **SQLite WAL-safe 백업 생성 및 검증** (`stop` → `tar -czf` → `tar -tzf`)
   - `--no-deps`로 Open WebUI만 재생성
   - health·버전·manifest·컨테이너 상태·기동 로그 검증
   - `check_pipelines` 입력값에 따라 Pipelines API 스모크 수행 또는 skip 기록
5. 결과가 Issue에 evidence로 기록됩니다.

**참고**: `check_pipelines`는 기본값 `true`입니다. Pipelines가 의도적으로 중지된 경우에만 `false`로 두며, 그 판단 근거를 Issue에 기록해야 합니다.

### 롤백

이전 이미지 태그로 되돌립니다.

```bash
export OPENWEBUI_IMAGE_TAG=vX.Y.Z-kwh.<N-1>   # 예: v0.11.1-kwh.1
docker compose -f docker-compose.deploy.yaml pull openwebui
docker compose -f docker-compose.deploy.yaml up -d --no-deps openwebui
```

⚠ 이미지 롤백이 DB 마이그레이션을 자동으로 되돌리지는 않습니다. 릴리스마다 마이그레이션 유무를 확인하십시오.

**예외 상황 fallback**: GitHub 장애나 self-hosted runner 오프라인 등으로 핸드오프 인프라를 쓸 수 없을 때만 수동 SSH 배포를 사용합니다. 순서는 위 4번 워크플로가 수행하는 단계와 동일합니다(백업 → env 확인 → `OPENWEBUI_IMAGE_TAG` 등 명시 export → `pull` → `up -d --no-deps openwebui` → §6 스모크). 사용했다면 사유를 릴리스 노트와 Issue에 기록합니다.

## 8. SQLite WAL 백업 참고사항

외부 DB를 설정하지 않으면 Open WebUI는 WAL 모드의 SQLite를 사용합니다. 컨테이너가 도는 중에 단순 `tar`를 뜨면 커밋되지 않은 WAL 데이터를 놓칠 수 있습니다. 다음 중 하나를 사용합니다.

- **stop → tar → start** (짧은 다운타임, 가장 단순)
- **`sqlite3 <db> ".backup <copy>"`** 로 일관된 온라인 스냅샷을 뜬 뒤 보조 디렉터리(`uploads/`, `cache/` 등)를 tar

향후 Postgres 등 다른 백엔드를 채택하면 해당 DB의 네이티브 덤프 도구를 사용합니다.

## 9. 문서 전용 변경 — 단축 경로 폐지됨 (2026-07-31)

과거에는 문서 전용 변경(`docs/` 아래 Markdown, 주석 등)을 `main`에 직접 PR하는 단축 경로가 있었습니다. **이 경로는 폐지되었습니다.**

문서 변경도 코드와 동일하게 `feature/*` → `integration/vX.Y.Z` → PR → `main`을 따릅니다. 다만 문서 전용 변경은 **새 git 태그나 이미지 재빌드가 필요 없습니다.**

## 10. 복구 패턴

### 10.1 `main`에 실수로 커밋한 경우

커스텀 변경을 로컬 `main`에 실수로 커밋했다면(2026-07-22 `insertSuggestionPrompt` 수정에서 실제 발생), push 이전에:

```bash
git branch feature/<slug> <bad-commit-sha>      # 커밋 보존
git reset --hard origin/main                    # main 복원
git checkout integration/vX.Y.Z
git merge --no-ff feature/<slug> \
  -m "merge: feature/<slug> into integration/vX.Y.Z"
```

커밋 SHA가 살아남고(`git branch`가 해당 SHA를 가리킴), `main`은 원상 복구되며, 변경은 올바른 경로로 integration에 도달합니다. 2026-07-22 커밋 `c68c745d2`로 검증됨.

### 10.2 릴리스 후 문서 예시 불일치 발견

§9의 원칙에 따라 `feature/*` → `integration/vX.Y.Z` → PR → `main`으로 수정합니다. 새 릴리스 태그는 불필요합니다.

## 11. 세션 연속성

- 작업 로그: `docs/jobs/YYYY-MM-DD-openwebui-jobs.md` (같은 날은 append)
- 본 문서: 릴리스 루틴을 건드리는 모든 세션에서 참조
- 영속 메모리(mem0/openviking): 본 문서를 가리키는 포인터가 `kwh8121-openwebui-service` 프로젝트 스코프에 존재

세션 간 재개 시 다음으로 방향을 잡습니다(전체 이력을 읽지 않고).

```bash
git status --short --branch
git log --oneline -5
git tag -l 'v*-kwh.*' | sort -V | tail -5
```

## 12. upstream 대비 divergence (현행 인벤토리)

향후 upstream 병합에서 무엇이 충돌할지 운영자가 알 수 있도록 여기에 유지합니다. 줄번호는 `v0.11.3` 병합 트리 기준입니다.

| 파일                                                        | 줄       | 변경 내용                                                                                                                                            | 도입                        |
| ----------------------------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `src/lib/components/chat/Chat.svelte`                       | 910      | `insertSuggestionPrompt` 기본값 `?? false` → `?? true` (제안 카드 클릭 시 자동 전송 방지)                                                            | `c68c745d2` (v0.10.2-kwh.2) |
| `src/lib/components/common/InterfaceSettings.svelte`        | 59, 340  | `= false` / `?? false` → `= true` / `?? true` (Chat.svelte 기본값과 일치). 파일 경로는 upstream 리팩터로 `chat/Settings/Interface.svelte`에서 이동됨 | `c68c745d2` (v0.10.2-kwh.2) |
| `backend/open_webui/env.py`                                 | 936 직후 | upstream의 `if WEBUI_NAME != 'Open WebUI': WEBUI_NAME += ' (Open WebUI)'` 2줄 삭제                                                                   | `4cbd9a061` (v0.10.2-kwh.2) |
| `Dockerfile`                                                | 31       | `ENV NODE_OPTIONS="--max-old-space-size=6144"` 주석 해제·상향 (프론트 빌드 OOM 방지)                                                                 | v0.10.2 사이클              |
| `static/static/*` + `backend/open_webui/static/*`           | —        | Koreatimes 브랜드 자산 (12개 파일 × 2개 디렉터리)                                                                                                    | `171e0f742` (v0.10.2-kwh.2) |
| `.github/workflows/docker.yaml`                             | —        | upstream 멀티아치·멀티배리언트 매트릭스를 fork 전용 최소 GHCR 워크플로로 전면 대체 (366줄 삭제)                                                      | fork 소유                   |
| `.github/workflows/release-pypi.yml`, `release.yml`         | —        | `.disabled`로 rename해 비활성화 (PyPI/release publish 차단)                                                                                          | fork 소유                   |
| `.github/workflows/deploy-approved-production-release.yaml` | —        | fork 추가. 프로덕션 배포 워크플로 (Protocol v1.2)                                                                                                    | fork 추가                   |
| `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` | —        | fork 추가. 배포 요청 Issue 템플릿                                                                                                                    | fork 추가                   |
| `docker-compose.yaml`                                       | —        | port 80, `.env.openwebui.oauth` 로드, `shared_bridge_network` 연결 (배포 특화)                                                                       | fork 수정                   |
| `docker-compose.{deploy,staging,local-test,-build}.yaml`    | —        | fork 추가. 배포·검증용 compose 정의                                                                                                                  | fork 추가                   |
| `scripts/local-test.sh`, `.env.local-test*.template`        | —        | fork 추가. 로컬 프로덕션 미러 게이트                                                                                                                 | v4 도구                     |
| `pipelines/*.py`                                            | —        | fork 추가. Dify/n8n/perplexity/wikipedia 파이프라인                                                                                                  | fork 추가                   |
| `.gitignore`                                                | —        | `CLAUDE.md` 항목 제거(루트 `CLAUDE.md` 커밋 가능하도록) 및 personal-scope 확장                                                                       | v0.10.2-kwh.2 이후          |
| `CLAUDE.md` + 하위 `AGENTS.md` 11개                         | —        | fork 추가. 에이전트 가이드 (`CLAUDE.md`가 `@AGENTS.md`를 import)                                                                                     | v0.10.2-kwh.2 이후          |

**upstream으로 졸업한 항목** (더 이상 divergence 아님):

| 파일                                 | 내용                                                                     | 처리                                                                                                            |
| ------------------------------------ | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `backend/open_webui/models/users.py` | `v0.11.1-kwh.2` OAuth 서브젝트 SQLite 정수 오버플로 핫픽스 (`dc9f01761`) | upstream `17cc5667`(v0.11.2)이 동일 버그를 더 강하게 수정. v0.11.3 병합 시 upstream 버전 채택, fork 핫픽스 폐기 |
