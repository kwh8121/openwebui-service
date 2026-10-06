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
