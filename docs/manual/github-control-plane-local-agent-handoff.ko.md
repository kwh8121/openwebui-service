# GitHub Control Plane: Local Development Agent Handoff

**Protocol version: v1.2** (2026-07-31)

이 문서는 로컬 WSL 개발 에이전트와 원격 프로덕션 배포 에이전트가 GitHub을 유일한 조율 표면으로 삼아 릴리스·배포·상태 정보를 교환하는 규약이다. 관리자가 두 터미널 사이에서 각 에이전트의 응답을 복사·붙여넣기하는 부담을 제거하는 것이 목적이다.

## 문서 우선순위와 계층

이 문서는 fork 저장소의 릴리스·배포 조율 문서 계층에서 **최상위 권위**를 가진다. 다른 문서와 충돌하면 이 문서가 우선한다.

1. **이 문서** (`docs/manual/github-control-plane-local-agent-handoff.ko.md`) — 로컬↔프로덕션 에이전트 조율 프로토콜
2. `docs/manual/github-actions-ghcr-release-deployment.md` — CI/CD 파이프라인 mechanics (tag 규칙, GHCR 규약)
3. `docs/manual/kwh-release-routine.md` — 일반 릴리스 참고. §7(수동 SSH 배포)은 이 문서에 의해 **DEPRECATED**, 나머지 섹션은 참고용으로 유지
4. Per-release deploy guides (`docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`) — 릴리스별 실행 아티팩트

## 사전 요건 (Prerequisites)

이 프로토콜은 아래 인프라가 준비된 상태에서 완전 작동한다. 실제 릴리스 시 항목이 누락돼 있으면 중단하고 관리자 확인을 받는다.

| 요건                                                                                | 위치                                                          | v1.2 시점 상태                                                                                                                 |
| ----------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `production` GitHub Environment (required reviewer: `kwh8121`)                      | GitHub repo → Environments                                    | ✅ 존재 (2026-07-30 생성)                                                                                                      |
| Per-release deploy guide 파일                                                       | `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`            | ✅ 예시 인스턴스 `v0.11.0-kwh.1` 존재                                                                                          |
| GHCR image build workflow                                                           | `.github/workflows/docker.yaml` (trigger: `v*-kwh.*` tag)     | ✅ 존재                                                                                                                        |
| `Deploy approved production release` workflow                                       | `.github/workflows/deploy-approved-production-release.yaml`   | ✅ v1.2에서 신설. `workflow_dispatch` 입력: `tag`, `issue_number`, `guide_commit`. Environment=`production` 바인딩.            |
| **Production deployment request** Issue form                                        | `.github/ISSUE_TEMPLATE/production_deployment_request.yaml`   | ✅ v1.2에서 신설. 라벨 `production-deploy`, 필수 필드가 §"배포 요청 계약" 스키마와 1:1 대응.                                   |
| self-hosted runner (production Environment 바인딩, labels `self-hosted,production`) | 프로덕션 호스트 (`/home/ubuntu/openwebui`에 접근 가능한 계정) | ✅ `openwebui-prod-runner` 등록 완료 (2026-07-31). labels: `self-hosted`, `Linux`, `X64`, `production`; systemd 서비스 active. |

**Interim mode 정의 (예외 fallback)**: runner가 offline이거나 GitHub Actions 인프라 장애로 workflow를 실행할 수 없을 때만 사람 프로덕션 에이전트가 §"필수 릴리스 흐름"과 per-release deploy guide를 따라 수동 실행한다. 정상 상태에서는 workflow가 동일 동작을 실행하고 Issue에 자동 코멘트를 게시하며, 사람 에이전트 개입은 승인·실패 조사·수정 시에만 필요하다.

## 셀프호스팅 러너 상태 및 유지관리

러너 등록은 완료됐다. 현재 runner는 GitHub repository scope에서 `openwebui-prod-runner`라는 이름으로 등록돼 있으며 `production` custom label을 사용한다. 로컬 에이전트가 Issue를 제출하고 관리자가 `production` Environment를 승인하면 workflow가 이 runner에서 실행된다.

현재 systemd 서비스:

```text
actions.runner.kwh8121-openwebui-service.openwebui-prod-runner.service
```

정상 상태 확인 항목:

