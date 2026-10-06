# Open WebUI Jobs Log — 2026-10-06

> 직전 세션은 `2026-09-04-openwebui-jobs.md`. 그 사이(09-16)에 로컬 개발 착수 전 점검이 있었고, 이 파일은 그 점검의 후속 정리와 **upstream v0.11.4 통합 사이클**을 기록한다.

## 요약

저장소 위생을 정리한 뒤(태그 네임스페이스·`.gitignore` 오타·미커밋 문서) **upstream v0.11.4 를 병합해 `integration/v0.11.4` 를 만들고 RC 게이트 자동 검증까지 통과**시켰다. 병합은 충돌 0건이고 fork 코드 변경은 3줄뿐이다.

RC 이미지는 `v0.11.4-kwh.1-rc.1`, 로컬 게이트 자동 검증 **PASS**. **브라우저 수동 체크리스트와 프로덕션 Tool/Function 의 `langchain_community` 점검은 미완**이다 (아래 §미검증). 프로덕션은 `v0.11.3-kwh.1` 그대로이며 이 세션에서 프로덕션에 어떤 조작도 하지 않았다.

## 1. 저장소 위생 정리

| 작업                                    | 내용                                                                                                                                                                                                                                 |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `integration/v0.11.3` 동기화            | `origin/main` 과 ff-only (`5f347488c` → `a4945d3a2`)                                                                                                                                                                                 |
| 오염된 bare 태그 3개 + Release 3개 삭제 | origin 의 `v0.11.0`·`v0.11.1`·`v0.10.2` 는 upstream 태그명인데 fork 커밋을 가리키고 있었다 (fork 규약은 `vX.Y.Z-kwh.N` 만). 로컬 `v0.10.2` 도 upstream 원본(`ecd48e2f7`)으로 되돌림. `git fetch --tags` 의 `would clobber` 경고 해소 |
| Release 본문 보존                       | 세 Release 모두 upstream 본문 복제본. v0.11.0·v0.11.1 은 바이트 동일이라 보존 불필요. v0.10.2 만 fork 사본에 `Database Migrations` 경고 1줄이 더 있어 `docs/references/openwebui-v0.10.2-release-notes.md` 로 보존                   |
| `.gitignore` 오타 수정                  | 커밋 `8bd740464` 가 `.omc/` 를 `.omo/` 로 잘못 적어 규칙이 한 번도 동작하지 않았음. `/.omc/*` + `!/.omc/skills/` 로 수정 (AGENTS.md 의 committable 예외 유지)                                                                        |
| 미커밋 문서 정리                        | 업데이트 리포트(2026-09-10) 커밋, Claude Code 스킬 요약본 2개는 `docs/references/` 가 upstream 전용이라 `.gitignore` 로 로컬 보관. repomix 덤프 2개(11.3 MB)는 이미 디스크에서 사라져 있었음                                         |

PR #41 (`integration/v0.11.3` → `main`) 로 올림. **이 파일 작성 시점에 병합하지 않았다.**

## 2. upstream v0.11.4 통합

- 범위: `v0.11.3` → `v0.11.4`, 327 커밋, 424 파일. DB 마이그레이션 **없음**.
- 병합 전 `git merge-tree --write-tree` 로 충돌 0건을 예측했고 실제 병합과 일치.
- fork 커스터마이징 8항목(§4.5 체크리스트) 보존 확인. 상세는 [`docs/plan/v0.11.4-integration.md`](../plan/v0.11.4-integration.md).
- 줄번호 이동을 `kwh-release-routine.md` §12 에 반영 (Chat.svelte 926, InterfaceSettings 60/341, env.py 951, Dockerfile 34).
- 정적 검증: format·i18n·ruff·vitest 통과, 작업 트리 clean. svelte-check 은 7,001 오류(upstream 베이스라인, 신규 0건).

### 영향 판정 요지

- upstream 의 폰트 11개 삭제는 "아무도 로드하지 않던 폰트"라 무영향.
- 새 Dockerfile 에도 CI 의 `awk` 주입이 그대로 1줄 동작 (로컬에서 CI 와 동일 awk 실행으로 확인).
- **`langchain-community` 제거(브레이킹)**: fork 소유 코드에는 참조 0건이나 프로덕션 Tool/Function 은 저장소로 확인 불가 → §3.

