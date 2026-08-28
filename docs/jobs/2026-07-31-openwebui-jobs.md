# Open WebUI Jobs Log — 2026-07-31

> Resume: `claude --resume 5b199c1c-8f18-482b-911b-74c53ef6000d`

## 요약

- `v0.11.0-kwh.1` 프로덕션 배포는 이전 세션에서 로컬 개발 에이전트가 작성한 `docs/manual/kwh-deploy-guide-v0.11.0-kwh.1.md`를 프로덕션 에이전트가 실행하여 완료된 상태로 확인됨.
- 두 에이전트 간 조율 방식을 문서화한 `docs/manual/github-control-plane-local-agent-handoff.ko.md`를 v0 초안(73줄)에서 **v1.0 확정판(282줄)**으로 확장. Actors/Coordination Surface/Contracts(6.1~6.3)/Per‑Release Guide Template/Incident Matrix/State Awareness/Versioning 추가. 관리자 승인 게이트 + Issue evidence 중심의 **터미널 복사‑붙여넣기 제거** 모델을 정식화.
- `kwh-release-routine.md §7`(수동 SSH 배포)를 protocol v1.0에 의해 **deprecated**로 표기. 인프라 미가용 상황의 fallback으로만 남김.
- 저장소 정리: 머지된 feature 브랜치 6개를 local + remote에서 모두 삭제. PR #9 머지 후 main = `2cd5f2911`, integration/v0.11.0을 fast-forward로 main tip에 동기화.

## 작업 흐름

1. **핸드오프 문서 재검토와 관점 정정**
   - 최초 검토에서 제가 만든 배포 가이드를 "폐기 대상"으로 결론지었으나, 사용자가 실제로 그 가이드를 프로덕션 에이전트에게 전달해 배포를 성공시켰음을 확인.
   - 관점 정정: 두 문서는 상반된 것이 아니라 **2층 모델**(Layer A coordination = handoff doc, Layer B execution = per‑release deploy guide).
   - 우선순위 규칙 갱신 수신: (1) handoff → (2) github-actions-ghcr-release-deployment → (3) kwh-release-routine(§7 폐기) → (4) per-release deploy guides.

2. **핸드오프 문서 v1.0 확장**
   - §1 Prerequisites: 실존/미구현 인프라를 ✅/⚠️ 표로 명시. Deploy workflow와 Issue form은 미구현이나 interim mode로 진행 가능함을 명문화.
   - §2 Actors and Boundaries: 3자(local/prod/maintainer) "Owns / Never does" 매트릭스.
   - §3 Coordination Surface: 각 상태 전이가 어떤 GitHub 아티팩트에 대응하는지 다이어그램.
   - §4 Required Release Flow: 10 스텝으로 재정리, 로컬 프로덕션 미러 검증(v4.2)을 스텝 2·6에 명시.
   - §5 Per-Release Deploy Guide Template: 11개 필수 섹션 규정, `kwh-deploy-guide-v0.11.0-kwh.1.md`가 첫 인스턴스임을 예시.
   - §6.1 Local agent Issue evidence schema: 필수 필드 리스트 + 금지 필드(자격 증명 등).
   - §6.2 Production agent reply contract: 4단계 코멘트 스키마 (dispatched/progress/success/failure).
   - §6.3 Maintainer acceptance contract: browser-only acceptance 코멘트 스키마.
   - §7 Incident Handling Matrix: 7가지 실패 시나리오별 auto vs await-maintainer 결정.
   - §8 State Awareness: 세션 종료 후 상태 인지 경로. Primary=관리자 relay, Fallback=사전 안내, 미지원=long-polling·webhook.
   - §9 Rules: 롤백 authority, tag rewriting 금지, out-of-scope 소통 규정.
   - §10 Completion Criteria: 4개 필수 아티팩트가 Issue에 기록되어야 릴리스 완결.
   - §11 Versioning: protocol v1.0 명시, v1.1 target (workflow+form 자동화), doc hierarchy 명문화, changelog seed.

3. **kwh-release-routine.md §7 deprecation**
   - §7 헤더에 "DEPRECATED (2026-07-31)" 표기.
   - 대체 참조(handoff §4·§5)와 예시 인스턴스(`kwh-deploy-guide-v0.11.0-kwh.1.md`) 링크.
   - 기존 SSH 명령 블록은 fallback용으로 유지, 사용 시 사유를 릴리스 노트+Issue에 기록하도록 명시.