- GitHub `Settings → Actions → Runners`에서 `openwebui-prod-runner`가 `Online`
- labels에 `self-hosted`, `Linux`, `X64`, `production` 존재
- systemd 서비스가 `enabled`, `active`
- `ubuntu` 계정이 Docker, GHCR manifest, `/home/ubuntu/openwebui`, `/app/pipelines`에 접근 가능

runner 교체 또는 재등록은 GitHub에서 이전 runner를 제거한 뒤 현재 repository의 최신 runner 등록 절차와 `production` custom label을 사용한다. 기존 릴리스 tag를 이용한 즉시 재배포는 dry-run이 아니며 Open WebUI 중지·백업·재생성을 수행하므로, 다음 승인된 릴리스에서 end-to-end workflow를 검증한다.

## 역할 범위

로컬 개발 에이전트는 코드 변경, CI, RC/스테이징 검증, 최종 릴리스 증적, 프로덕션 배포 요청 Issue 작성, per-release deploy guide 작성 및 커밋을 담당한다. 프로덕션에 SSH 접속하거나 Docker Compose를 실행하고, 운영 데이터를 백업하거나, 프로덕션 배포 workflow를 dispatch하지 않는다.

프로덕션 배포 에이전트는 승인된 Issue를 검토하고, per-release deploy guide를 실행(automation 시 dispatch, interim mode에서 수동)하고, 운영 백업, 배포, 기술 스모크, 장애 대응, Issue 결과 기록을 담당한다.

사용자(관리자, `kwh8121`)는 GitHub `production` Environment를 승인하고, 브라우저 전용 검수를 수행하고, incident 발생 시 롤백/hotfix/다음 릴리스 여부를 결정한다.

## 필수 릴리스 흐름

1. `feature/*` 작업을 `integration/vX.Y.Z`를 거쳐 `main`으로 통합한다.
2. `main` 병합 전에 필수 CI와 로컬 프로덕션 미러 검증(`scripts/local-test.sh <RC tag> --allow-rc`)을 완료한다.
3. 병합된 `main` 커밋에 다음 형식의 최종 annotated tag를 만든다.

```text
v<major>.<minor>.<patch>-kwh.<release>
```

4. **Build and publish GHCR release image** workflow가 성공할 때까지 기다린다.
5. 최종 tag, 전체 `main` SHA, Actions build URL, GHCR image digest를 기록한다.
6. 최종 tag에 대해 로컬 재검증(`scripts/local-test.sh <final tag>`, 축적 데이터 유지)을 수행한다.
7. per-release deploy guide를 `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`로 §"Per-Release Deploy Guide Template" 스펙에 따라 작성한다.
8. deploy guide를 `feature/docs-* → integration/vX.Y.Z → main` 흐름으로 커밋해 안정 경로에서 참조 가능하도록 한다.
9. **Production deployment request** Issue를 §"배포 요청 계약"에 따라 작성해 제출한다.
10. Issue 제출 뒤 중단한다. 사용자가 프로덕션 터미널에 붙여넣을 SSH·Docker Compose·백업·롤백 명령을 제공하지 않으며 배포 workflow도 dispatch하지 않는다.

## Per-Release Deploy Guide Template

각 릴리스는 `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`를 저장소에 커밋한다. 이 파일은 프로덕션 에이전트가 실행하는 유일한 명령 소스이며 아래 섹션을 이 순서로 반드시 포함한다. 표준 인스턴스: `docs/manual/kwh-deploy-guide-v0.11.0-kwh.1.md`.

1. **Release identifiers** — 버전, main tip SHA, GHCR image tag, digest(또는 프로덕션 에이전트가 pull 후 취득 방법), git-SHA parity tag, Actions Run URL, upstream base, fork carryovers 요약, rollback target tag
2. **Deployment overview** — 변경 내용, 실행될 Alembic 마이그레이션 (SHA + 이름), fork 보존 항목 요약
3. **Prerequisites verification** — 경로·파일·compose project·현재 이미지·GHCR auth·env sanity·디스크
4. **Pre-deployment backup (MANDATORY)** — WAL-safe 절차 (stop→tar), backup 경로 기록, 무결성 검증
5. **Deployment execution** — env exports, compose config dry-run, pull, up -d --no-deps
6. **Migration monitoring** — Alembic 로그 예상, "startup complete" 마커, /health polling
7. **Post-deployment smoke checklist** — 소유권별 분할: 7.1 Authentication, 7.2 Data integrity, 7.3 Fork carryovers, 7.4 Functional smoke, 7.5 Version-specific spot check
8. **Rollback procedure** — 8.1 이미지 롤백, 8.2 full 롤백 (backup 복원), 8.3 failed-upgrade 디렉터리 보존
9. **Success markers to record** — 프로덕션 에이전트가 Issue 코멘트에 남길 값 목록
10. **Appendix A. Environment variable reference** — compose env 전체 인벤토리
11. **Appendix B. External references** — 문서 우선순위 재확인