## 3. RC 게이트 결과 — `v0.11.4-kwh.1-rc.1` @ `5f3ede34c`

GH Actions 빌드 `#37413977492` 성공(약 9분). `./scripts/local-test.sh v0.11.4-kwh.1-rc.1 --allow-rc --health-timeout 900` (자동 백업 켬).

| 항목                          | 결과                                                                                                                                                  |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 자동 게이트                   | **PASS** — 부팅 98초, `/health` 200                                                                                                                   |
| 마이그레이션                  | 이번 부팅 upgrade 0건, `alembic current == heads` (`d4c1a8e37b62`), SQLite `integrity_check = ok`                                                     |
| `/api/config`                 | `name = 'Koreatimes'` (접미사 없음), `version = 0.11.4`, oauth = google                                                                               |
| 브랜드 자산                   | favicon·logo·splash·splash-dark 4개 모두 HTTP 200 + fork 사본과 sha256 일치                                                                           |
| 컨테이너 로그 (stdout+stderr) | `Traceback`·`langchain`·`ModuleNotFoundError`·`ImportError` 모두 0건. `ERROR` 2건은 `fastapi-tools-v2` 미접속(로컬에 없는 프로덕션 도구 서버, 비치명) |
| pipelines                     | 6개 파이프라인 로드, 모델 11개 노출 — 09-04 기준선과 동일                                                                                             |

## 4. ⚠️ 미검증 — 통과로 읽지 말 것

09-04 의 교훈("게이트 통과가 검증됨을 뜻하지 않는다")을 그대로 적용한다. 아래는 **확인하지 못했다**.

| 항목                                                       | 왜 미검증인가                                                                                                                                                 | 다음 행동                                                                                       |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **프로덕션 Tool/Function 의 `langchain_community` import** | 로컬 DB 에 Tool 0개·Function 0개라 스캔이 **공집합**이었다. "0건 사용"이 아니라 "검증 대상 없음". 프로덕션 DB 는 로컬 에이전트가 접근하지 않는다(AGENTS.md)   | 배포 요청 Issue 에 "프로덕션 워크스페이스 Tool/Function 목록과 import 확인"을 사전조건으로 명시 |
| `middleware.py` 필터 경로 (inlet/outlet) 경유 채팅         | 인증된 세션이 필요하다. 누적 데이터에 임의로 사용자·키를 만들지 않았다. pipelines 로드(6개)만 확인했고 Open WebUI → pipelines 요청 경로는 **실행하지 않았다** | 브라우저 수동 체크리스트에서 pipelines 모델로 채팅                                              |
| OAuth 로그인, RAG 업로드·인용                              | 브라우저 필요                                                                                                                                                 | 수동 체크리스트 (`docs/plan/local-test-workflow.md`)                                            |

## 5. 이 세션에서 바로잡은 것

- **로그 스캔 리다이렉션 오류**: `docker logs … 2>&1 > file` 은 stderr 가 파일에 안 들어간다. Traceback 은 stderr 로 나오므로 첫 스캔의 "0건"은 근거가 없었다. `> file 2>&1` 로 재수집해 0건을 확인.
- **splash 불일치 오판**: 비교 기준을 `backend/open_webui/static/` 한 곳만 잡아 "불일치"로 보였으나 서빙본은 `static/static/`(프론트엔드 정적 디렉터리)와 일치했다. 두 경로를 모두 대조해 해소.
- **`git merge -F -` 는 stdin 을 읽지 못한다**: 병합이 실행되지 않았는데 파이프의 `tail` 이 실패를 가려 `set -e` 가 못 잡았다. `-m` 으로 재실행. push 된 것은 없었음.
- Monitor 도구는 `persistent` 여도 5분에 만료된다. 백그라운드 `until` 루프 + 종료 알림으로 대체.

## 6. 관찰 (이번 병합과 무관, 기존부터)

`docker.yaml` 이 주입하는 `NODE_OPTIONS=12288` 은 Dockerfile 의 뒤따르는 `ENV …=6144` 에 덮여 실제 빌드는 항상 6144 다 (`v0.11.3-kwh.1` 도 동일, 정상 빌드). 조치하지 않음.

## 7. 커밋 / PR / 태그

