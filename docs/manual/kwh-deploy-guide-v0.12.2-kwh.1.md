# Production Deployment Guide — `v0.12.2-kwh.1`

이 가이드는 프로덕션 배포 에이전트가 실행하는 릴리스별 명령 소스다. 정상 상태에서는
`Deploy approved production release` workflow(`.github/workflows/deploy-approved-production-release.yaml`)가
§4~§6을 자동 수행하며, 이 문서는 그 입력값·기대 결과·제한을 규정한다.
공통 절차·수동 fallback 명령은 [`kwh-deploy-guide-v0.11.3-kwh.1.md`](./kwh-deploy-guide-v0.11.3-kwh.1.md)와 같고, 바로 이전 릴리스 가이드 [`kwh-deploy-guide-v0.12.0-kwh.1.md`](./kwh-deploy-guide-v0.12.0-kwh.1.md)의 구조를 따른다. 이 문서는 **이번 릴리스에서 달라지는 점만** 적는다.

> **상태: 초안.** 최종 태그·GHCR 빌드·최종 게이트·리허설 값은 `<TBD>`로 남겨 두었고 최종본에서 채운다. 배포 Issue 번호는 Issue 생성 후 dispatch 입력으로 전달한다. 프로덕션 Pipelines 처리(§3.7)는 소유자가 배포 요청 Issue에서 정한다. 승인 시각·Environment 승인은 별도이며 이 문서가 대신하지 않는다.
> **이번 릴리스도 스키마가 바뀐다(마이그레이션 2건). 이미지 롤백만으로는 복구되지 않는다(§8).** 신규 마이그레이션이 `channel_member` 테이블을 **재작성**하고 `auth` 행을 추가한다.

권위 순서: [협업 규약 Protocol v1.2.1](./github-control-plane-local-agent-handoff.ko.md) → [CI/CD 메커니즘](./github-actions-ghcr-release-deployment.md) → [릴리스 루틴](./kwh-release-routine.md) → 이 가이드. 충돌 시 앞선 문서가 이긴다.

---

## 1. Release identifiers

| 항목                            | 값                                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Version                         | **v0.12.2-kwh.1**                                                                                     |
| Main tip SHA (태그 대상, 40자)  | `<TBD: PR 병합 후 main tip 전체 SHA>`                                                                 |
| GHCR image tag (배포 대상)      | `ghcr.io/kwh8121/openwebui-service:v0.12.2-kwh.1`                                                     |
| OCI index digest                | `<TBD>`                                                                                               |
| linux/amd64 digest              | `<TBD>`                                                                                               |
| GHCR short-SHA parity tag       | `ghcr.io/kwh8121/openwebui-service:git-<TBD 7자리>`                                                   |
| GH Actions build Run            | `<TBD>`                                                                                               |
| RC (참고용, 배포 대상 아님)     | `v0.12.2-kwh.1-rc.1` @ `a503c3538` — build run 38665238494                                            |
| Base upstream                   | Open WebUI `v0.12.2` (2026-10-14). `v0.12.0`에서 210 커밋·247 파일. `v0.12.1`을 포함한다              |
| Fork carryovers                 | Koreatimes 브랜드 자산, `WEBUI_NAME` 접미사 제거, `insertSuggestionPrompt=true`, `BUILD_CHANNEL=main` |
| Rollback target (현재 프로덕션) | `ghcr.io/kwh8121/openwebui-service:v0.12.0-kwh.1` (실제 값은 §3.3에서 재확인)                         |

`latest`·`main`·RC 태그를 배포하지 않는다. immutable 최종 태그 또는 git-SHA parity 태그만 유효하다.

digest 확인 방법(개발 측): 개발 머신에는 `docker buildx`가 없어 `docker manifest inspect ghcr.io/kwh8121/openwebui-service:v0.12.2-kwh.1`로 index와 amd64 항목을 읽고, 최종 태그와 parity 태그를 각각 `docker pull`한 뒤 `RepoDigests`가 같음을 확인한다. 이 digest가 §3.5-1 대조의 기준이다.

---

## 2. Deployment overview