각 guide는 릴리스 스코프다. rollback target, digest, 마이그레이션 목록이 릴리스마다 다르므로 편집 없이 재사용 불가.

## 배포 요청 계약

Issue 제목: `Production deployment request: v<X.Y.Z>-kwh.<N>`

프로덕션 배포 요청에는 반드시 다음을 포함한다.

- 최종 immutable 릴리스 tag (예: `v0.11.0-kwh.1`)
- tag가 가리키는 전체 40자 commit SHA
- 성공한 GHCR build Run URL과 image digest (`sha256:<64-hex>`)
- **Per-release deploy guide 경로 및 참조 SHA** (예: `docs/manual/kwh-deploy-guide-v0.11.0-kwh.1.md` at commit `<SHA>`)
- 로컬 검증 결과 (RC 및 최종 태그 로컬 프로덕션 미러 검증 pass/fail, `scripts/local-test.sh` 버전)
- 예상 마이그레이션과 호환성 위험 (Alembic 신규 마이그레이션 개수 및 ID)
- Fork carryover 검증 결과 (브랜드 자산, `insertSuggestionPrompt=true` 기본, `WEBUI_NAME` suffix 제거)
- 알려진 문제와 사용자 브라우저 검수 항목
- 이전 immutable rollback tag (현재 프로덕션에서 실행 중인 tag)

OAuth credential, package token, API key, DB 내용, cookie, 사용자 데이터는 Issue에 기록하지 않는다.

## 프로덕션 에이전트 Issue 응답 계약

프로덕션 에이전트는 배포 Issue에 아래 단계별 형식으로 상태를 남긴다. 경로, digest, Actions URL은 기록할 수 있지만 비밀값과 민감 로그 전문은 기록하지 않는다.

### 1. 배포 착수

```markdown
## Deployment dispatched

Run: <GitHub Actions URL, or "manual (interim mode)">
Runner: <label, or "human operator">
Target: <release tag>
Estimate: <optional estimate>
Guide: `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md` at commit <SHA>
```

### 2. 진행 체크포인트

```markdown
## Deployment checkpoint

Backup: <path> (<size>)
Migrations: <applied count or "not applicable">
Health polling: started
```

### 3. 성공

```markdown
## Deployment success

Image digest: sha256:<digest>
Backup retention: <path>
Technical smoke: PASS (container health, logs, health/version/manifest, Pipelines API)
Guide followed: `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md` at commit <SHA>
Awaiting user browser acceptance: OAuth, model chat, upload/RAG, branding/splash, custom tools as applicable.
```

### 4. 실패

```markdown
## Deployment failed

Stage: <pre-deploy backup | image pull | migration | health | technical smoke>
Cause: <one-line safe summary>
Run logs: <GitHub Actions URL, or code block ≤50 lines>
Rollback status: <previous image restarted | halted for incident decision | restored from backup>
Guide section: §<N>.<M> of `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`
Next action required: <local agent | maintainer | ready to retry>
```

## 관리자 브라우저 acceptance 코멘트 템플릿

프로덕션 에이전트가 §3(성공) 코멘트를 남긴 후, 관리자는 브라우저 검수를 완료하고 아래 형식으로 Issue에 코멘트를 남긴다. 이 코멘트가 §"완료 기준" 4번을 충족한다.