4. **정식 flow로 통합**
   - `feature/docs-deploy-guide-v0.11.0-kwh.1` 브랜치를 재사용해 handoff 확장 + deploy guide + §7 deprecation을 단일 커밋 `51eb61501`로 커밋.
   - Push → `integration/v0.11.0` `--no-ff` 머지 `47080bfe3` → push → PR #9 `--merge` → main tip `2cd5f2911`.
   - `integration/v0.11.0`을 main으로 fast-forward → origin 반영. 다음 kwh 사이클 수집점 유지.

5. **머지된 feature 브랜치 정리**
   - `git merge-base --is-ancestor <sha> origin/main`으로 6개 모두 검증 통과.
   - Local + remote 순차 삭제: `feature/koreatimes-loading-splash`, `feature/local-test-workflow`, `feature/local-test-workflow-v4`, `feature/local-test-workflow-v4.1`, `feature/local-test-workflow-v4.2`, `feature/docs-deploy-guide-v0.11.0-kwh.1`.
   - Remote feature 브랜치 목록: 모두 제거됨 (0건 남음).
   - Local 잔존: `feature/agents-md-deepinit` (이전 세션 결정으로 별도 처리 대상).

## 커밋 / PR

**신규 커밋:**

- `51eb61501` docs: handoff protocol v1.0 + kwh.3/kwh.1 deploy guide + §7 deprecation (3 files, +704/-1)
- `47080bfe3` merge: feature/docs-deploy-guide-v0.11.0-kwh.1 into integration/v0.11.0
- `2cd5f2911` Merge pull request #9 from kwh8121/integration/v0.11.0

**PR:**

- **#9** — https://github.com/kwh8121/openwebui-service/pull/9 (merged, --merge)
  - Title: `docs: handoff protocol v1.0 + v0.11.0-kwh.1 deploy guide + kwh-release-routine §7 deprecation`

**태그:** 이 세션에서 신규 발행 없음 (docs-only 변경, GHCR 트리거 안 됨).

## 브랜치 이동

`feature/docs-deploy-guide-v0.11.0-kwh.1` → `integration/v0.11.0` → `main` → `integration/v0.11.0` (fast-forward 후) → 정리 완료.

## 삭제된 브랜치 (6개)

| 브랜치                                  | 최종 SHA  | 목적                        | main 반영 경로 |
| --------------------------------------- | --------- | --------------------------- | -------------- |
| feature/koreatimes-loading-splash       | edde6e35b | splash 자산 교체            | PR #7          |
| feature/local-test-workflow             | 05e336b2e | v3 로컬 검증 도구           | PR #7          |
| feature/local-test-workflow-v4          | f3dd74bd0 | v4 프로덕션 미러 승격       | PR #7          |
| feature/local-test-workflow-v4.1        | 444a2d180 | cache seed 패치             | PR #7          |
| feature/local-test-workflow-v4.2        | 23f8a069f | tar exit-1 처리             | PR #7          |
| feature/docs-deploy-guide-v0.11.0-kwh.1 | 51eb61501 | handoff v1.0 + deploy guide | PR #9          |

## 학습 사항

- **문서 폐기 결정은 실제 사용 흔적으로 검증해야 한다**: 배포 가이드가 프로덕션 에이전트에게 실제로 소비되어 배포를 완성시킨 흔적을 확인하지 않고 "규칙 위반"만으로 폐기를 제안한 것은 성급한 판단이었다. 문서가 실행 계층(Layer B)에서 정당하게 소비되고 있었고, 조율 문서(Layer A)와는 상반이 아닌 보완 관계였다.
- **2층 모델(Coordination + Execution)이 자연스러운 분해**: 조율 문서는 "누가 무엇을 하는가", 배포 가이드는 "어떻게 하는가". 두 층을 하나로 통합하려는 시도는 규정 과부하와 유연성 저하를 유발한다.
- **인프라 미완성 상태의 문서화 전략은 interim mode 명시**: 이상적 자동화(workflow dispatch + Issue form + self-hosted runner)가 완성되기 전에도 프로토콜이 작동해야 한다. Prerequisites 표에 ✅/⚠️로 명시하고 각 ⚠️ 항목에 대한 fallback을 규정하면 문서는 지금 즉시 사용 가능하다.
- **관리자 승인 게이트는 GitHub Environment로 충분**: `production` Environment의 required reviewer 설정 하나로 사람의 개입 지점을 명확히 하고, 이 승인 없이는 어떤 자동화도 프로덕션에 영향 주지 못하게 강제할 수 있다. 오늘 확인: id 19003379401 (2026-07-30 09:24 KST 생성, reviewer=kwh8121).
- **`feature/docs-*` doc-only shortcut은 폐기**: 기존에는 doc-only 변경을 `feature/docs-* → main`으로 직접 머지했으나, 사용자가 이 우회를 규정 위반으로 취소. 이제 모든 변경은 `feature/* → integration/vX.Y.Z → main`. 감사 추적성 확보.
- **머지된 브랜치 정리는 `git merge-base --is-ancestor origin/main` 검증 후**: 6개 브랜치를 스크립트로 일괄 검증·삭제. Local + remote 순서 준수.