**변경 내용:** `v0.12.0-kwh.1` → `v0.12.2-kwh.1`. upstream `v0.12.1`·`v0.12.2` 패치 릴리스 흡수. 병합은 **텍스트·의미 충돌 0건**이다. upstream이 `background_tasks_handler`에서 `assistant_message`를 `.get()`으로 읽도록 바꿨지만 fork의 #47 가드(`ctx.get('assistant_message')` 확인 후 `ctx['model']` 엄격 접근)는 그대로 유지됐다.

### 실행될 Alembic 마이그레이션: **2건** (`b8f2c6d91a04` → `0bd252b206fb`)

| revision       | 내용                                                                                                                                                               | 기존 데이터 영향                                                                                                 |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `c92da83b017f` | `app` 테이블 생성. `channel_member.user_id`를 nullable로 바꾸고 `app_id`·체크 제약(사용자 또는 앱 중 정확히 하나)·유니크·인덱스 추가. `message.app_id`·인덱스 추가 | **SQLite `batch_alter_table`로 `channel_member` 테이블이 통째로 재작성된다.** `message`는 컬럼·인덱스 추가만     |
| `0bd252b206fb` | `user`에는 있는데 `auth`에 없는 사용자에게 **빈 비밀번호·`active=true`** 인 `auth` 행을 추가                                                                       | 기존 `auth` 행은 변경하지 않는다. 대상이 없으면 0행. 빈 해시는 비밀번호 검증에 통과하지 않는 설계(upstream 주석) |

- 프로덕션 revision이 `b8f2c6d91a04`인지 §3에서 확인한다. 다르면 배포하지 않는다.
- 기동 로그에 `Running upgrade` 2줄이 나오는 것이 **정상**이다. 2줄이 아니면(0줄 포함) 전제가 깨진 것이므로 중단하고 에스컬레이션한다.
- `downgrade()`는 두 마이그레이션 모두 구현돼 있다. `c92da83b017f`는 `message.app_id`가 채워진 행이 있으면 `RuntimeError`로 중단한다(앱 기능이 꺼져 있으면 해당 없음). `0bd252b206fb`의 `downgrade()`는 **no-op**이라 추가된 `auth` 행을 되돌리지 않는다. **이전 이미지(`v0.12.0-kwh.1`)는 자동으로 downgrade하지 않으며**, 새 revision을 알지 못해 기동에 실패할 가능성이 높다(§8).
- 로컬 게이트에서 2건 모두 오류 없이 적용됐고, 합성 데이터(채널 2개·멤버 6행·메시지 20건·`auth` 없는 사용자 1명)로 **재작성 전후 내용 동일**과 체크 제약 동작을 확인했다(§9). 프로덕션 규모·실데이터에서의 시간은 `<TBD: 리허설 결과>`.

### 신규 기능·설정 (환경 변수 추가 불필요)

- **Apps (채널 외부 앱)** — 기본 비활성(`ENABLE_APPS`). 켜지 않으면 동작 변화가 없다.
- 그 밖에 Azure OpenAI Realtime 음성, 분석 대시보드 토큰 열, 채널 알림 "멘션만", 스킬 `.skill` 내보내기, 리비전 비교(Compare) 등 UI 기능 추가. 모두 기본 설정으로 영향이 없다.
- **`.env.openwebui.oauth`를 변경하지 않는다.** 설정이 필요한 새 변수는 없다.
- 의존성: 프런트엔드 `mermaid`·`@codemirror/merge` 변경. 백엔드는 선택 패키지 주석 변경뿐이며 제거된 패키지 없음.

### 이번 릴리스에서 프로덕션에 영향이 있을 수 있는 upstream 수정

- **v0.12.1 — 재연결 루프 수정.** "0.12.0부터 로그인 후 새로고침하지 않은 탭이 연결이 끊긴 뒤 초당 여러 번 재연결해 서버에 부하를 준다"는 결함의 수정이다. 현재 프로덕션이 v0.12.0이므로 해당될 수 있다.
- **v0.12.2 — 보안성 수정.** 채널 메시지 메타데이터 서버측 보관, 검색 컬렉션 이름 접근 검사 강화, SCIM 관리자 삭제 차단. 이 fork의 Google OAuth 구성에서는 SCIM이 해당하지 않을 가능성이 크다.
- 그 밖에 도구 선택 유지, 후속 질문·제목 관련 수정, MinerU 4.x 지원 등.

