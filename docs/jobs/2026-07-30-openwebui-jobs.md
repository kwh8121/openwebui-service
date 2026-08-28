# Open WebUI Jobs Log — 2026-07-30

> Resume: `claude --resume 5b199c1c-8f18-482b-911b-74c53ef6000d`

## 요약

- 로컬 사전 배포 검증 도구를 v3 "추가 방어선"에서 **v4 "스테이징 게이트 대체"**로 승격. 스테이징(`docker-compose.staging.yaml`)이 프로덕션과 동일 호스트 위 compose 격리만 제공한다는 위험 인식 → 로컬 프로덕션 미러(OAuth on, pipelines 편입, 데이터 보존, 자동 WAL-safe 백업/롤백)로 재설계.
- v4 도구 구현·통합·RC2 태그 발행: 커밋 `f3dd74bd0`(v4 도구) → `5bc81840e`(integration 머지) → 태그 `v0.10.2-kwh.3-rc.2`(GH Actions 빌드 6분 41초 성공).
- 브라우저 검증 도중 이슈 발견 및 대응:
  1. **첫 실행 시 ~250MB 임베딩 모델 재다운로드** — non-slim 이미지에 baked-in된 `/app/backend/data/cache/*`가 bind mount에 가려져 재다운로드 유발. v4.1 패치로 `docker create + docker cp` 기반 cache seed 로직 추가 (커밋 `444a2d180`, `170566c23`).
- 새 이슈 발견(미해결): `tar` exit code 1(warning)을 스크립트가 실패로 판정해 백업이 abort됨. 즉시 워크어라운드는 `--no-backup`. v4.2 패치 예정.

## 작업 흐름

1. **v4 설계 및 계획 개정**
   - 사용자가 "스테이징이 결국 운영 서버에서 검증되는 형태이므로 로컬로 이동하고 싶다"고 제시.
   - `docs/plan/local-test-workflow.md` v4 개정: 포지셔닝 승격, env 프로덕션 미러화, 데이터 보존 기본화, 자동 백업/롤백, pipelines 편입, 워크플로 재정의 (RC 로컬 검증 → PR → 최종 태그 → 로컬 재검증 → 프로덕션 배포).
   - 옵션 A(v3 도구 임시 활용) vs 옵션 B(v4 도구 구현) 제시 → 옵션 B 선택.

2. **v4 도구 구현 (`feature/local-test-workflow-v4`)**
   - `docker-compose.local-test.yaml`: `pipelines` 서비스 편입 (`ghcr.io/open-webui/pipelines:main`, 127.0.0.1:9099).
   - `.env.local-test.template`: 프로덕션 미러(OAuth on, Google OIDC 자리 표시자, `WEBUI_URL`, `OPENAI_API_BASE_URL=http://pipelines:9099`, redirect URI 등록 안내).
   - `.env.local-test.fresh.template`: v3 스타일 fresh 모드 보존(OAuth off, 패스워드 로그인).
   - `.gitignore`: `!.env.local-test.fresh.template` 예외 규칙 추가.
   - `scripts/local-test.sh`: defaults reverse (기본 preserve), `--fresh`/`--no-backup`/`--allow-rc` 플래그, 자동 WAL-safe 백업(compose down → tar), `--list-backups`/`--restore <ts>`/`--prune-backups [--keep N] [--yes]` 하위 명령, pipelines state 4중 확인 추가.
   - `docs/manual/kwh-release-routine.md`: §3.6에 deprecation notice + `OPENWEBUI_STAGING_*` 변수명 정정, §3.6-b 신설, §3.9-b 짧은 포인터로 축소.
   - 검증: `bash -n` OK · CLI 케이스 테스트 통과 · `docker compose config` dry-run OK.
   - 커밋 `f3dd74bd0` (813 insertions, 287 deletions, 7 files) → push → `integration/v0.10.2` `--no-ff` 머지 `5bc81840e` → push.

3. **RC2 태그 발행 및 빌드**
   - `v0.10.2-kwh.3-rc.2` at `5bc81840e` — 이미지 콘텐츠는 RC1과 byte-identical(도구 개편만), 새 태그로 도구 실기동.
   - GH Actions run `30433693789` 6분 41초 성공. 산출물: `ghcr.io/kwh8121/openwebui-service:v0.10.2-kwh.3-rc.2`, `git-5bc8184`.