| 대상                               | 값                                                                    |
| ---------------------------------- | --------------------------------------------------------------------- |
| `integration/v0.11.3`              | `3ca623953` (docs 위생 3커밋 병합) · PR #41 → `main` **열림, 미병합** |
| `integration/v0.11.4`              | `5f3ede34c` (upstream v0.11.4 병합, 부모 `3ca623953` + `0dd6fbd66`)   |
| `feature/upstream-merge-v0.11.4`   | `0dd6fbd66`                                                           |
| `feature/docs-v0.11.4-integration` | `c8eee38e5` + 이 일지 → `integration/v0.11.4` 로 `--no-ff` 병합       |
| 태그                               | `v0.11.4-kwh.1-rc.1` → `5f3ede34c` (immutable, 재발행 금지)           |
| 삭제                               | origin 태그·Release: `v0.11.0`, `v0.11.1`, `v0.10.2`                  |

## 8. 다음 세션 재개 지점

1. 로컬 게이트 컨테이너가 **떠 있다** (`http://127.0.0.1:8082`, pipelines `:9099`). 브라우저 수동 체크리스트를 진행한 뒤 `./scripts/local-test.sh --down`.
2. 프로덕션 Tool/Function 의 `langchain_community` 사용 여부 확인 경로 확정 (§4 첫 행).
3. 수동 검증 통과 후: `feature/docs-v0.11.4-integration` 병합 → PR `integration/v0.11.4` → `main` (`--merge`) → 최종 태그 `v0.11.4-kwh.1` → 최종 태그 게이트 → 배포 Issue.
4. PR #41 과 v0.11.4 PR 의 순서 결정 필요. `integration/v0.11.4` 는 `integration/v0.11.3` tip 에서 분기했으므로 #41 을 먼저 병합하면 v0.11.4 PR 이 그 위에 자연스럽게 이어지고, v0.11.4 PR 을 먼저 병합하면 #41 은 변경 사항이 없어진다.
5. feature 개발은 `integration/v0.11.4` 에서 분기한다.

---

## 06:38 — 배포 하네스 보호 + 러너 최소권한 + 게이트 격리 (병행 세션)

위 v0.11.4 통합과 **별개 세션**에서 수행했다. 프로덕션 컨테이너에는 어떤 조작도 하지 않았고, 모든 단계에서 `openwebui-openwebui-1`의 `StartedAt`(`2026-09-02T09:49:50Z`)과 `/health` 200을 전후 비교해 무중단을 확인했다.

### 1. GitHub ruleset 3건 신설 — `main`·태그·`integration/*` 보호

보호가 전혀 없던 상태(`GET /branches/main/protection` → 404, `GET /rulesets` → `[]`)를 해소했다. 관제 평면 문서의 1회 설정 8번이 미완료였다.

| ID       | 이름                          | 대상                       | 규칙                                               | bypass |
| -------- | ----------------------------- | -------------------------- | -------------------------------------------------- | ------ |
| 22414966 | main protection               | `~DEFAULT_BRANCH`          | deletion, non_fast_forward, pull_request(승인 0건) | 없음   |
| 22414967 | release tags immutable        | `refs/tags/v*-kwh.*`       | deletion, update, non_fast_forward                 | 없음   |
| 22414968 | integration branch protection | `refs/heads/integration/*` | deletion, non_fast_forward                         | 없음   |

설계 판단 3건:

- **required status checks는 넣지 않았다.** `Frontend Build`는 `paths-ignore: [backend/**]`, `Python CI`는 `paths: [backend/**]`로 둘 다 path-filtered다. 문서만 바꾼 PR(이 저장소 PR의 다수)은 두 체크가 **보고되지 않아** 영구 차단된다. 넣으려면 path-aware skip job이 선행돼야 한다.
- **PR 필수 승인은 0건.** 단독 관리자는 자신의 PR을 승인할 수 없어 1건 이상 요구 시 릴리스 병합이 막힌다. PR 경로만 강제하고 self-merge는 유지.
- **태그는 생성 허용, update·deletion만 차단.** 릴리스 루틴의 태그 발행은 그대로 동작하고 immutable 규약이 서버 레벨로 강제된다. 이 세션의 origin 태그 정리(`v0.11.0` 등 bare 태그)는 `v*-kwh.*`에 매칭되지 않아 영향받지 않았다.

PR #41이 05:05Z에 ruleset 하에서 정상 병합된 것으로 설정이 릴리스 흐름을 깨지 않음을 실증했다.