**변경하지 않는 것:** `docker-compose.deploy.yaml`, `.env.openwebui.oauth` 구조, pipelines 이미지, deploy workflow(마지막 변경 `44c3db7ac`, 2026-10-08).

**배포 전략:** `openwebui` 서비스만 `--no-deps`로 교체한다.

---

## 3. Prerequisites verification (§4 이전)

workflow의 검증 스텝이 자동 수행한다. 이번 릴리스에서 특히 확인할 항목:

- 3.1 경로·파일과 3.2 compose project name `openwebui`는 v0.11.3 가이드 §3.1~3.2와 같다.
- **3.3 현재 실행 이미지**를 기록한다. 기대값 `v0.12.0-kwh.1`. 다르면 실제 값이 rollback target이다. workflow는 컨테이너를 조회할 수 없거나 없으면 **서비스 정지 전에** 중단한다.
- **3.4 GHCR digest**: 최종 태그와 parity 태그가 같은 digest로 해석되고 §1 값과 일치해야 한다. 불일치 시 중단.
- **3.4-1 현재 DB revision = `b8f2c6d91a04`.** 운영 DB를 직접 열지 말고 실행 중 컨테이너의 `alembic current`로 읽는다.
- 3.5 `.env.openwebui.oauth`의 `WEBUI_NAME=Koreatimes`, `ENABLE_DB_MIGRATIONS` 미설정 여부는 v0.11.3 가이드 §3.5와 같다. `ENABLE_DB_MIGRATIONS=false`이면 마이그레이션이 실행되지 않아 스키마가 코드보다 뒤처진다. 이 조합은 시험하지 않았으므로 설정돼 있으면 배포하지 않고 소유자에게 확인한다.
- 3.5-1 digest 대조는 dispatch 전 배포 에이전트가 수행한다(workflow는 기록만 한다).
- 3.5-2 `/app/pipelines` 존재·읽기 가능 확인(백업 tar 포함 대상, 부재 시 정지 후 tar 실패).
- **3.6 디스크**: 새 이미지(약 5~6 GB) + 백업 tar(이전 배포 실측 2.66 GB, 데이터 약 3.9 GB) + env 사본. 이전 리허설 스냅샷(약 2.8 GB)과 이전 배포 백업이 호스트에 남아 있을 수 있으므로 배포 시점 여유를 다시 확인한다.
- **3.6-1 배포 전 개수 기록.** Model(사용자 정의)·Tool·Function·Skill·Knowledge·Prompt 개수를 관리자 화면에서 기록한다(직전 보고값: 9·8·29·5·2·8). 이번 마이그레이션은 이들을 갱신하지 않지만 §7.2 대조의 기준이 된다. 채널·채널 멤버·채널 메시지 개수도 함께 기록한다(`channel_member` 재작성 대조용).

### 3.7 Pipelines — 소유자 결정 필요

`v0.12.0-kwh.1` 배포에서는 `check_pipelines=false`(`SKIPPED`)였고 [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34)는 열려 있다. 이번 릴리스의 `check_pipelines` 값은 **배포 요청 Issue에서 소유자가 배포 직전 컨테이너 상태를 보고 결정**한다. `running`이고 9099가 200이면 `true`, 정지·미사용이면 `false`(`SKIPPED`, `PASS`로 기록하지 않음)이다. 배포 중 Pipelines를 기동·재생성하지 않는다.

---

## 4. Pre-deployment backup — 남은 한계