```markdown
## Browser acceptance

Result: <PASS | PASS with follow-up | FAIL>

Checked:

- OAuth 로그인 및 세션 지속: <observation>
- Brand (로고, 인스턴스명 접미사 없음, splash 라이트/다크, favicon): <observation>
- 제안 카드 UX (자동 전송 안 됨): <observation>
- 모델 대화 (응답 수신): <observation>
- Upload/RAG (문서 → 질의 → 인용): <observation>
- Pipelines (워크스페이스 리스팅 및 연결): <observation>
- 버전별 spot check (예: v0.11.0 UI 재설계): <observation>

Follow-up items (있으면): <목록, 각 항목별 tracking Issue 링크 권장>

Release accepted. <!-- 또는 --> Release rejected: <이유>
```

- `PASS` 또는 `PASS with follow-up` 코멘트 → Issue 닫음. Follow-up은 별도 tracking Issue로 이관.
- `FAIL` → §"장애 처리와 권한"의 "browser acceptance 실패" 행 절차 진행.

## 장애 처리와 권한

| 상황                               | 프로덕션 에이전트 즉시 조치                                                                                | 로컬 개발 에이전트 후속                         | 사용자/관리자 결정                                     |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------ |
| 배포 전 백업 실패                  | 배포 중단. 컨테이너가 이미 멈췄다면 고정 스크립트가 이전 이미지를 재기동한다. Issue에 실패 기록.           | 디스크, 권한, 경로 원인 분석 지원.              | 필요 시 저장공간 또는 권한 조치.                       |
| 이미지 pull 또는 배포 전 검증 실패 | 배포 중단. 컨테이너가 이미 멈췄다면 이전 이미지를 재기동한다.                                              | tag, digest, GHCR build 증적 확인.              | GHCR 권한 또는 패키지 정책 문제 시 조치.               |
| Alembic 마이그레이션 실패          | 새 컨테이너 이후에는 자동 롤백하지 않는다. DB와 로그를 보존하고 Issue를 실패 상태로 기록한다.              | 원인 재현 및 수정 후 새 immutable kwh tag 준비. | 이미지 롤백 또는 백업 복구 여부를 승인.                |
| 새 컨테이너 시작 후 health 실패    | workflow는 실패 처리하고 자동 롤백하지 않는다. 마이그레이션 실행 여부를 확인하고 incident 판단을 기다린다. | 원인 분석 및 수정 릴리스 준비.                  | 이전 이미지 재배포 또는 데이터 복구를 명시적으로 승인. |
| technical smoke 일부 실패          | 영향을 Issue에 기록하고, 기능 영향 범위에 따라 배포 완료 보류 또는 incident 전환을 제안한다.               | 결함 분석, hotfix 또는 다음 릴리스 준비.        | 진행, 롤백, 또는 제한 운영을 결정.                     |
| browser acceptance 실패            | 기술 배포 성공과 사용자 검수를 구분해 Issue를 열어 둔다. 명시적 요청 없이는 롤백하지 않는다.               | 관리자 결정 시 hotfix 세션과 새 릴리스 준비.    | 롤백, hotfix, 다음 릴리스 중 선택.                     |

이미지 롤백은 DB schema를 되돌리지 않는다. 마이그레이션 가능성이 있는 실패에서 이미지 교체나 데이터 이동을 자동화하지 않는다. 검증된 pre-deploy backup 복구는 명시적 승인과 해당 릴리스 가이드의 full rollback 절차가 있을 때만 수행한다.

## 상태 인지

로컬 개발 에이전트의 1차 상태 정보원은 GitHub deployment Issue와 Actions run이다.

1. **관리자 relay (필수 액션)**: 관리자는 프로덕션 에이전트가 §3(성공) 또는 §4(실패) 코멘트를 남긴 뒤, 로컬 개발 에이전트 세션 재개 시 다음 중 하나를 채팅에 붙여넣는다.
   - (a) deployment Issue URL, 또는
   - (b) 해당 Issue 코멘트 verbatim
     이 relay가 프로토콜에서 유일하게 남는 관리자의 chat 액션이다. 나머지 명령·응답 relay는 모두 GitHub Issue와 Actions로 흡수된다.
2. 로컬 개발 에이전트는 해당 Issue와 Actions 결과를 기준으로 hotfix, 다음 kwh 릴리스, 또는 후속 기능 작업을 결정한다.
3. 세션 종료 뒤에는 ScheduleWakeup, 장시간 polling, 또는 로컬 세션 유지에 의존하지 않는다.
4. 확실히 유지되는 15분 이하의 짧은 배포 세션에서만 단기 polling을 예외적으로 사용할 수 있다.