## 다음 후보 작업

- **`.github/workflows/deploy-approved-production-release.yaml` 신규 작성** (protocol v1.1 목표): self-hosted runner에서 workflow가 backup+pull+up+health+smoke을 자동 실행. 파라미터: `tag`, `issue_number`. Environment=`production` 바인딩.
- **`.github/ISSUE_TEMPLATE/production_deployment_request.yaml` 신규 작성** (protocol v1.1 목표): §6.1 필드 form 강제.
- **Self-hosted runner 프로덕션 등록** (관리자 작업): runner label 규정 후 handoff 문서 §1 Prerequisites 갱신.
- **AGENTS.md / CLAUDE.md에 handoff 우선순위 명시**: 세션 시작 시 로컬 에이전트가 즉시 규칙 인지하도록. 별도 doc-only feature 브랜치.
- **`docs/openwebui-*-research.md` 8개 로컬 삭제 상태 처리**: 브랜치 전체에서 반복 등장. 별도 판단(정식 삭제 커밋 or 복원)이 필요.
- **`integration/v0.10.2` 브랜치 처리 결정**: v0.11.0으로 넘어갔으므로 삭제 가능. hotfix 라인 목적 유지 여부는 사용자 결정.
- **local-test-workflow 관련 이슈 후속**:
  - v4.3 후보: `/health` polling window 확장 (60→240초) + `OPENWEBUI_LOCAL_TEST_HEALTH_TIMEOUT` env override.
  - HuggingFace cache permission 이슈 재발 방지 (chown 대신 컨테이너 USER 재정의 검토).

## 미커밋 상태

이 로그 파일 (`docs/jobs/2026-07-31-openwebui-jobs.md`)은 로컬만 저장. 커밋 안 함 (이전 관례 유지).

```bash
git add docs/jobs/2026-07-31-openwebui-jobs.md
git commit -m "docs: add 2026-07-31 openwebui jobs log"
```

---

## 17:03 — v1.2 하드닝 검증 + 다음 세션을 위한 핵심 사항 정리

> Resume: `claude --resume 5b199c1c-8f18-482b-911b-74c53ef6000d`

### 시스템 상태 (다음 세션 시작 시 참조)

**저장소 상태:**

- `main` tip = `576558c6c12c493e1e6a6b39d5c0da3e5053aec2`
- `integration/v0.11.0` = main과 동기 (다음 kwh 사이클 수집점)
- 프로덕션 이미지 = `ghcr.io/kwh8121/openwebui-service:v0.11.0-kwh.1` (변화 없음)
- 미머지 feature 브랜치: 없음
- 잔존 브랜치: `feature/agents-md-deepinit` (처리 대기), `integration/v0.10.2` (종료 라인, 처리 대기)

**컨트롤 플레인 인프라 (모두 ✅):**

