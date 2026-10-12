# 2026-10-12 Open WebUI 작업일지

## 19:11 UTC — upstream v0.12.0 통합 + RC 게이트 (개발 에이전트)

### 시작 점검

- 시작 시 `main` = `origin/main`(`98c1e3a61`). 열린 PR #54(`integration/v0.11.4` → `main`, #47·#49 1단계)와 #55(`feature/deploy-backup-workflow-cleanup` → `integration/v0.11.4`)가 draft로 보류돼 있었고, 열린 Issue는 #34·#47·#48·#49.
- `git fetch upstream --tags`로 `v0.12.0`(`15818d88f`, 2026-10-10)을 확인. `v0.11.4`에서 584 커밋·542 파일. 마지막 일지(10-07)가 예고한 "다음 upstream 릴리스 통합" 지점.

### 결정 (사용자 선택)

- **통합 기준:** #55 → #54 순서로 먼저 병합한 `main`에서 `integration/v0.12.0`을 분기. #47·#49 수정이 v0.12.0-kwh.1에 포함되고 `main`↔`integration/v0.11.4` 발산(4/6)이 해소된다.
- **게이트 모드:** 기본(누적 데이터 + 자동 백업).
- **진행 확인:** push·integration 병합·RC 태그는 되돌릴 수 없어(`integration/*` ruleset, immutable 태그) 실행 직전에 사용자 확인을 받았다.
- **문서 방식:** 지난 사이클과 같음 — 가이드 초안(`<TBD>`)과 일지를 통합 PR에 포함, 최종본은 문서 전용 PR.

### 수행

1. #55(`backup-regression` 1건)·#54(check 5건) CI green 확인 후 ready 전환·`--merge` 병합. #54는 #55 병합으로 head가 바뀌어 check 9건으로 CI가 재실행(약 3분)된 뒤 병합. `main` = `c22d75a8a`. 병합은 태그·빌드·배포를 일으키지 않는다.
2. `integration/v0.12.0` 분기, `feature/upstream-merge-v0.12.0`에서 `v0.12.0` 병합(`da231c07f`). `merge-tree` 예측과 같이 텍스트 충돌은 `.github/workflows/docker.yaml` 1건.
3. 정적 검사: `npm ci`(Node 22, 1,152 패키지), `i18n:parse` 변경 0건, prettier·vitest 4/4·ruff(추적 363개) 통과, `svelte-check` 6,040건(기준선 약 7,800) 중 수정 파일 신규 오류 0건.
4. push → `integration/v0.12.0` 병합(`68baf382c`) → RC 태그 `v0.12.0-kwh.1-rc.1` → GHCR 빌드 run 38230963520 success(headSha 일치).
5. 로컬 게이트 `./scripts/local-test.sh v0.12.0-kwh.1-rc.1 --allow-rc --health-timeout 900`: **PASS**. 부팅 103초, 마이그레이션 6건(`d4c1a8e37b62` → `b8f2c6d91a04`), `alembic current == heads`, integrity `ok`, pipelines 응답. 백업 `20261012-184618-…` / pipelines `20261012-184750-…`.
6. 수동(사용자 확인): OAuth·pipelines 채팅·RAG·브랜드·버전 표시, 저장 채팅의 제목 생성.
7. 검증: RC 이미지 안에서 `test_background_tasks_handler.py` 3/3 통과. 컨테이너 로그를 `/usr/bin/docker logs`로 수집(331줄)해 `Traceback`·`KeyError` 0건.

### 충돌·판단 기록

- **`docker.yaml`(텍스트 충돌):** fork가 전면 교체한 파일이라 우리 workflow 유지. 단 v0.12.0 신규 `BUILD_CHANNEL`을 `main`으로 고정해 반영 — Dockerfile이 `APP_BUILD_CHANNEL`로 전달하고 `BuildVersion.svelte`가 UI에 노출한다. 넘기지 않으면 `unknown`이 되어 버전 표시에 `(build · hash)`가 붙고 업데이트 확인이 꺼진다.
- **`middleware.py`(의미 충돌, git이 자동 병합):** upstream이 #47과 같은 `KeyError`를 `ctx['model']` → `ctx.get('model')`로 독립 수정했고, 병합 결과가 우리 가드와 합쳐져 `ctx.get('model')`이 남았다. 이는 `test_completed_turn_context_without_model_still_fails_loudly`(KeyError 단정)를 깨뜨린다. `build_chat_response_context`가 항상 `'model'`을 설정하므로 upstream의 `.get()`은 도달 불가 경로의 방어 코드. PR #54에서 승인된 "엄격 유지" 의도를 지켜 `ctx['model']`로 되돌렸다.
- 보존 확인: 브랜드 자산·compose 4종·`scripts/local-test.sh`·`insertSuggestionPrompt=true` 기본값은 병합 전후 diff 0. 해당 경로에서 바뀐 것은 upstream `static/pyodide/pyodide-lock.json`뿐.