### 2. 운영 워크스페이스를 `origin/main`으로 정렬

`/home/ubuntu/openwebui`가 `feature/docs-korean-agents-guide`(main 대비 1,347 커밋 뒤)에 머물러 있었고, 디스크에 **폐기된 구버전 하네스**가 남아 실제와 불일치했다: `.github/workflows/deploy-production.yaml`(구버전 입력명), `ops/openwebui-deploy`, `ops/install-production-actions-runner`, `docs/manual/github-control-plane-deployment.{ko.,}md`. 이 문서들은 존재하지 않는 `/usr/local/sbin/openwebui-deploy` 방식을 전제했다.

- 정렬 전 미커밋·미추적 전량을 로컬 브랜치 `wip/workspace-snapshot-20260907`(`cf6ed8c2b`)에 커밋해 보존(push 안 함). 브랜치명 날짜는 당시 호스트 시계가 약 29일 뒤처진 상태에서 생성돼 실제(2026-10-06)와 다르다.
- 전환 중 함께 사라진 `data/state_store.db/*.bin`(에이전트 메모리 상태)과 `.opencode/{opencode.json,mem0-mcp.cjs,skills/}`는 폐기 대상이 아니라 복원했다.
- 검증: `docker-compose.deploy.yaml` sha256 `adc5693f…` 불변, `.env.openwebui.oauth` sha256·0600·inode 불변, `openwebui/webui.db` inode 불변, 컨테이너 healthy, `docker compose config` OK.

**후속 필요**: 스냅샷 브랜치에만 남은 고유 문서 9건(jobs log 3건, `docs/plans/` 2건 — main은 단수 `docs/plan/` 사용, `docs/README.md`, `docs/manual` 2건, `docs/references/SECURITY.md`). 보존이 필요하면 정규 경로로 승격해야 한다.

### 3. 러너 최소권한 — sudoers 대신 `NoNewPrivileges`

러너는 `User=ubuntu`로 돌고 `ubuntu`는 `/etc/sudoers.d/90-cloud-init-users`로 `NOPASSWD:ALL`을 갖는다. 즉 **workflow dispatch ≈ 호스트 root**였다.

문서가 제시한 "단일 명령만 허용"안은 실행할 수 없었다 — `ubuntu`와 `root` **패스워드가 모두 locked**(`passwd -S` → `L`)이어서 `NOPASSWD`를 제거하면 sudo를 완전히 상실하고, 남는 경로는 SSM 하나인데 호스트 내부에서 운영자 IAM의 `ssm:StartSession` 허용 여부를 검증할 수 없다(되돌릴 수 없는 잠금 위험).

대신 **sudoers를 건드리지 않고** 러너 유닛에 드롭인을 추가했다:

```
/etc/systemd/system/actions.runner.kwh8121-openwebui-service.openwebui-prod-runner.service.d/10-hardening.conf
[Service]
NoNewPrivileges=yes
```

- 러너와 **모든 워크플로 자식 프로세스**가 setuid 경유 상승을 잃는다(커널 플래그, 해제 불가·상속됨). `ubuntu`의 대화형 SSH sudo는 그대로 → 잠금 위험 0, 드롭인 삭제로 즉시 가역.
- 실증: `systemd-run --uid=ubuntu -p NoNewPrivileges=yes … sudo -n true` → `sudo: The "no new privileges" flag is set…` exit 1. 대조군(속성 없음)은 성공. 적용 후 MainPID `/proc/<pid>/status`에 `NoNewPrivs: 1`.
- 안전성: 배포 워크플로는 sudo를 전혀 사용하지 않는다(docker/tar/curl/gh만). 러너 `busy=false` 확인 후 재시작, GitHub 측 `status=online` 복귀 확인.
- **잔여 리스크(제거 불가)**: 러너가 `docker` 그룹에 있어 docker 소켓 경유 root 등가성은 어떤 방식으로도 남는다. 이 조치는 심층 방어다.

### 4. swap 4GB 추가 — 게이트 동시 실행 시 프로덕션 OOM 사망 방지

게이트는 같은 호스트에 **두 번째 Open WebUI 인스턴스**를 띄운다. 조치 전 상태는 `total 7,816MB / available 1,194MB / swap 0`이고 프로덕션 컨테이너는 `Memory=0`(상한 없음)에 RSS 3.45GiB였다. 이 상태에서 host OOM killer가 작동하면 **RSS가 가장 큰 프로덕션을 선택**한다.

