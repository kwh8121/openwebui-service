# 2026-10-07 Open WebUI 작업일지

## 04:23 UTC — 배포 개선 계획을 위한 읽기 전용 현황 점검

- **목적:** 다음 배포 작업과 새 세션의 개시 점검에 필요한 예외를 확인했다. 점검 절차와 판정 기준은 로컬 초안 `.omx/plans/v0113-deploy-improvement-20261007.md`의 단위 4에 기록했다. 이 파일은 승인 계획의 정본이 아니며, 승인 후 `docs/plan/`으로 승격해야 한다.
- **Git·릴리스:** 로컬 `feature/deploy-harness-downtime-and-pipelines-drop`는 `origin/integration/v0.11.4`의 `3d8dd299c`와 같다. 원격 `main`은 `2ed7296c`이고 integration은 아직 병합되지 않았다. 열린 PR은 없고, `v0.11.4-kwh.1-rc.1` [GHCR 빌드 run 37413977492](https://github.com/kwh8121/openwebui-service/actions/runs/37413977492)는 성공했다. 최종 `v0.11.4-kwh.1` 태그·이미지, 최종 게이트 증적, 배포 요청 Issue·승인은 관측되지 않아 **지금 배포 dispatch는 BLOCKED**다. 미추적 `.omo/`, `.opencode/mem0-mcp.cjs`, `.opencode/opencode.json`은 기존 로컬 상태로 남아 있다.
- **운영 상태:** `openwebui-openwebui-1`은 `v0.11.3-kwh.1`로 running/healthy이고 `/health`는 HTTP 200이었다. 쓰기 mount는 `openwebui/ → /app/backend/data`다. `openwebui-pipelines-1`은 `Exited (137)`이며 현재 checkout과 다른 `/home/ubuntu/openwebui-integration-v0102`에서 생성됐다. [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34)의 Pipelines 운영 검증은 아직 열려 있어 `PASS`가 아니다.
- **데이터·복구:** 앱 데이터 약 3.7GB, cache 약 2.0GB, vector_db 약 725MB, uploads 약 574MB이며 `webui.db`·WAL·SHM이 존재한다. 디스크 여유 약 24GB, inode 여유 약 90%다. 기존 아카이브 3개가 존재하지만 내용·무결성·복원 가능성은 이번 점검에서 읽지 않았다. 2026-08 아카이브 2개는 mode `0664`다. 운영 `.env.openwebui.oauth`는 mode `0600`이지만 현행 배포 workflow의 백업 대상에는 포함되지 않는다. 새 이미지+staging+후처리 아카이브 동시 공간은 배포 직전에 다시 계산해야 한다.
- **도구·세션 기억:** `git`, `gh`, Docker Compose, `rsync`, `jq`, `tar`, Python 3.12, `/usr/bin/curl` 사용 가능. `sqlite3` CLI는 없지만 Python `sqlite3` 모듈(SQLite 3.45.1)은 있다. 현재 Codex 세션의 mem0 API는 응답했으나 현재 범위의 기억은 0건이다. OpenViking 도구가 이 세션에 없어 watch·최신 문서 검색은 **UNKNOWN**이다. OpenCode의 mem0 MCP 목록 조회는 20초 시간 제한에 걸려 실제 연결을 확정하지 못했다. 프로젝트 `.env`는 Git에서 제외되지만 mode `0664`이며, 값은 출력하지 않았다.
- **조치·다음 재개 지점:** 계획 단위 4에 매 세션·매 릴리스 작업의 읽기 전용 개시 점검을 추가했다. 다음 세션은 이 기록을 현재 상태로 재사용하지 말고 GitHub·컨테이너·데이터·기억 연결을 다시 조회해야 한다. 서비스 stop/start, 이미지 pull/build, 백업·DB 내용 열람, Git ref 변경, 배포 dispatch는 수행하지 않았다.

## 04:36 UTC — 배포 세션에서 OpenViking 의존 제거

- **결정:** 사용자가 OpenViking의 현재 문제를 알리고 배포 절차에서 제외하도록 지시했다. 다음 세션의 현재 배포 상태는 GitHub Issue·Actions와 실제 컨테이너에서, 절차·이력은 Git에 커밋된 `AGENTS.md`·`docs/manual/`·`docs/plan/`·`docs/jobs/`에서 직접 읽는다. mem0는 개인 선호용으로 남기고 배포 정보의 대체 출처로 사용하지 않는다.
- **로컬 변경:** 초안 계획의 개시 점검과 통과 기준, `AGENTS.md`·`CLAUDE.md`·최상위 handoff 규약·릴리스 루틴, OpenCode 배포 컨텍스트 지침의 출처 분류를 갱신했다. handoff Protocol v1.2.1은 관리자 채팅 relay를 GitHub 조회 실패·Issue 모호성 때의 식별자 보충 경로로 낮추며 기존 Issue/workflow/Environment 승인 계약은 유지한다.
- **검증:** OpenCode 플러그인에 OpenViking을 `unresolved`, 커밋된 프로젝트 문서를 `historical context`로 분류하는 테스트를 먼저 추가했다. 두 테스트가 기존 코드에서 예상대로 실패한 뒤 최소 분류 변경으로 각각 통과했다. 실제 #31 Issue/run/container 형식에 맞춘 증적 파서와 새 세션 종단 검증은 여전히 계획의 후속 항목이며, 현재 자동 `READY` 판정을 주장하지 않는다.
- **전달 상태:** 변경은 이 feature 작업 트리에만 있다. 당일 jobs log는 아직 Git 미추적이고 초안 계획은 `.omx/` Git 제외 대상이므로, 다른 머신이나 새 checkout에 전파됐다고 보지 않는다. 승인 계획의 `docs/plan/` 승격과 표준 `feature/* → integration/vX.Y.Z → main` 전달이 필요하다. 운영 서비스·데이터·GitHub 배포 상태는 변경하지 않았다.

## 04:38 UTC — 인계 명령 실행 경로 보완 및 이전 안내 정정

- OpenCode 가드가 새 세션의 PR·배포 Issue·GHCR/배포 Actions 목록 조회를 막는 것을 발견해 정확한 읽기 전용 명령 형식만 추가했다. 릴리스 루틴의 개시 명령도 해당 허용 목록에 맞췄다. 목록 조회는 대상 식별용이며 승인 증적이 아니다.
- 이 문서 04:23 절의 "기억 연결을 다시 조회" 안내는 04:36 사용자 결정 이후 폐기한다. 다음 배포 세션은 외부 기억 서비스 상태를 점검 조건으로 삼지 않고 GitHub·커밋된 프로젝트 문서·현재 런타임을 직접 조회한다.
- 개인 요약 메모 `docs/memo/one-fact-one-home.md`에 이전 OpenViking 설명의 역사적 상태를 표시하고, Issue form의 handoff 프로토콜 링크를 v1.2.1로 맞췄다. 현재 증적 파서가 실제 #31 형식을 처리하지 못하는 후속 과제는 그대로 남아 있다.

## 04:40 UTC — OpenViking 대체 경로 검증과 잔여 제한

- 새 세션의 GitHub PR·배포 Issue·배포 Actions·GHCR Actions 목록 명령 네 개를 실제 실행해 모두 성공했다. 목록은 대상 발견용이며 승인 근거는 아니다. OpenCode 플러그인 테스트 21개가 모두 통과했고, 변경 JavaScript 문법 검사와 `git diff --check`도 통과했다.
- 독립 검토에서 현행 OpenCode 명령과 allowlist가 Issue 승인·결과 댓글, Pipelines, 데이터 mount, 백업, 디스크 상태를 아직 수집하지 못함을 확인했다. 실제 #31 형식과 맞지 않는 증적 파서 문제도 남는다. 초안 계획 단위 5에 이 읽기 범위와 실물 fixture 보완을 명시했고, 최상위 규약과 `/deployment-context` 명령에 자동 `READY` 판정 불가를 표시했다. 미확인 필수 증적은 `UNKNOWN`/`unresolved`로 남겨 dispatch를 막는다.
- 이 변경은 아직 작업 트리의 로컬 수정이다. 초안 `.omx/plans/v0113-deploy-improvement-20261007.md`는 Git 제외 대상이고 이 jobs log도 미추적 상태이므로, 원격 저장소나 다른 checkout의 세션 연속성을 확보했다고 주장하지 않는다. 배포 실행·서비스/데이터 변경은 하지 않았다.

## 04:56 UTC — 3시간 후 배포 예정에 따른 준비 시작

- 사용자는 약 3시간 후 퇴근하여 현재 서비스 이용자가 없을 때 본격 배포할 예정이라고 밝혔다. 이 시점 기준 가장 이른 작업 개시 예상은 **2026-10-07 07:55 UTC(16:55 KST)**다. 이는 배포 Issue의 릴리스별 승인·GitHub `production` Environment 승인 또는 중단 예산을 대체하지 않는다.
- 지금은 GitHub 릴리스/승인 증적과 운영 서비스·데이터의 읽기 전용 재점검을 진행한다. 서비스 stop, workflow dispatch, 이미지/데이터 변경은 예정 시각 및 필수 게이트가 충족되기 전 실행하지 않는다.
- 로컬 점검상 `v0.11.4-kwh.1` 최종 태그와 해당 릴리스 가이드는 없고 RC 태그만 있다. 현행 workflow는 stop 후 압축 백업을 하며 `.env.openwebui.oauth`를 아카이브에 포함하지 않고 백업 뒤 `compose pull`을 재실행한다. 따라서 저중단·완전 보존 개선안은 아직 운영 적용 가능 상태가 아니다. 원격/운영 상태는 병렬 읽기 전용 점검 결과로 갱신한다.

## 04:55–05:00 UTC — 배포 전 릴리스·운영 병렬 재점검

- **릴리스 BLOCKED:** 원격 `main=2ed7296c`, `integration/v0.11.4=3d8dd299c`; 열린 integration→main PR과 그 CI가 없다. RC `v0.11.4-kwh.1-rc.1` 및 GHCR build run `37413977492`는 성공했으나 최종 `v0.11.4-kwh.1` 태그·이미지·digest, 최종 로컬 게이트, `docs/manual/kwh-deploy-guide-v0.11.4-kwh.1.md`, v0.11.4 `production-deploy` Issue·소유자 승인·Environment 실행별 승인은 없다. RC 기록의 브라우저 OAuth/RAG와 프로덕션 Tool/Function 점검도 미완이다. RC를 최종 이미지로 승격하거나 deploy workflow에 dispatch하지 않는다.
- **운영 가용성 READY, Pipelines 별도 BLOCKED/UNKNOWN:** `2026-10-07T04:55:55Z`에 Open WebUI `v0.11.3-kwh.1` running/healthy, `/health` HTTP 200. Pipelines는 2026-08-07부터 `Exited (137)`이고 별도 오래된 checkout에서 만들어졌다. 이번 릴리스에서 제외하려면 `check_pipelines=false`와 `pipelines_snapshot_mode=stopped`가 Issue 승인과 일치해야 하며 Pipelines PASS로 기록하거나 자동 시작하지 않는다. GitHub Issue #34는 계속 열려 있다.
- **보존 사전조건 BLOCKED:** 데이터 루트 약 3.7G, DB·WAL·SHM 존재, `.env.openwebui.oauth` 존재/mode 0600. 가용 공간 약 24G·inode 여유 약 90%는 현재 시점 수치일 뿐 새 이미지+staging+archive 동시 점유 계산은 미완이다. 이전 아카이브는 존재하나 이번 점검에서 무결성·복원 가능성은 확인하지 않았다. 현행 workflow는 env_file을 백업에 넣지 않고 stop 중 2GB급 압축/검증을 수행하므로 새 계획의 완전 보존·120초 중단 게이트를 통과하지 못한다.
- **07:55 UTC 판정 조건:** 최종 main/태그/GHCR 이미지와 릴리스 가이드·최종 게이트·배포 Issue의 소유자 승인, Pipelines 제외 결정, 현재 런타임/공간/복구 증적, 실행별 Environment 승인이 모두 확인돼야 한다. 어떤 필수 항목이 `BLOCKED` 또는 `UNKNOWN`이면 dispatch/stop 금지. 현재 07:55 배포 가능성을 `READY`로 표시하지 않는다.

## 04:57 UTC — GitHub 실행 인프라 읽기 전용 점검

- GitHub `production` Environment가 존재하고 `kwh8121` 필수 reviewer 규칙이 활성화돼 있다. 실행별 승인은 아직 요청되지 않았으며, 작업 시간 도래나 사용자가 없다는 사실로 자동 충족되지 않는다.
- self-hosted `openwebui-prod-runner`는 `online`, `busy=false`, `production` 라벨을 가지고 있다. 이 관측은 04:57 UTC의 일시적 상태이며 배포 시점에 다시 확인한다.

## 04:58 UTC — 07:55 UTC 재판정을 위한 미완료 항목

1. 개발 머신: RC에서 남은 브라우저 OAuth/RAG와 Tool/Function `langchain_community` 점검을 완료하고 결과·미검증 범위를 GitHub/커밋 로그에 남긴다. 프로덕션 호스트에서 로컬 게이트를 대신 실행하지 않는다.
2. 개발 릴리스 경로: `v0.11.4-kwh.1` 릴리스 가이드와 요구된 백업·중단 개선을 검증 가능한 feature→integration→main 경로로 전달한다. 최종 immutable tag의 GHCR build와 digest, 최종 로컬 게이트 증적을 확인한다. 새 저중단 방식은 복원 시험·실제 크기 3회 리허설을 통과하지 못하면 현행 workflow보다 안전하다고 주장하지 않는다.
3. GitHub 통제 평면: 해당 릴리스 `production-deploy` Issue에 tag/main SHA/build digest/guide commit/로컬 게이트/Pipelines 제외 사유·유효 작업 시간대를 게시하고 소유자 결정을 받는다. GitHub `production` Environment의 실행별 승인도 별도다.
4. 배포 호스트: 예정 시각 이후에도 원격 main/태그/Issue/run, runner, 실제 Open WebUI·Pipelines 상태, 모든 mount/env_file, 새 이미지+staging+archive 공간, 백업 보존 범위를 다시 확인한다. 한 필수 게이트라도 빠지면 dispatch·stop하지 않는다.

## 05:16 UTC — 퇴근 후 Environment 승인 가능 여부 확인

- 사용자는 퇴근 후에도 GitHub `production` Environment 승인을 할 수 있다고 답했다. 따라서 승인자 부재를 07:55 UTC 이후 배포의 차단 사유로 기록하지 않는다. 이 답은 특정 릴리스의 배포 Issue 승인이나 실제 workflow 실행별 Environment 승인을 미리 부여한 것은 아니다.
- 남은 `BLOCKED`는 v0.11.4 최종 릴리스/가이드/게이트/Issue 부재와 현행 백업의 env_file 누락, 새 저중단 절차의 미구현·미검증이다. 07:55 UTC 이후에도 실제 승인과 현재 증적을 재확인한다.

## 05:23 UTC — 개발 에이전트 Git 핸드오프 작성

- 사용자는 현재 v0.11.4 최종 릴리스 준비를 진행 중인 개발 세션이 없다고 확인했고, 개발 에이전트가 바로 이어받도록 관련 사항을 Git에 남기라고 지시했다.
- 별도 `feature/v0114-release-handoff` 작업 트리에 `docs/manual/kwh-release-handoff-v0.11.4-kwh.1.md`를 작성했다. 이 문서는 07:55 UTC 이후 희망 일정과 실제 `BLOCKED` 사유, 개발 머신의 릴리스 준비 순서, 배포 머신의 재판정/중단 조건을 담는다. 앞서 검토한 OpenViking 대체·세션 인계 문서/플러그인 변경도 같은 feature 브랜치에 옮겨 검증 후 push한다. 배포 승인이나 새 저중단 workflow 구현으로 취급하지 않는다.

## 05:26 UTC — Git 핸드오프 전달 결과

- 별도 작업 트리 `/tmp/openwebui-v0114-handoff`의 `feature/v0114-release-handoff`에 커밋 `fff96648be8827bbebba03c325f8bf2be8519348`을 만들고 `origin`에 push했다. [draft PR #42](https://github.com/kwh8121/openwebui-service/pull/42)는 `integration/v0.11.4`를 대상으로 한다. CLA 확인란은 사용자를 대신해 체크하지 않았다.
- 커밋에는 개발 핸드오프 문서, 이 작업일지, OpenViking 대체를 위한 권위 문서/Issue form/OpenCode 분류·조회 변경만 포함했다. 미추적 `.omo/`, `.opencode/opencode.json`, `.opencode/mem0-mcp.cjs`와 무시된 `.omx/` 초안 계획, 운영 비밀값·데이터는 포함하지 않았다.
- 검증: OpenCode 플러그인 테스트 21/21 통과, 변경 문서/Issue form의 직접 Prettier 검사 통과, staged diff 공백 검사 통과, 비밀값 패턴 0건. 이 검증은 실제 #31 증적 파서·새 백업 복원·120초 중단을 입증하지 않는다. PR은 **draft**이며 배포 승인이나 main 반영이 아니다.

## 개발 에이전트 — #41 병합 반영 + 핸드오프 수신 (KST 오후)

- PR #41(`integration/v0.11.3` → `main`) 병합 완료(`2ed7296c9`). 10-06 일지의 "미병합" 표기는 작성 시점 기준이다. `integration/v0.11.4` 에 `main` 을 `--no-ff` 병합(`47f30f013`).
- 로컬 `integration/v0.11.4` 가 origin 보다 4커밋 뒤처진 채 병합해 낡은 기반 위에 올렸고, push 전이라 `reset --hard origin/integration/v0.11.4` 후 재병합했다. **브랜치 전환 직후 origin 대비 ahead/behind 를 먼저 본다.**
- 배포 에이전트의 핸드오프(draft PR #42)를 검토했다. 충돌은 이 파일의 add/add 한 곳이었다. 내 일지 커밋은 push 전이라 버리고, #42 병합(`c2bdd01af`) 후 이 섹션으로 append 했다.
- **사용자 결정:** (1) v0.11.4-kwh.1 은 **현행 배포 절차**로 진행한다. 백업 결함(서비스 stop 후 압축, `.env.openwebui.oauth` 백업 누락)은 배포 가이드·Issue 에 명시하며, "120초 중단"·"완전 복구"는 주장하지 않는다. (2) **Pipelines 는 이번 배포에서 제외**: `check_pipelines=false`, 정책 `stopped`, 결과는 `SKIPPED`(Issue #34 유지). (3) OpenViking 제외는 **배포 호스트에만** 적용하고 개발 에이전트 환경은 기존대로 활용한다 — `CLAUDE.md`·`AGENTS.md` 문구 보정.
- RC 게이트 컨테이너 재기동(`v0.11.4-kwh.1-rc.1`, `--no-backup`, 포트 8082) → 브라우저 수동 체크리스트(OAuth, pipelines 채팅, RAG) 대기.

### 다음 재개 지점

1. 수동 체크리스트 결과 → 일지에 `PASS/SKIPPED/UNKNOWN` 구분 기록. `langchain_community` 는 배포 Issue 사전조건.
2. `docs/manual/kwh-deploy-guide-v0.11.4-kwh.1.md` 작성(Pipelines 제외, 백업 결함 명시, 롤백 대상 `v0.11.3-kwh.1`).
3. `integration/v0.11.4` → `main` PR(`--merge`) → 최종 태그 `v0.11.4-kwh.1` → GHCR 빌드·digest → 최종 게이트 → 배포 Issue.

## 개발 에이전트 — 수동 체크리스트 결과 + 가이드 초안

- RC 게이트 재기동(`v0.11.4-kwh.1-rc.1`, `--no-backup`): 자동 `PASS`, 부팅 163초, upgrade 0건.
- **수동 체크리스트(사용자 확인, 로컬 누적 데이터·RC 이미지):** Google OAuth 로그인 `PASS` · pipelines 모델 채팅 `PASS`(middleware 필터 경로) · RAG 업로드·인용 `PASS`.
- **여전히 `UNKNOWN`:** 프로덕션 Tool/Function 의 `langchain_community` 사용 — 로컬 DB 에 Tool/Function 이 없어 검증 불가. 배포 Issue 사전조건으로 넣었다(가이드 §2).
- `docs/manual/kwh-deploy-guide-v0.11.4-kwh.1.md` 초안 작성. Pipelines `SKIPPED`/`check_pipelines=false`, 백업 결함 명시, 롤백 대상 `v0.11.3-kwh.1`. 태그 의존 값(SHA·digest·run·Issue 번호·최종 게이트)은 `<TBD>` — 최종 태그 후 문서 전용 PR 로 채우고 그 병합 커밋을 `guide_commit` 으로 쓴다.

## 개발 에이전트 — 최종 태그 `v0.11.4-kwh.1` 발행 + 최종 게이트

- PR #43(`integration/v0.11.4` → `main`) CI 전부 통과 후 `--merge` 병합(`e901f7724`). 최종 태그 `v0.11.4-kwh.1` 을 그 SHA 에 발행. GHCR 빌드 run `37579260460` success.
- digest: index `sha256:23de12d4…2639`, amd64 `sha256:403d4880…a222`. parity 태그 `git-e901f77` 와 동일 digest 확인.
- **최종 이미지 게이트 `PASS`** (`--no-backup`, 축적 데이터): 부팅 98초, upgrade 0건, `alembic current == heads`, integrity `ok`, `Koreatimes 0.11.4`, `version.json` = 태그 SHA, 로그 `Traceback`·`langchain` 0건.
- ERROR 4건: 도구 서버 미접속 2건(기존과 동일) + `oauth_sessions` `InvalidToken` 2건. 후자는 로컬 브라우저의 이전 RC 세션 쿠키 요청 직후 발생·즉시 signout 처리됨. 원인은 추정이며 확정하지 못했다(가이드 §9에 `관측`으로 기록).
- 가이드 `<TBD>` 를 채워 최종본으로 갱신(문서 전용 PR, 재빌드 불필요). 이후 배포 Issue 게시.

## 개발 에이전트 — 핸드오프 #2·#4 처리 (OpenCode 변경 검토 + workflow 대조)

- **#2 `.opencode` 변경 검토(PR #42 diff):** 변경은 읽기 전용 `gh` 명령 4개의 allowlist 추가(완전 일치 문자열)와 출처 분류 확장(`docs/manual`·`docs/plan`·`docs/references`·`AGENTS.md`·`CLAUDE.md` → `historical context`, `openviking` → `unresolved`)뿐이다. 변형 명령 거부 테스트가 함께 추가됐다. `node --test .opencode/plugin/test/*.test.mjs` 로 **21/21 통과** 재확인(디렉터리 인자로 실행하면 `MODULE_NOT_FOUND` — 실행 방식 문제, 코드 문제 아님). 결함은 발견하지 못했다. 단 핸드오프가 밝힌 한계는 그대로다: 증적 파서·승인 댓글·Pipelines·mount·백업·디스크 조회 미완성, `.opencode/opencode.json` 미추적, `gh workflow run` allowlist 가 `-f` 입력을 받지 못함. **자동 `READY` 를 주장하지 않는다.**
- **#4 workflow 대조:** `deploy-approved-production-release.yaml` 전문을 읽고 가이드와 대조. 서술은 일치했으나 가이드에 **누락 2건**이 있어 반영했다: (a) 백업 tar 가 `/app/pipelines` 를 포함하고 경로가 없으면 서비스 stop **이후** 실패(§3.5-2·§4), (b) workflow 는 image digest 를 Issue 와 대조하지 않고 기록만 하므로 dispatch 전 배포 에이전트가 대조해야 함(§3.5-1). 대조표는 가이드 Appendix.
- 가이드가 바뀌므로 **`guide_commit` 이 갱신된다.** 새 병합 커밋 SHA 로 Issue #45 본문과 안내 댓글을 고친다.