4. **첫 실행 임베딩 모델 다운로드 이슈 발견**
   - 사용자가 이미지 다운로드가 매우 오래 걸린다고 지적.
   - 조사: `Dockerfile:6 ARG USE_SLIM=false` (기본) → 이미지 빌드 시 sentence-transformers `all-MiniLM-L6-v2` + `bge-micro-v2` + Whisper base + tiktoken이 `/app/backend/data/cache/*`에 baked-in.
   - 우리 `docker-compose.local-test.yaml`이 빈 host 디렉터리를 `/app/backend/data`에 bind mount → baked-in cache 완전히 가림 → 첫 실행 시 HuggingFace에서 ~250MB 재다운로드.
   - 프로덕션에서는 이전 릴리스의 데이터 dir가 cache를 포함해 유지되므로 이 문제가 안 보이는 것.
   - 3가지 해결책 제시(cache seed 스크립트 패치 / named volume 분리 / 무시). **cache seed 패치(v4.1)** 채택.

5. **v4.1 패치 구현 (`feature/local-test-workflow-v4.1`)**
   - `scripts/local-test.sh`에 이미지 pull 직후 · compose up 이전에 seed 로직 삽입:
     - 첫 실행 감지: `$DATA_DIR/cache` 부재/empty → `docker create $FULL_IMAGE` + `docker cp <cid>:/app/backend/data/cache $DATA_DIR/`
     - `--reseed-cache` 플래그: 강제 재복사(신규 릴리스에 추가 baked-in 모델 대비)
     - USE_SLIM=true fallback: docker cp 실패해도 경고 후 정상 진행
   - `docs/plan/local-test-workflow.md`: v4.1 revision entry 추가.
   - `docs/manual/kwh-release-routine.md`: §3.6-b 옵션 플래그에 `--reseed-cache` 추가.
   - 검증: `bash -n` OK. 실제 실행 테스트는 세션 격리 제약으로 미수행(assistant/user가 같은 `$HOME` 공유).
   - 커밋 `444a2d180` (49 insertions, 2 deletions, 3 files) → push → `integration/v0.10.2` `--no-ff` 머지 `170566c23` → push.
   - 결정: 옵션 α(RC3 발행 없이 kwh.3-rc.2 이미지에 v4.1 스크립트 적용)로 진행 → 이미지 byte-identical이므로 RC 재빌드 스킵.

6. **백업 tar exit-1 이슈 발견 (미해결)**
   - 사용자가 v4.1 스크립트로 재실행 → `ERROR: backup failed`.
   - 실제로는 백업 파일이 정상 생성됨(테스트에서 805MB 확인). `tar` exit 1(warning: 파일 read 중 변경, 특수 파일 skip 등)을 스크립트가 실패로 판정.
   - 스크립트가 `2>/dev/null`로 stderr 숨겨 정확한 warning 원인 미확인.
   - 즉시 워크어라운드: `--no-backup` 플래그.
   - v4.2 패치 초안: tar exit code 구분(`0` OK, `1` warn, `2` fatal) + stderr 캡처 + 파일 생성/크기 검증.

## 커밋 / PR

**커밋 (2026-07-29 밤 ~ 2026-07-30 오전):**

- `f3dd74bd0` feat(local-test): v4 promote to release gate, prod-mirror + data preservation
- `5bc81840e` merge: feature/local-test-workflow-v4 into integration/v0.10.2
- `444a2d180` fix(local-test): v4.1 seed baked-in model cache on first run
- `170566c23` merge: feature/local-test-workflow-v4.1 into integration/v0.10.2

**태그:**

- `v0.10.2-kwh.3-rc.2` at `5bc81840e` — GHCR run `30433693789`, 6분 41초 성공

**PR:** 이번 세션에서 생성 안 함. 다음 단계로 통합 후 PR → main 예정.

## 브랜치 이동

`integration/v0.10.2` → `feature/local-test-workflow-v4` → `integration/v0.10.2` → `feature/local-test-workflow-v4.1` → `integration/v0.10.2` (최종)

## 학습 사항