### 발견·관측

- **이번 릴리스는 이전과 성격이 다르다:** 마이그레이션 6건이 기존 `model`·`skill`·`tool`·`function` 행마다 history 행을 만들고 `version_id`를 채운다. 모두 `downgrade()`는 있지만 이전 이미지(`v0.11.4-kwh.1`)는 downgrade하지 않으며 DB revision을 모르므로 **이미지 롤백만으로 복구된다고 가정할 수 없다.** 배포 가이드 §8을 "백업 복원이 기본 경로"로 썼다. 복원·downgrade는 **시험되지 않았다.**
- **프로덕션 규모(약 3.7 GB) 마이그레이션 시간은 미검증.** 로컬은 891 MB 기준 103초.
- **`rtk`가 `docker logs` 출력을 14줄로 압축·중복 제거**해 채팅 요청이 보이지 않았다. 이 출력으로는 판단하지 않고 `/usr/bin/docker`로 재수집했다. (AGENTS.md의 "도구 함정"에 `docker logs`도 포함해야 한다 — 미반영, 별도 확인 필요.)
- 게이트 `ERROR`: 도구 서버 `fastapi-tools-v2` DNS(#48, 릴리스 무관), `oauth_sessions` `InvalidToken`(로컬 컨테이너의 새 `WEBUI_SECRET_KEY` + 브라우저의 이전 세션 쿠키, 직후 `signout` 200).
- 제목의 UI 표시는 개발 측이 직접 보지 못했다(사용자 보고 + 로그 정황).
- 미추적 `docs/plan/2026-10-12-wire-desk-poc-*.md`·`herb-wire-api-request-v9.md` 4건은 이전 세션 산출물로 이번 작업과 무관해 손대지 않았다. `ruff format --check .`가 이 중 2건의 코드 블록을 재포맷 대상으로 보고했으나 추적 파일이 아니라 CI와 무관하다.

### 교훈

- git의 자동 병합이 **텍스트 충돌 없이도 의미를 깨뜨릴 수 있다.** `merge-tree`가 충돌 1건만 예측해도 우리가 수정한 함수와 upstream 변경이 겹쳤는지 따로 대조한다(`git diff v0.11.4 v0.12.0 -- <우리가 고친 파일>`).
- 지난 사이클 교훈(수동 체크리스트 직후 `Traceback` 재스캔, 저장 채팅 + 제목 생성 포함)을 이번 RC에 적용했다. 로그 수집은 반드시 절대 경로로.

### 다음 재개 지점

1. 이 문서·가이드 초안을 `feature/docs-v0120-deploy-guide` → `integration/v0.12.0` → `main` PR로 전달.
2. `main` tip에 최종 태그 `v0.12.0-kwh.1` 발행(immutable, 발행 전 사용자 확인) → GHCR 빌드·digest → 최종 이미지 게이트.
3. 가이드 최종본(문서 전용 PR) — `<TBD>` 채움, workflow 재대조, `guide_commit` 확정.
4. 프로덕션 규모 마이그레이션 시간·백업 복원 시험은 배포 승인 전 소유자와 논의 필요(가이드 §4·§8).
5. 로컬 게이트 컨테이너(8082/9099)는 실행 중. 최종 게이트 전 `./scripts/local-test.sh --down`.

## 19:46 UTC — 최종 태그 `v0.12.0-kwh.1` 발행 + 최종 이미지 게이트 + 가이드 최종본 (개발 에이전트)

### 수행

1. PR #56(`integration/v0.12.0` → `main`) CI 5건 green 확인 후 ready·`--merge` 병합(`b7a661939`). 병합 후 `main` CI 4건도 green.
2. 사용자 승인 후 최종 태그 `v0.12.0-kwh.1`(annotated) → `b7a66193917b8344ff928c996171b99089dba12f` 발행. 발행 직전 `origin/main`이 그 SHA인지와 태그 미존재를 스크립트로 확인했다. GHCR 빌드 run 38236137881 success(headSha 일치).
3. digest: index `sha256:cd4957b2…c985`, linux/amd64 `sha256:24581534…ee25`. 최종 태그와 `git-b7a6619`가 같은 index digest로 해석됨(양쪽 `docker pull` 후 `RepoDigests` 비교).
4. **최종 이미지 게이트 `[PASS]`**: `./scripts/local-test.sh v0.12.0-kwh.1 --health-timeout 900`(기본 모드, 자동 백업 포함). 부팅 71초, 마이그레이션 6건, `alembic current == heads`(`b8f2c6d91a04`), integrity `ok`, pipelines 응답. 컨테이너 이미지 digest가 index digest와 일치, 기동 로그 `Commit: b7a66193…`. 로그 59줄 `Traceback`·`KeyError`·`ModuleNotFoundError` 0건, `ERROR`는 도구 서버 DNS 2건(#48)뿐.
5. 마이그레이션 후 DB(읽기 전용 조회): `model` 369 → `model_history` 369, `version_id` NULL 0건, 사용자 3·채팅 6 유지.

### 판단 기록

- **RC 게이트 이후 데이터는 이미 `b8f2c6d91a04`였다.** 그대로 최종 이미지를 띄우면 마이그레이션 0건이라 최종 이미지가 6건을 적용하는 경로가 검증되지 않는다. 사용자가 "기본 모드(누적 데이터)"를 택한 근거가 메이저 점프 마이그레이션 검증이었으므로, RC 직전 백업(`20261012-184618-v0.12.0-kwh.1-rc.1`)으로 data 디렉터리를 복원한 뒤 게이트를 돌렸다. 복원 전 revision `d4c1a8e37b62`·integrity `ok`를 읽기 전용으로 확인했다.
- `--restore`는 data·pipelines 백업의 타임스탬프가 같아야 한다. RC 백업은 data `184618`·pipelines `184750`으로 달라 그대로 쓸 수 없었다. 스크립트를 고치지 않고 `--restore`와 같은 동작(현재 디렉터리를 `.rolled-back-…`으로 옮겨 보존 후 추출)을 data 디렉터리에만 수행했다. 보존본은 `~/openwebui-local-test-data.rolled-back-20261012-193551`(RC 이후 상태, RC 때 만든 테스트 채팅 포함). pipelines 디렉터리는 alembic 대상이 아니라 그대로 뒀다.

### 발견·한계

- **`skill`·`tool`·`function` backfill은 실제 행으로 시험되지 않았다.** 로컬 DB에 세 테이블이 모두 0건이다. `model` 경로(369행)만 검증됐다. 프로덕션에 도구·함수·스킬이 있으면 처음 실행되는 코드이므로 가이드 §7.2·§9에 명시했다.
- 이 호스트에는 `docker buildx`가 없다(`docker: unknown command: docker buildx`). digest는 `docker manifest inspect`와 `docker pull`의 `RepoDigests`로 확인했다. 첫 시도에서 이 사실을 모르고 출력 파싱 실패로 오진할 뻔했다.
- 최종 게이트는 자동 검사만 수행했다(수동 체크는 RC에서 수행, 지난 사이클과 동일).
- 프로덕션 규모(약 3.7 GB) 마이그레이션 시간, 백업 복원, DB downgrade는 여전히 미검증·미시험이다.

### 다음 재개 지점

1. 가이드 최종본 문서 전용 PR(`feature/docs-v0120-deploy-guide-final` → `integration/v0.12.0` → `main`) 병합 후, 그 `main` 커밋 SHA가 `guide_commit`.
2. 배포 요청 Issue(`Production deployment request`) 제출 — 소유자 승인 필요. `check_pipelines`는 Issue에서 확정(가이드 §3.7). 배포 전 프로덕션의 Model/Tool/Function/Skill 개수 기록, 현재 revision `d4c1a8e37b62` 확인.
3. 소유자 논의: 백업 복원 시험(가이드 §8이 복원을 기본 복구 경로로 가정), 프로덕션 규모 마이그레이션 시간.
4. 로컬 게이트 컨테이너(8082/9099)는 실행 중. 확인 후 `./scripts/local-test.sh --down`. `.rolled-back-20261012-193551`은 필요 없으면 삭제.