`/swapfile` 4GiB 생성·활성화(`fallocate` → `mkswap` → `swapon`, 0600), `/etc/fstab`에 `/swapfile none swap sw 0 0` 등록(사전 백업 `/etc/fstab.bak-*`, `findmnt --verify` 경고만·오류 없음, `systemctl daemon-reload` 후 `swapfile.swap` active). 무중단·즉시 가역(`swapoff`). `vm.swappiness`는 기본 60 유지 — 필요하면 10으로 낮추는 것이 선택적 후속이다.

### 5. ⚠️ `scripts/local-test.sh`의 프로덕션 파괴 결함 수정

**발견**: 스크립트가 compose를 `-p` 없이 호출하고 `COMPOSE_PROJECT_NAME`도 설정하지 않는다. compose는 프로젝트명을 **프로젝트 디렉터리명**에서 유도하므로, 운영 체크아웃(`/home/ubuntu/openwebui`)에서 실행하면 프로젝트가 `openwebui`로 해석된다. 프로덕션은 `-p openwebui`이고 **서비스명(`openwebui`, `pipelines`)까지 동일**하다.

읽기 전용 `ps`로 증명했다 — 게이트 compose가 프로덕션 컨테이너를 자기 서비스로 인식했다:

```
openwebui-openwebui-1   service=openwebui   v0.11.3-kwh.1   running   ← 프로덕션
openwebui-pipelines-1   service=pipelines                   exited    ← 프로덕션
프로젝트명: openwebui  (프로덕션 라벨 com.docker.compose.project=openwebui 와 동일)
```

따라서 이 디렉터리에서는 `--down`(L158)이 **프로덕션 컨테이너와 네트워크를 삭제**하고, `up -d`(L536)가 **프로덕션을 게이트 스펙으로 재생성**하며, L465–467의 "openwebui가 떠 있으면 down" 분기가 프로덕션에 적용된다. 지금까지 사고가 없었던 이유는 가드가 아니라 **worktree에서 실행해 프로젝트명이 달라졌기 때문**이다(검증함) — 실행 디렉터리에 따라 결과가 갈리는 구조였다.

**수정**: `COMPOSE_PROJECT_NAME="${OPENWEBUI_LOCAL_TEST_PROJECT:-openwebui-local-test}"`를 상단에서 export(스크립트 내 모든 compose 호출이 상속)하고, 프로젝트명이 `openwebui`로 해석되면 **exit 2로 거부**하는 가드를 추가했다. `[FAIL]` 안내 문구의 `docker compose` 예시에도 `-p`를 넣었다.

검증: `bash -n` OK / 가드 강제 시 exit 2 / 수정본으로 `--down` 실행 후 프로덕션 `StartedAt` 불변·healthy·`/health` 200 / 게이트 프로젝트의 `compose ps`는 공집합. RC 이미지 유효성에는 영향 없다 — `local-test.sh`는 런타임 이미지에 포함되지 않는다(최종 스테이지는 `/app/build`와 `./backend`만 COPY).

### 6. §8 재개 지점 정정

§8.1의 "로컬 게이트 컨테이너가 떠 있다"는 **현재 사실과 다르다**. 컨테이너도 `:8082` 리스너도 없고 RC 이미지(5.09GB)도 로컬에 없다. 브라우저 수동 체크리스트는 **게이트를 처음부터 다시 띄워야** 이어갈 수 있다(이미지 pull 3~8분 + 자동 게이트 2~9분).

### 7. 이 섹션에서 바뀐 것

| 대상           | 값                                                                                        |
| -------------- | ----------------------------------------------------------------------------------------- |
| GitHub ruleset | 22414966 / 22414967 / 22414968 (신설)                                                     |
| 호스트         | `/swapfile` 4GiB + fstab 항목, 러너 드롭인 `10-hardening.conf`                            |
| 코드           | `scripts/local-test.sh` — 프로젝트 격리 + 가드                                            |
| 로컬 브랜치    | `wip/workspace-snapshot-20260907` (`cf6ed8c2b`, push 안 함)                               |
| 미결           | 고유 문서 9건 승격 여부, `vm.swappiness` 조정 여부, 게이트 컨테이너 메모리 상한 부여 여부 |