## 로컬 에이전트 handoff 메시지

모든 증적을 채운 뒤 배포 Issue 본문에 아래 형식으로 남긴다. Issue form 미구현 상태(interim mode)에서는 free-form Issue의 상단에 이 블록을 배치한다.

```text
Release ready for production deployment.

Tag: vX.Y.Z-kwh.N
Main SHA: <full SHA>
GHCR build: <Actions Run URL>
Image digest: sha256:<digest>
Rollback tag: <previous final tag>
Deploy guide: docs/manual/kwh-deploy-guide-vX.Y.Z-kwh.N.md at commit <SHA>
Validation: CI and local production-mirror verification passed; <known limitations or "none">.
Browser checks required after deployment: OAuth, real model chat, upload/RAG, branding/splash, and relevant custom tools.
```

프로덕션 배포 에이전트는 Issue 증적을 검토하고, automation 모드에서는 **Deploy approved production release** workflow를 tag와 Issue 번호로 dispatch하며, interim mode에서는 deploy guide를 따라 수동 실행한다. 어느 모드에서든 GitHub는 self-hosted runner 또는 프로덕션 에이전트가 실행되기 전에 `production` Environment 승인을 기다린다.

## 완료 기준

릴리스는 배포 Issue에 다음이 모두 기록돼야 완료된다.

1. 프로덕션 Actions run 성공(또는 실패와 대응 상태) — §3 또는 §4 코멘트로 증적
2. 배포된 image digest 및 backup 경로 — §3 코멘트 본문
3. 기술 스모크 결과 — §3 코멘트 본문
4. 사용자 브라우저 검수 결과 또는 합의된 후속 작업 — §"관리자 브라우저 acceptance 코멘트 템플릿"에 규정된 코멘트

네 항목 중 하나라도 부재하면 tag 존재 여부와 무관하게 릴리스는 아직 open 상태다.

## 규칙

- `main`, `latest`, RC tag, 형식 밖의 tag를 프로덕션 배포 대상으로 요청하지 않는다.
- tag 생성만으로 프로덕션 배포 완료로 간주하지 않는다. production Actions workflow 결과(automation 모드) 또는 프로덕션 에이전트의 §3 성공 코멘트(interim mode)가 공식 배포 기록이다.
- 기존 tag를 재작성하지 않는다. 수정은 검증 후 새 immutable final tag(`-kwh.<N+1>`)로 릴리스한다.
- 관리자는 `production` Environment 승인의 유일한 주체다. 프로덕션 에이전트는 이 게이트를 우회하지 않는다.
- 프로덕션 에이전트는 명시적 Issue 참조 없이 배포를 수행하지 않는다. 모든 workflow dispatch(또는 수동 실행)는 Issue 번호를 포함한다.
- 마이그레이션 또는 health 실패가 보고되면 릴리스 작업을 중단하고 §"장애 처리와 권한"의 해당 행에 따라 진행한다. 이미지 롤백은 DB 마이그레이션을 되돌리지 못할 수 있다.
- 롤백 재배포는 새 tag를 발행하지 않고 이전 immutable tag를 재사용한다.
- 릴리스와 무관한 소통(버그 리포트, 기능 요청, hotfix 스코핑)은 이 프로토콜의 범위 밖이다. 표준 GitHub Issue를 `bug`, `enhancement`, `hotfix` 라벨로 사용하고 관련 릴리스 tag를 본문에 명시한다.

## 버전 관리 (Versioning)

**Protocol version**: v1.2 (2026-07-31)

**호환**:

- Per-release deploy guide 스펙 v1.0 (§"Per-Release Deploy Guide Template"에서 정의)
- `.github/workflows/docker.yaml` (v*-kwh.* tag build)
- `.github/workflows/deploy-approved-production-release.yaml` (v1.2 신설, `workflow_dispatch`)
- `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` (v1.2 신설)
- `production` GitHub Environment (2026-07-30 생성, required reviewer `kwh8121`)

**v1.3 목표 (선택)**:

- 마이그레이션 실패 시 자동 데이터 복원 옵션 (opt-in workflow input) 검토 — 현재는 사람 결정 대기
- Actions Run 완료 시 로컬 개발 에이전트에게 자동 알림 (webhook or scheduled poller) — 세션 재개 자동화
- deploy guide 렌더링 검증 (§"Per-Release Deploy Guide Template" 11 섹션 준수 자동 체크)

**Changelog**:

- **2026-07-31 (v1.2)**:
  - `.github/workflows/deploy-approved-production-release.yaml` 신설 후 안전성 보완. `workflow_dispatch` 입력(`tag`, `issue_number`, `guide_commit`) + `environment: production` (required reviewer 게이트 자동 발동) + `runs-on: [self-hosted, production]`. per-release guide·main 계보 검증 → dispatched 코멘트 → 현재 이미지 캡처 → pull → Open WebUI와 Pipelines의 검증된 WAL-safe 백업 → checkpoint 코멘트 → 새 이미지 up → health/version/manifest/Pipelines API 검증 → success/failure 코멘트 자동 게시. 새 컨테이너 시작 전 실패는 이전 서비스를 재기동하고, 마이그레이션 실패 시 auto-rollback 하지 않는다.
  - `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` 신설. 라벨 `production-deploy`, §"배포 요청 계약" 필드가 form 필드로 1:1 매핑. `Per-release deploy guide (path + commit SHA)` 필드로 §51 fix 계승.
  - `openwebui-prod-runner`를 프로덕션 호스트에 등록. labels `self-hosted`, `Linux`, `X64`, `production`; repository scope; systemd enabled/active; Docker, GHCR, 운영 데이터 경로 접근을 검증했다. 마지막 ⚠️(runner)를 ✅로 전환했다.
  - §"사전 요건" 표의 workflow, Issue form, runner를 모두 ✅로 승격. 정상 배포는 GitHub Actions workflow를 사용하며 interim mode는 runner/infrastructure 장애 fallback으로만 유지한다.
  - `feature/handoff-v1.2-automation → integration/v0.11.0 → main` 흐름으로 통합.

- **2026-07-31 (v1.1)**:
  - §"프로덕션 에이전트 Issue 응답 계약" §1·§3의 `Guide:` 필드가 존재하지 않는 파일을 참조하던 버그 수정 → per-release deploy guide 경로로 정정 (`kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md at commit <SHA>` 포맷).
  - §"사전 요건 (Prerequisites)" 신설. 인프라 인벤토리를 ✅/⚠️로 명시하고 interim mode를 명문화. workflow와 Issue form이 아직 없다는 사실이 문서화되지 않아 다음 릴리스에서 혼란 우려가 있던 gap 해소.
  - §"Per-Release Deploy Guide Template" 신설. 릴리스별 실행 아티팩트 스펙을 11개 필수 섹션으로 규정. `kwh-deploy-guide-v0.11.0-kwh.1.md`를 표준 인스턴스로 지정.
  - §"관리자 브라우저 acceptance 코멘트 템플릿" 신설. 프로덕션 에이전트 §3 코멘트 이후 관리자 응답 스키마 부재로 §"완료 기준" 4번이 파싱 불가능하던 문제 해결.
  - §"문서 우선순위와 계층" 신설. 이 문서가 top authority임을 문서 내부에서 선언. `kwh-release-routine.md §7` 폐기 상태 명시.
  - §"상태 인지" 관리자 relay 액션 명시화 — 유일하게 남는 관리자 chat 액션이 무엇인지 명확화.
  - §"버전 관리" 신설. Protocol version + 호환 목록 + v1.2 목표 + 이 changelog.
  - `feature/docs-handoff-v1.1 → integration/v0.11.0 → main` 흐름으로 통합.

- **2026-07-31 (v1.0)**: 초기 versioned release. 역할 범위, 필수 릴리스 흐름, 배포 요청 계약, 프로덕션 에이전트 Issue 응답 계약(4단계), 장애 처리와 권한 매트릭스, 상태 인지, 완료 기준, 규칙. Commit `51eb61501`, PR #9.

- **2026-07-30 (v0)**: 초안. 로컬 개발 에이전트 최초 작성. `v0.11.0-kwh.1` 배포에 사용된 handoff 방식(관리자가 프로덕션 배포 에이전트에게 deploy guide 전달)으로 실제 배포 성공.