workflow의 `Stop openwebui and back up data` 스텝은 `v0.12.0-kwh.1` 배포 이후 **변경되지 않았다.** 그 배포에서 새 단계(#49 1단계)가 운영 러너에서 처음 실행되어 성공했다(아카이브·env 사본 모두 mode `600`, 이미지 pull은 정지 전 완료, `up --pull never`).

**이전 배포 실측(`v0.12.0-kwh.1`, run 38376927749):** 이미지 pull 2분 39초(정지 전), 백업 단계 4분 28초, 기존 컨테이너 종료→`/health` 완료 약 5분 11초(관측 상한), 전체 job 8분 12초(승인 대기 제외). 백업 tar 2,660,671,162 bytes. 이번 DB는 더 클 수 있으며 **시간을 약속하지 않는다.**

**남은 한계 — 승인자가 알고 승인해야 한다:**

- 정지 후 압축 순서는 그대로다. 압축 시간만큼 서비스가 중단된다. **중단 시간 단축(#49 2단계)은 미구현이다.**
- **실제 배포 백업 tar의 복원은 증명되지 않았다.** `tar -tzf` 목록 검사만 통과했다. 승인 전 리허설이 있었다면 그것은 온라인 스냅샷이며 실제 배포 백업의 복원을 대체하지 않는다(§9).
- 실패 경로(작업 중 실패·중단 시 남는 파일의 권한·복구)는 운영에서 시험되지 않았다.

---

## 5. Deployment execution

### 5.1 Workflow dispatch

| 입력              | 값                                                                          |
| ----------------- | --------------------------------------------------------------------------- |
| `tag`             | `v0.12.2-kwh.1`                                                             |
| `issue_number`    | 이 릴리스의 `Production deployment request` Issue 번호 (Issue 생성 후 확정) |
| `guide_commit`    | 이 가이드의 최종본을 담은 `main` 커밋 전체 SHA                              |
| `check_pipelines` | §3.7에서 결정. **기본값은 체크(`true`)이므로 정지 상태면 반드시 해제**      |

`production` Environment 보호 규칙에 따라 `kwh8121`의 실행별 승인 이후에만 실행된다. Issue 승인과 Environment 승인은 별개다. dispatch 입력은 소유자가 GitHub UI에서 직접 넣는다(개발 에이전트의 `gh workflow run`은 권한 검사에서 프로덕션 배포로 차단된다).

### 5.2 수동 fallback

v0.11.3 가이드 §5.2의 명령을 `OPENWEBUI_IMAGE_TAG=v0.12.2-kwh.1`로 바꿔 쓴다. `--no-deps` 없이 `up`을 실행하지 않는다.

---

## 6. Migration monitoring

기대 로그: alembic 2줄(`Context impl SQLiteImpl.`, `Will assume non-transactional DDL.`) 뒤에 **`Running upgrade` 2줄**: `b8f2c6d91a04 -> c92da83b017f`, `c92da83b017f -> 0bd252b206fb`. 마지막 revision은 `0bd252b206fb`.

다음이 나오면 §8: `Generating new WEBUI_SECRET_KEY`, `Traceback`, `sqlalchemy.exc`, `ModuleNotFoundError`, `Can't locate revision`, 2줄 미만에서 멈춘 `Running upgrade`, `CHECK constraint failed`.

- 마이그레이션은 기동 중 `/health` 이전에 실행된다. `channel_member` 재작성은 행 수에 비례하나 이전 배포에서 6건 마이그레이션이 전체 job 시간에 가려질 만큼 짧았다. 로컬 게이트 부팅은 171초(백업 직후·이미지 pull 포함 전체 18분)였다.
- `/health`는 workflow가 300초까지 폴링한다. 300초를 넘겨도 **마이그레이션 진행 중일 수 있으므로** 이미지 문제로 단정하거나 컨테이너를 재시작하지 않는다. 먼저 `docker logs`로 `Running upgrade` 진행과 `free -m`을 본다.

---

## 7. Post-deployment smoke checklist

새 시크릿 창 또는 하드 리프레시로 수행한다.

### 7.1 Authentication

- [ ] 기존 Google 계정 OAuth 로그인 성공, 새로고침 후 세션 유지, 로그아웃 정상
- [ ] 2단계 인증이 켜지지 않았는지(`ENABLE_MFA` 기본 `False`) 확인

### 7.2 Data integrity

- [ ] 배포 전 채팅 이력·사용자 설정·Knowledge 목록 유지
- [ ] alembic revision = `0bd252b206fb`, SQLite `PRAGMA integrity_check` = `ok`
- [ ] **Model/Tool/Function/Skill/Knowledge/Prompt 개수가 §3.6-1 기록과 같다**
- [ ] **채널·채널 멤버·채널 메시지 개수가 §3.6-1 기록과 같다** (`channel_member` 재작성 검증). 채널을 쓰지 않는다면 0 유지만 확인한다.

### 7.3 Fork carryovers

- [ ] 사이드바 로고·탭 제목·인스턴스명 = `Koreatimes`(`(Open WebUI)` 접미사 없음), `/manifest.json` `name`·`short_name` = `Koreatimes`
- [ ] 스플래시(라이트·다크) = Koreatimes
- [ ] 제안 카드 클릭 → 입력란만 채워지고 자동 전송되지 않음
- [ ] **버전 표시가 `v0.12.2`이고 `(build · …)` 접미사가 없다** (`BUILD_CHANNEL=main`)

### 7.4 Functional smoke

- [ ] 기본 모델에 메시지 전송 → 응답 수신
- [ ] **저장되는 새 채팅에서 제목 자동 생성** 후 로그에 `KeyError`·`Traceback` 없음 (#47). 배포 직후 로그를 `> file 2>&1`로 수집해 스캔한다.
- [ ] 소형 텍스트 문서 업로드 후 질의 → 인용 포함 응답(RAG)
- [ ] Workspace → Models/Tools/Functions/Skills 목록 로드 시 오류 없음
- [ ] **채널 화면**: 채널이 있으면 열어서 기존 멤버·메시지가 보이고, 메시지를 보내면 표시된다(새로고침 후에도 유지). `@` 멘션 목록이 뜬다. 채널 옵션 메뉴에 Notifications(전체/멘션만)가 있다.
- [ ] 관리자 설정에서 Apps가 꺼진 상태다
- [ ] Pipelines 연결 상태는 §3.7 결정에 따른다
- [ ] (선택) 로그인 후 새로고침하지 않은 탭이 연결 끊김 뒤 서버 부하를 올리지 않는다(v0.12.1 수정)

---

## 8. Rollback procedure

**트리거:** §6 금지 로그 출현, `/health`가 자원 병목으로 설명되지 않는 이유로 비정상, §7.1이 전 사용자 로그인을 막음, §7.2 무결성 실패 또는 항목·채널 개수 손실, §7.4 제목 생성 `KeyError` 재발, 채널 화면 오류.

workflow는 컨테이너 기동 **이전** 실패에만 이전 서비스를 자동 복구한다. 기동 이후 실패는 **자동 롤백하지 않고** 컨테이너·로그·DB·백업을 보존한 채 관리자 판단을 기다린다. 판단 전에 아무것도 삭제·덮어쓰지 않는다.

### ⚠ 이미지 롤백만으로는 복구되지 않는다

DB가 `0bd252b206fb`로 올라간 뒤 `v0.12.0-kwh.1` 이미지로 되돌리면, 해당 이미지는 그 revision을 알지 못하므로 기동에 실패할 가능성이 높다. **이 동작을 실제로 시험하지 않았다.** 이미지만 되돌리는 것을 기본 복구 경로로 쓰지 않는다.

### 8.1 Full 롤백 (이미지 + 백업 복원) — 기본 복구 경로

1. 컨테이너를 정지하고 현 상태(DB·로그)를 별도로 보존한다.
2. §4 백업 아카이브(`prod-backup-preupgrade-…-v0.12.0-kwh.1.tar.gz`)로 `openwebui/` 데이터와 `/app/pipelines`를 복원한다.
3. `.env.openwebui.oauth`는 아카이브에 없다. 변경하지 않았다면 그대로 두고, 의심되면 §4의 `0600` 사본과 대조한다(내용을 출력하지 않는다).
4. `OPENWEBUI_IMAGE_TAG`를 §3.3에서 기록한 이전 태그(기대 `v0.12.0-kwh.1`)로 두고 `up -d --no-deps openwebui` → 로그·`/health`.
5. 복원 후 §7.2로 데이터 개수를 확인한다.

**한계:** 실제 배포 백업 tar의 복원은 증명되지 않았다. 백업 시점 이후의 채팅·설정은 사라진다. 승인자에게 이를 알린 뒤 진행한다.

### 8.2 DB downgrade (대안, 미시험)

새 이미지로 `alembic downgrade b8f2c6d91a04`를 실행하면 2건이 역순으로 되돌려진다. 단 `0bd252b206fb`는 no-op이라 추가된 `auth` 행이 남고, `c92da83b017f`는 `message.app_id`가 채워진 행이 있으면 중단한다. **운영 DB에서 시험된 적이 없다.** 8.1이 실패했을 때만 소유자 승인으로 검토한다.

동일 태그를 재빌드·덮어쓰지 않는다. 수정은 `v0.12.2-kwh.2`로 발행한다.

---

## 9. Evidence summary (개발 측)

| 항목                                      | 결과        | 비고                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 병합                                      | PASS        | 텍스트 충돌 0건, 의미 충돌 0건. fork #47 가드·`insertSuggestionPrompt ?? true`·`BUILD_CHANNEL=main` 유지 확인                                                                                                                                                                                                                               |
| 정적 검사 (병합 브랜치)                   | PASS        | `npm ci`(Node 22, 1,155 패키지), `i18n:parse` 변경 0건, prettier(변경 파일) 통과, vitest 4/4, ruff 추적 파일 통과(지적 4건은 untracked 문서), `svelte-check` 5,918건(직전 6,040건) — 병합이 만든 신규 오류 없음. `Chat.svelte:986`의 `insertSuggestionPrompt` 타입 오류는 fork 기존 항목                                                    |
| RC 자동 게이트                            | PASS        | 2026-10-15 `./scripts/local-test.sh v0.12.2-kwh.1-rc.1 --allow-rc`. 부팅 171초, `/health` 200, upgrade 2건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, pipelines 응답, `Traceback`·`KeyError`·`IntegrityError` 0건, `/api/config` `Koreatimes 0.12.2`, `/_app/version.json` = RC 태그 대상                                 |
| 마이그레이션 데이터 보존 (합성 데이터)    | PASS        | 직전 백업 사본에 채널 2·멤버 6·메시지 20·`auth` 없는 사용자 1을 심고 RC 이미지의 alembic으로 적용. `channel_member`·`message`·`channel` 내용 동일, integrity ok, FK 위반 0, 새 컬럼 NULL, 체크 제약이 둘 다 NULL인 행을 거부, 기존 `auth` 행 불변, 누락 사용자에 빈 비밀번호 `auth` 행 추가. **합성 데이터이며 프로덕션 실데이터가 아니다** |
| RC 브라우저 검증 (Playwright, 자동)       | PASS        | 로컬 RC 게이트 인스턴스. 로그인 화면·"What's New"(`v0.12.2`, Koreatimes)·채널 생성·한글 메시지 전송과 새로고침 후 유지·채널 옵션 Notifications·`@` 멘션 목록(Users·Models)·멤버 패널. 콘솔 오류 0건. 로컬 DB에는 채널이 없던 상태에서 새로 만든 것이라 **기존 채널 데이터의 UI 표시는 아니다**                                              |
| RC 수동: OAuth·RAG·브랜드·제목 생성 (#47) | `<TBD>`     | 사용자 확인 결과를 최종본에서 기록                                                                                                                                                                                                                                                                                                          |
| 최종 태그 이미지 게이트                   | `<TBD>`     | `./scripts/local-test.sh v0.12.2-kwh.1` 결과                                                                                                                                                                                                                                                                                                |
| 프로덕션 스냅샷 리허설                    | `<TBD>`     | 소유자 결정. 수행 시 복원 가능성, `channel_member` 재작성, `0bd252b206fb` 동작, 소요 시간                                                                                                                                                                                                                                                   |
| 백업 복원·DB downgrade                    | 미시험      | §4, §8. 실제 배포 백업 tar의 복원은 증명되지 않았다                                                                                                                                                                                                                                                                                         |
| 프로덕션 Pipelines                        | 소유자 결정 | §3.7. 배포 요청 Issue에서 `check_pipelines` 값을 확정한다                                                                                                                                                                                                                                                                                   |

RC 결과를 최종 태그 이미지의 PASS로 대체하지 않는다. 최종 게이트는 별도로 최종 이미지에 대해 수행한다.

### RC 게이트 로그의 ERROR (관측)

- `get_tool_server_data` / `get_tool_servers_data` 2건: 도구 서버 `fastapi-tools-v2:8000` DNS 실패. [Issue #48](https://github.com/kwh8121/openwebui-service/issues/48)과 동일하며 릴리스 무관(수용·무변경 결정).

---

## Appendix. workflow 대조 결과

deploy workflow(`.github/workflows/deploy-approved-production-release.yaml`)의 마지막 변경 커밋은 `44c3db7ac`(2026-10-08)이며 이번 릴리스에서 바뀌지 않았다. `v0.12.0-kwh.1` 가이드의 대조 표가 그대로 유효하다. 배포 에이전트는 dispatch 전에 `guide_commit` 시점의 workflow와 그 표를 한 번 더 대조한다.