- `production` GitHub Environment (required reviewer `kwh8121`)
- Self-hosted runner `openwebui-prod-runner` online, labels `[self-hosted, Linux, X64, production]`, systemd active
- `.github/workflows/deploy-approved-production-release.yaml` (296줄, v1.2 + PR #13 하드닝)
- `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` (132줄)

### 문서 우선순위 (충돌 시 위가 우선)

1. `docs/manual/github-control-plane-local-agent-handoff.ko.md` — **top authority, Protocol v1.2 (2026-07-31)**
2. `docs/manual/github-actions-ghcr-release-deployment.md` — CI/CD mechanics
3. `docs/manual/kwh-release-routine.md` — §7 폐기, 나머지 참고 유지
4. `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md` — per-release execution artifacts

### 릴리스 흐름 규칙 (엄격, 위반 시 workflow가 dispatch 거부)

- **모든 변경 (docs 포함)**: `feature/* → integration/vX.Y.Z → main`. `feature/docs-*` → main 직접 우회 **폐기**.
- **Immutable tag**: 실패 태그 재작성/재빌드 금지. 수정은 항상 `-kwh.<N+1>` 새 태그.
- **관리자 승인 게이트**: 모든 프로덕션 배포는 `production` Environment 승인 필수.

### Workflow가 자동 강제하는 사항 (Issue evidence 준비 시 필수)

Workflow `deploy-approved-production-release.yaml`는 dispatch 시 다음을 검증하고 미충족 시 배포 거부:

1. Tag 형식 `v<X.Y.Z>-kwh.<N>` (RC/main/latest 불가)
2. Tag lineage: `gh api compare/<tag>...main` 결과 `identical` 또는 `behind` (main에 없는 태그로 dispatch 불가)
3. Deploy guide pin: `docs/manual/kwh-deploy-guide-<tag>.md`가 지정 커밋 SHA에 존재
4. Backup 스코프: openwebui + pipelines 통합 (`tar -C ${DEPLOY_DIR} openwebui -C /app pipelines`)
5. Backup 무결성: `tar -tzf` 전수 스캔 통과
6. Pre-start 실패 자동 복원: `OPENWEBUI_STOPPED=true && NEW_CONTAINER_STARTED != 'true'` 조건 시 이전 이미지 재기동. **Post-start 실패는 자동 롤백 안 함** (handoff §"장애 처리와 권한" 준수).
7. Health poll: `/health` + `/_app/version.json` + `/manifest.json` + `:9099/openapi.json` 4개 모두 200 (300초 timeout, 5초 interval)
8. Startup 로그 스캔: `Traceback|Failed to start|sqlalchemy.exc` 검출 시 fail

### 로컬 dev 에이전트가 다음 릴리스에 제출할 Issue evidence 필드

Issue form `Production deployment request` (라벨 `production-deploy`):

- **Release tag**: `v<X.Y.Z>-kwh.<N>` (main tip에서 tag)
- **Main tip SHA**: 40자 full SHA
- **GHCR build Run URL**
- **Image digest**: `sha256:<64-hex>` (`docker inspect --format='{{index .RepoDigests 0}}'`)
- **Deploy guide (path + commit SHA)**: `docs/manual/kwh-deploy-guide-<tag>.md at commit <SHA>` — **SHA는 반드시 main에 머지된 최종 커밋** (workflow validation 통과 조건)
- **Rollback tag**: 현재 프로덕션 실행 중인 태그 (지금 = `v0.11.0-kwh.1`)
- **Local verification**: `scripts/local-test.sh v4.2` 결과 (RC + 최종 태그)
- **Migration risk**: Alembic 신규 마이그레이션 목록 + non-reversibility
- **Fork carryovers**: 브랜드 자산, `insertSuggestionPrompt`, `WEBUI_NAME` suffix removal 보존 확인
- **Browser checks required**: 관리자 확인 항목 목록

### 프로덕션 시스템 좌표 (변경 시 workflow env: 블록 수정 + handoff §"사전 요건" 갱신 필요)

- Deploy dir: `/home/ubuntu/openwebui`
- Compose file: `/home/ubuntu/openwebui/docker-compose.deploy.yaml`
- Env file: `/home/ubuntu/openwebui/.env.openwebui.oauth`
- Data (openwebui): `/home/ubuntu/openwebui/openwebui` (webui.db 포함)
- Data (pipelines): `/app/pipelines`
- Compose project: `openwebui`
- Backup dir: `/home/ubuntu`

### 관리자 액션 (정상 배포 시 최소 4가지만)

1. `production` Environment 승인 클릭
2. 프로덕션 에이전트 `## Deployment success` 코멘트 확인
3. 브라우저 acceptance 검수 → `## Browser acceptance` 코멘트 게시 (PASS/FAIL + 항목별)
4. 다음 세션 재개 시 로컬 dev 에이전트에게 Issue URL 또는 최종 코멘트 1건 relay

### `scripts/local-test.sh` v4.2 특성 (다음 릴리스 검증에서 반드시 사용)

- 기본 모드: 데이터 보존 (프로덕션 upgrade 시뮬레이션)
- 자동 백업 (`~/openwebui-local-test-data.backups/`)
- Tar exit=1 관용 (파일 read-중-변경 warning 무시)
- Cache seed 자동 (필요 시 `--reseed-cache`로 강제)
- `--fresh` 로 empty DB 검증 (신규 설치)
- `--allow-rc` 로 RC 태그 검증
- Permission denied 발생 시: `sudo chown -R $(id -u):$(id -g) ~/openwebui-local-test-data ~/openwebui-local-test-pipelines` 후 재실행 (HF cache 관련 알려진 issue)

### Fork 커스터마이징 touchpoints (upstream 머지마다 확인 필수)

- `backend/open_webui/env.py:842` — WEBUI_NAME suffix 강제 제거 유지
- `src/lib/components/chat/Chat.svelte` — `insertSuggestionPrompt ?? true` (v0.11.0에서 line 664)
- `src/lib/components/chat/Settings/Interface.svelte` — 기본 `true` + 토글 UI
- `static/static/*` + `backend/open_webui/static/*` — Koreatimes 브랜드 자산 (favicon/logo/splash 라이트+다크/manifest)
- `site.webmanifest` (양측) — name/short_name = `Koreatimes`
- `.github/workflows/docker.yaml` — `v*-kwh.*` tag trigger + upstream QEMU/Prepare CI Dockerfile 스텝
- `.gitignore` — CLAUDE.md 예외 (upstream 관례 제거)

### 이번 세션 처리 이력

**PR 흐름 (integration-only, doc shortcut 없음):**

- PR #10: handoff v1.0 → v1.1 (broken ref fix + Prerequisites + templates + hierarchy + versioning)
- PR #11: handoff v1.2 (deploy workflow + Issue form 신설)
- PR #12: workflow 하드닝 (integration/v0.11.0)
- PR #13: 하드닝 승격 → main
- PR #14: 문서 formatting (integration)
- PR #15: 러너 등록 완료 반영 → main

**검증 완료 커밋:**

- `ba31d0fc8` 하드닝 원본 (배포 에이전트 작업)
- `59f94594e` 러너 상태 문서화
- `576558c6c` main tip (PR #15 머지)

### 미완/보류 사항 (blocking 아님)

- **v1.3 옵션 목표** (handoff §"버전 관리"): 마이그레이션 실패 시 자동 데이터 복원 opt-in / 로컬 dev 에이전트 auto-resume / deploy guide 템플릿 linter
- **`docs/openwebui-*-research.md` 8개 로컬 삭제 상태**: 세션 전반 반복 등장. 정식 삭제 커밋 or 복원 결정 필요
- **`feature/agents-md-deepinit`**: 오래된 로컬 브랜치, 처리 대기
- **`integration/v0.10.2`**: 사실상 종료 라인, 삭제 or hotfix 라인 유지 결정 대기
- **AGENTS.md / CLAUDE.md에 handoff v1.2 우선순위 명시**: 별도 doc feature 브랜치로 처리 가능
- **v1.2 changelog에 하드닝 세부 backfill 여부**: 배포 에이전트 하드닝 내용이 현재 changelog에 반영되지 않음. v1.2.1 또는 v1.3 시 backfill 판단

### 메모리 시스템 상태 (참고)

- **mem0 MCP 서버**: 이 세션에서 disconnect 상태 (플러그인 재시작 시 복구)
- **자동 메모리** (`~/.claude/projects/.../memory/`): hook가 mem0 사용 강제로 파일 쓰기 차단
- **결과**: 세션 간 지속 메모리는 이 jobs log가 유일 실용 경로 — 세션 재개 시 자동 로드, 관리자가 시각화 가능, 감사 추적 확보

### 미커밋 상태

이 append section도 로컬만 저장 (관례 유지). 필요 시:

```bash
git add docs/jobs/2026-07-31-openwebui-jobs.md
git commit -m "docs: append 2026-07-31 17:03 openwebui jobs entry"
```
