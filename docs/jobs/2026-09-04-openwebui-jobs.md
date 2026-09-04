# Open WebUI Jobs Log — 2026-09-04

> 직전 세션은 `2026-09-02-openwebui-jobs.md`. v0.11.3 릴리스 사이클과 배포는 그날 완료됐고, 이 파일은 그 이후의 후속 정리를 다룹니다.

## 요약

v0.11.3 사이클의 **잔여 트래커 3건(KOR-25, KOR-24, GitHub #34)을 정리**하고, 그 과정에서 **게이트 2회가 통과했음에도 pipelines 경로가 실제로는 전혀 검증되지 않았다는 사실**을 발견해 원인까지 규명했다. 문서 정합 개선(PR #39)으로 재발을 막았다.

`main` @ `ff428676f`. 프로덕션은 `v0.11.3-kwh.1` 그대로이며 이 세션에서 프로덕션에 어떤 조작도 하지 않았다.

## KOR-25 정리 — PR 번호 오기 정정 후 Done

2026-09-03 다른 세션이 만든 baseline 추적 이슈. Triage 상태로 남아 있었고 "다음 작업" 2건이 이미 낡아 있었다.

| 원문                                    | 실제                                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| deployment-context harness = **PR #37** | **PR #38** (2026-09-03 00:46 병합)                           |
| —                                       | PR #37은 KOR-23 게이트 수정 **작업 기록(docs)** (01:17 병합) |

이슈 생성 시각(01:14)에 #37이 유일한 열린 PR이어서 혼동된 것으로 보인다. 두 항목 모두 완료 상태여서 Done으로 전이했다.

**확인 과정에서 남긴 관찰**: PR #38 하네스는 Linear를 "사용할 수 없는 통합"으로 단정하는데, `AGENTS.md`는 Linear를 4-도구 중 하나로 규정한다. 함께 읽으면 모순으로 보이지만 실제로는 **에이전트별 환경 차이**(Claude Code에는 Linear MCP가 있고 opencode에는 없음)다. 이를 KOR-24에 합쳤다.

## KOR-24 구현 — 배포 문서 정합 개선 (PR #39)

두 스코프 모두 **"문서가 검증되지 않은 전제를 단정해 현실과 어긋난"** 같은 실패 유형이다.

### 스코프 A — 배포 가이드 스펙 v1.0 → v1.1

handoff 문서 §"Per-Release Deploy Guide Template"에 **§"사전조건 기술 규칙"**을 신설했다.

로컬 개발 에이전트는 프로덕션 상태를 조회할 권한이 없는데, 기존 스펙 3번 항목은 작성자가 _검증할 수 있는_ 항목만 상정했다. 그래서 `v0.11.3-kwh.1` 가이드가 전달받은 답변을 근거로 `check_pipelines=true`를 단정형으로 박았고, 실제 프로덕션은 `Exited (137)`이라 4개 절이 배포 시점에 supersede돼야 했다.

수정: 검증 불가능한 런타임 상태에 의존하는 workflow 입력은 고정값이 아니라 **분기 절차**로 쓴다. 각 갈래마다 §7·§9 판정을 `PASS`/`SKIPPED` 중 무엇으로 기록할지 함께 규정한다 — 이게 빠지면 `false`를 골랐을 때 스모크 항목 처리가 다시 공백이 된다.

대상에 PersistentConfig 실효값(env보다 DB 우선)도 포함했다. 기존 가이드 4종은 소급 수정하지 않았다.

### 스코프 B — Linear 가용 범위

`AGENTS.md` Linear 항목에 한 문장 추가. **배포 경로의 권위 증적은 Linear가 아니라 GitHub**임을 명시했고, 이는 5단계가 GitHub Issue에 남는 기존 이유와 맞물린다.

수정 방향을 한쪽으로만 잡았다 — 하네스 문서에 "Claude Code에서는 Linear 사용 가능"을 추가하지 **않았다.** opencode 에이전트가 자기 환경에 없는 통합을 고려할 이유가 없다.

상시 로드 컨텍스트 **줄 수 증가 0** (129줄 유지, +467B). Done 조건이던 분량 억제를 충족했다.

## GitHub #34 정리 — 본문 대조 + 로컬 선행 검증

### 1차: 본문과 현재 사실 대조

| 발견               | 내용                                                                                                                                                  |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **diff 수치**      | #34가 옳다. `middleware.py`는 `+114/-49`(순증 65)이고 내가 쓴 `+163`은 **churn 합계 오표기** — 규모를 2.5배 부풀렸다                                  |
| **깨진 참조**      | §8의 `github-control-plane-deployment.ko.md`는 저장소에 없다                                                                                          |
| **관제 평면 공백** | 워크플로의 `pipelines` 등장 4곳은 전부 검사·백업·상수. **기동 경로 없음**. PR #38 하네스도 `.opencode/` 전체에 `pipelines` 언급 0건이라 메우지 못한다 |

`+163` 오표기는 배포 가이드 §2에서 시작해 계획서 §12.2, 2026-09-02 jobs log, Linear KOR-14/18/24 코멘트, PR #35/#36/#39 본문까지 전파됐다. 고정 가이드는 소급 수정하지 않고 #34 코멘트를 정정 기록으로 남겼다.

### 2차: ⚠️ 게이트 2회가 통과했지만 pipelines는 미검증이었다

`~/openwebui-local-test-pipelines/`가 **비어 있었다**(mtime 2026-07-29, v0.11.3 사이클 이전). RC 게이트와 최종 태그 게이트 **양쪽 모두** Pipelines 런타임이 플러그인 0개로 떠 있었다.

따라서 RC 게이트 기록의 "pipelines 경유 모델 응답 정상"은 **근거가 부족했다** — 로드된 pipeline이 0개면 선택할 pipeline 모델이 없다. 실제로 확인된 것은 서비스 도달성뿐이었다.

### 3차: 로컬 선행 검증 실행 — 진짜 원인은 따로 있었다

프로덕션 조작 없이 로컬에서 검증했다. 그 과정에서 **더 근본적인 원인**을 찾았다.

`.env.local-test`는 올바르게 `OPENAI_API_BASE_URL=http://pipelines:9099`인데, 이 값이 **PersistentConfig(DB)에 덮여 무효**였다.

| #   | 주소                               | enable    | 컨테이너 내부 도달 |
| --- | ---------------------------------- | --------- | ------------------ |
| [1] | `http://host.docker.internal:9099` | **false** | **000 (실패)**     |
| —   | `http://pipelines:9099` (env 값)   | —         | **200**            |

`host.docker.internal`은 이 compose 구성에서 해석되지 않고, 설령 해석돼도 9099는 호스트 `127.0.0.1`에만 바인딩돼 컨테이너에서 도달할 수 없다. 게다가 `enable=false`였다.

**즉 플러그인 유무와 무관하게 애초에 연결 자체가 불가능했다.**

### 검증 결과 — middleware 필터 경로 PASS

주소 교정 + 활성화 + 플러그인 6개 복사 후:

- 플러그인 **6개 전부 로드 성공**(실패 0건, `wikipedia` 의존성 자동 설치), Pipelines가 모델 11개 노출
- openwebui `/api/models`에 **pipeline 모델 11개 노출**(총 22개 중) — `middleware.py` 경유 모델 수집 정상
- `wikipedia_pipeline`로 스트리밍 대화: HTTP 200 / 0.85초 / SSE 3청크 / 본문 366자 도달

```
POST /wikipedia_pipeline/filter/inlet    200 OK    ← inlet
POST /chat/completions  stream:true      200 OK    ← pipe
POST /wikipedia_pipeline/filter/outlet   200 OK    ← outlet
openwebui Traceback / sqlalchemy.exc / Failed to start: 0건
```

**`utils/middleware.py`(+114/-49)가 재구성한 inlet → pipe → outlet 필터 파이프라인이 처음으로 끝까지 실행됐고 정상 동작한다.**

### 부수 확인 — 비스트리밍 빈 응답은 middleware 결함 아님

`stream: false` 요청은 HTTP 200에 빈 본문을 반환한다. **Pipelines 런타임**이 제너레이터 반환 pipe를 비스트리밍 모드에서 소비하지 않기 때문이며 openwebui와 무관하다(inlet 필터는 이 경우에도 정상 호출됐다). 실제 UI는 스트리밍을 쓰므로 운영 영향은 없으나, pipelines 이미지가 가변 태그 `:main`이라는 #34 §7-3 리스크와 맞물린다.

### 로컬 baseline 교정 — 유지 결정

| 변경                                | 내용                                            |
| ----------------------------------- | ----------------------------------------------- |
| `~/openwebui-local-test-pipelines/` | 빈 상태 → `pipelines/*.py` 6개 (`failed/` 제외) |
| DB `openai.api_base_urls[1]`        | `host.docker.internal:9099` → `pipelines:9099`  |
| DB `openai.api_configs["1"].enable` | `false` → `true`                                |

관리자가 **유지**를 결정했다. 원래 값은 애초에 동작하지 않던 오설정이고, 이 상태여야 다음 사이클 게이트가 pipelines 경로를 실제로 검증한다.

원복용 백업을 세션 임시 폴더에서 영구 위치로 옮겼다 — `~/openwebui-local-test-data.backups/openai-config-before-pipelines-fix-20260904.json`. 대상은 `api_base_urls`·`api_configs` 두 키뿐이며 **API 키는 포함하지 않는다.**

openwebui 데이터는 보존: alembic `d4c1a8e37b62`, chat 4 / user 3 / model 369.

### 문서화 — 재발 방지

설정이 로컬 머신 상태로만 존재하면 다음 세션이 같은 문제를 다시 겪는다. `docs/plan/local-test-workflow.md`에 **§"Pipelines 검증 사전 설정"**을 신설해 PR #39에 포함시켰다.

핵심은 **검증 성립 판별 기준**이다.

```
filter/inlet  →  chat/completions  →  filter/outlet     ← 세 줄이 각각 200
```

이 세 줄이 pipelines 로그에 없으면 `middleware.py` 필터 경로는 미검증이다. 이번에 게이트가 2회 통과하고도 실제로는 미검증이었던 이유가 정확히 이 판별 기준의 부재였다.

## 학습

### 1. "게이트 통과"가 "검증됨"을 뜻하지 않는다

게이트는 **자기가 검사하도록 만들어진 것만** 검사한다. `/openapi.json` 200은 "Pipelines 런타임이 살아 있다"는 뜻이지 "pipelines 경로가 동작한다"는 뜻이 아니다. 플러그인 0개, 연결 비활성 상태에서도 이 검사는 통과한다.

→ **검사 항목마다 "무엇이 성립해야 이 항목이 검증된 것인가"를 문서에 명시한다.** KOR-23에서 마이그레이션 assertion을 추가한 것과 같은 종류의 공백이었다.

### 2. PersistentConfig는 env를 조용히 덮는다

`.env.local-test`에 올바른 값이 있어도 DB 값이 우선한다. 이 프로젝트에서 세 번째로 같은 함정에 걸렸다 — `ENABLE_IMAGE_GENERATION`(v0.11.3 계획 §3.3), `ENABLE_LOGIN_FORM`(배포 가이드 §7.1), 그리고 이번 `openai.api_base_urls`.

→ **env 파일을 근거로 런타임 동작을 단정하지 않는다.** 실효값은 DB에서 확인한다. 이 규칙은 KOR-24 스코프 A로 handoff 스펙 v1.1에 반영됐다.

### 3. 오표기가 조용히 전파된다

`middleware.py (+163)`은 churn 합계를 추가 라인 수로 잘못 읽은 것이다. 배포 가이드에 한 번 쓰인 뒤 계획서·jobs log·Linear 코멘트·PR 본문 4곳까지 퍼졌고, 다른 세션이 원본 diff를 다시 계산해서야 잡혔다.

→ **수치는 인용하지 말고 매번 원본에서 계산한다.** 특히 위험 평가에 쓰이는 숫자는 규모 인식을 왜곡한다.

## 커밋 / PR

| PR  | 내용                                                   | 상태                       |
| --- | ------------------------------------------------------ | -------------------------- |
| #39 | 배포 문서 정합 개선 (KOR-24 A+B) + pipelines 사전 설정 | 병합, `main` @ `ff428676f` |

커밋: `d32d7d486`(KOR-24), `d6e02f040`(pipelines 사전 설정) + 병합 커밋 2건.

feature 브랜치 2개 삭제(로컬·원격). 열린 PR 0건, 작업트리 clean.

## Linear 이벤트

| 이슈   | 전이                                                              |
| ------ | ----------------------------------------------------------------- |
| KOR-25 | Triage → **Done** (`verify-passed`), PR 번호 정정                 |
| KOR-24 | Backlog → **Done** (`verify-passed`), 스코프 B 병합으로 제목 조정 |

## 다음 세션 재개 지점

**현재 상태**: `main` @ `ff428676f`. 프로덕션 `v0.11.3-kwh.1` 가동 중. 열린 PR 0건, feature 브랜치 0건, 작업트리 clean.

**열린 작업 1건**:

**GitHub #34** (OPEN) — Pipelines 안전 재기동 + 프로덕션 회귀 검증.

- 스코프 2(회귀 검증)는 **로컬 PASS**로 실패 위험이 크게 낮아졌다.
- 스코프 1(프로덕션 재기동)은 미착수. 별도 요청 Issue + `production` Environment 승인 필요.
- **§7-3(업무상 근거)이 이 Issue의 향방을 결정한다** — 프로덕션이 pipelines 경유 모델을 실제로 사용하는가. 최소 두 릴리스 주기 동안 정지 운영됐고 영향 보고가 없었다. 미사용이면 `won't do`로 닫고 "Pipelines 미사용"을 운영 정책으로 문서화하면 되며, §7-2 관제 평면 공백도 함께 소멸한다.
- **가장 빠른 판별**: 프로덕션 `/app/pipelines` 내용을 읽기 전용으로 확인. 로컬처럼 비어 있으면 답이 "미사용"으로 수렴한다.

**다음 upstream 사이클 시작 시**:

- 로컬 게이트 baseline은 alembic `d4c1a8e37b62` / chat 4 / user 3 / model 369, pipelines 플러그인 6개 로드 + 연결 활성 상태다. 매 사이클 게이트를 실행해 유지한다.
- 게이트 실행 전 `docs/plan/local-test-workflow.md` §"Pipelines 검증 사전 설정"을 확인한다.
- 원격에 `feature/post-issue-31-deployment-harness`가 남아 있다(PR #38 소유, 다른 세션 산출물). 정리 여부는 관리자 판단.

## 사용자 노트

- 설명을 요청받으면 전문 용어를 걷어내고 비유를 써서 다시 설명한다.
- 트래커 정리 시 상태만 바꾸지 말고 **근거를 코멘트로 남긴다** — 나중에 "무엇을 근거로 Done인지" 추적 가능해야 한다.