- **스테이징 격리는 논리적일 뿐 물리적이지 않다**: 프로덕션과 동일 호스트에서 compose 격리(포트/data dir/network)로만 분리된 스테이징은 자원 경합·커널·네트워크 경로를 통해 프로덕션에 파급될 수 있음. 로컬 프로덕션 미러가 더 안전한 릴리스 게이트.
- **Open WebUI `WEBUI_URL`과 브라우저 접속 도메인은 정확히 일치해야 함**: `localhost` vs `127.0.0.1`은 별개 도메인. OAuth state 쿠키가 `127.0.0.1`로 발급되면 `localhost` 접속에서 못 읽어 `/oauth/google/login`에서 500 발생. 문서에서 접속 URL을 `http://127.0.0.1:8082`로 명시 통일 필요.
- **Non-slim 이미지의 baked-in cache는 bind mount에 가려진다**: `/app/backend/data`에 빈 host dir를 mount하면 이미지 내 `/app/backend/data/cache/*`가 완전히 가려져 첫 실행 시 재다운로드 발생. `docker create` + `docker cp`로 seed하면 해결.
- **콜드 부트는 60초 이상 걸릴 수 있음**: 신규 SQLite + Alembic + Uvicorn 초기화 조합으로 90~180초까지 걸리는 사례 흔함. `/health` 폴링 window를 확장하거나 환경변수로 조정 가능하게 하는 것이 안전.
- **`tar` exit code**: 0=성공, **1=warning(파일 read 중 변경 등, 파일은 생성됨)**, 2=fatal. `!` 부정문으로 판정하면 warning도 실패로 취급됨. 파일 존재/크기로 실제 성공 여부 판정하는 것이 더 안전.
- **assistant 세션과 사용자 세션이 같은 `$HOME` 공유**: `~/openwebui-local-test-data` 같은 로컬 자원에 assistant가 스크립트 실행 테스트를 하면 사용자 데이터에 사이드이펙트 발생. bash 문법 검증(`bash -n`)까지만 하고 실제 실행은 사용자에게 넘길 것.
- **RC 태그는 이미지 콘텐츠가 바뀌지 않는 script/docs만 있는 통합에서도 발행 가능**: 도구 개편(v4)을 실기동으로 검증하기 위해 새 태그 필요. 반대로 v4.1처럼 script만 바뀐 후속 hotfix는 기존 RC 이미지 재사용해도 유효(옵션 α).
- **immutable 태그 원칙은 도구 자체가 아니라 이미지 콘텐츠에 대한 것**: 스크립트 패치는 host-side라 이미지에 baked되지 않음. 같은 kwh.N 라인 안에서 RC 하위 번호(rc.M+1) 발행 없이도 스크립트만 업데이트 가능.

## 다음 후보 작업

- **사용자: 현 세션 검증 재개** — `--no-backup`으로 v4.1 스크립트 재실행하여 브라우저 프로덕션 미러 체크리스트 완료.
- **v4.2 패치**: 백업 tar exit-1 처리 (exit code 구분 + stderr 캡처 + 파일 크기 검증). 이번 검증 완료 후 별도 브랜치.
- **v4.3 후보**: `/health` 폴링 window 확장(60초 → 240초) + 진행 로그 + `OPENWEBUI_LOCAL_TEST_HEALTH_TIMEOUT` 환경변수 오버라이드.
- **PR `integration/v0.10.2` → `main`** (검증 통과 후, `--merge` 스타일).
- **최종 태그** `v0.10.2-kwh.3` on merged main tip → GH Actions 프로덕션 빌드.
- **최종 태그 재검증** (§3.9-b, `./scripts/local-test.sh v0.10.2-kwh.3`, 축적 데이터 유지).
- **프로덕션 SSH 배포** — `docs/manual/kwh-release-routine.md §7` 순서대로.
- **정리**: 세션 테스트로 생성된 백업 파일 3개(~2.4GB) — `./scripts/local-test.sh --prune-backups --keep 1 --yes` 로 정리 가능.
- **저장소 상태 정리**: 브랜치 트리에 `docs/openwebui-*-research.md` 8개 파일이 로컬 삭제된 상태로 남아있음 (이번 세션 범위 밖). 원인 조사 후 별도 처리 필요.

## 미커밋 상태

이 로그 파일(`docs/jobs/2026-07-30-openwebui-jobs.md`)은 로컬만 저장. 커밋은 하지 않음 (이전 관례). 필요 시:

```bash
git add docs/jobs/2026-07-30-openwebui-jobs.md
git commit -m "docs: add 2026-07-30 openwebui jobs log"
```
