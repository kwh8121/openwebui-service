# v0.11.4-kwh.1 릴리스 준비 핸드오프 (배포 완료, 이전 준비 기록)

> **후속 상태 — 2026-10-07 09:51 UTC:** `v0.11.4-kwh.1`은 [배포 Issue #45](https://github.com/kwh8121/openwebui-service/issues/45)의 승인과 별도 `production` Environment 승인을 거쳐 [배포 run 37600391176](https://github.com/kwh8121/openwebui-service/actions/runs/37600391176)으로 배포됐다. Issue는 브라우저 검수 `PASS with follow-up`으로 닫혔고 사용자는 현행 운영 유지를 결정했다. [당일 작업일지](../jobs/2026-10-07-openwebui-jobs.md)에 결과와 후속 추적 #47·#48·#49가 기록돼 있다. **아래 본문은 04:55–05:16 UTC의 배포 전 준비 스냅샷이며 현재의 미완료 목록이나 새 배포 승인으로 사용하지 않는다.** 새 세션은 [최상위 협업 규약](github-control-plane-local-agent-handoff.ko.md)의 「상태 인지」에 따라 Issue·Actions·원격 Git과 실제 컨테이너를 다시 조회한다.

> **당시 상태:** 개발 에이전트용 인계. 배포 승인이나 릴리스별 배포 가이드가 아니다. 아래 값은 2026-10-07 04:55–05:16 UTC의 관측 스냅샷이며, 실제 작업 전 GitHub와 운영 상태를 다시 읽는다. Protocol v1.2.1 보완은 당시 운영 `main`에 반영되기 전이었다.
>
> **권위:** [협업 규약](github-control-plane-local-agent-handoff.ko.md) → [CI/CD 메커니즘](github-actions-ghcr-release-deployment.md) → [릴리스 루틴](kwh-release-routine.md). 실제 작업 기록은 [2026-10-07 jobs log](../jobs/2026-10-07-openwebui-jobs.md)에 있다.

## 목적과 작업 경계

사용자는 다음 배포를 **2026-10-07 07:55 UTC(16:55 KST) 이후**, 현재 서비스 이용자가 없는 시점에 진행하려 한다. 퇴근 후에도 GitHub `production` Environment의 `kwh8121` 승인에 응할 수 있다고 밝혔다. 이 시간은 가장 이른 재판정 시각이다. 특정 릴리스의 GitHub Issue 승인이나 실행별 Environment 승인을 미리 받은 것은 아니며, 자동 배포도 예약하지 않았다.

이 호스트 `/home/ubuntu/openwebui`는 **프로덕션 배포 전용**이다. 개발 에이전트는 개발 머신에서 릴리스 게이트·수동 검증·가이드·PR을 준비한다. 이 호스트에서 npm 빌드, 로컬 게이트, RC 컨테이너 시험 또는 운영 DB를 이용한 개발 시험을 하지 않는다. 배포 전용 에이전트는 새 세션에서 GitHub Issue·Actions와 커밋된 문서를 직접 읽고, 실제 컨테이너·데이터 상태를 다시 확인한다. OpenViking과 mem0는 배포 승인 또는 세션 재개에 쓰지 않는다.

## 관측된 릴리스 상태

| 항목             | 2026-10-07 관측                                                                                                                                                                                                  | 다음 조건                                                                                                                             |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 원격 브랜치      | `main=2ed7296c`, `integration/v0.11.4=3d8dd299c`; 열린 integration→main PR 없음                                                                                                                                  | 개발 검증 후 integration PR·CI·main 병합                                                                                              |
| RC               | `v0.11.4-kwh.1-rc.1`의 [GHCR build run 37413977492](https://github.com/kwh8121/openwebui-service/actions/runs/37413977492) 성공; [10월 6일 jobs log](../jobs/2026-10-06-openwebui-jobs.md)에 RC 로컬 게이트 PASS | RC 결과를 최종 태그/이미지 PASS로 대체하지 않음                                                                                       |
| 미완료 개발 검증 | RC 기록에 브라우저 OAuth/RAG, 프로덕션 Tool/Function의 `langchain_community` 확인이 남음                                                                                                                         | 결과와 미검증 범위를 개발 증적에 명시                                                                                                 |
| 최종 릴리스      | `v0.11.4-kwh.1` 태그·GHCR 이미지/digest·최종 로컬 게이트 없음                                                                                                                                                    | main 계보의 immutable 태그, 성공한 이미지 build, 최종 이미지 게이트                                                                   |
| 가이드·배포 요청 | `docs/manual/kwh-deploy-guide-v0.11.4-kwh.1.md`와 v0.11.4 `production-deploy` Issue 없음                                                                                                                         | 가이드를 릴리스 경로에 포함하고, Issue에 증적·소유자 결정을 게시                                                                      |
| Pipelines        | 운영 컨테이너 `Exited (137)`; 별도 오래된 checkout에서 생성; [Issue #34](https://github.com/kwh8121/openwebui-service/issues/34) 열림                                                                            | 이번 배포에서 제외한다면 `check_pipelines=false`와 `stopped` 정책을 Issue에 명시 승인. Pipelines PASS로 기록하거나 자동 기동하지 않음 |

배포 호스트는 04:55 UTC에 Open WebUI `v0.11.3-kwh.1`을 `running/healthy` 및 `/health` HTTP 200으로 관측했다. 운영 데이터는 약 3.7 GB이고 SQLite DB·WAL·SHM이 존재한다. `.env.openwebui.oauth`는 존재하며 mode `0600`이었다. 여유 공간 약 24 GB, inode 여유 약 90%와 runner `online/busy=false`는 당시 수치일 뿐이다. 2026-08/09 기존 백업은 존재하지만 이번 점검에서 무결성·복원 가능성은 확인하지 않았다. 비밀값과 DB 내용은 열람하거나 이 문서에 복사하지 않았다.

현재 workflow 입력에는 `check_pipelines`만 있고 `pipelines_snapshot_mode`의 자동 강제는 없다. `stopped`는 Issue에 명시할 운영 판단이며, 새 계획의 자동 검증이 구현되기 전에는 실행자가 현재 상태와 승인 내용을 직접 대조해야 한다.

## 개발 에이전트가 준비할 것

1. [10월 6일 RC 기록](../jobs/2026-10-06-openwebui-jobs.md)을 읽고 남은 브라우저 OAuth/RAG 및 Tool/Function 검증을 마친다. `PASS`, `SKIPPED`, `UNKNOWN`을 실제 검사 범위대로 구분한다.
2. 현재 작업 트리에 있는 세션 연속성 변경을 이 feature 브랜치의 diff로 검토한다. GitHub Issue·Actions와 커밋 문서의 직접 조회가 OpenViking을 대체한다. `.opencode`의 목록 조회 테스트는 21개 통과했지만 실제 Issue #31의 승인 댓글·Pipelines·mount·백업·디스크 조회와 증적 파서가 아직 완성되지 않았다. 운영 호스트의 `.opencode/opencode.json`은 미추적 파일이라 이 브랜치에 없고 플러그인 자동 등록도 검증되지 않았다. 자동 `READY`를 주장하지 않는다.
3. 저중단·완전 보존 절차를 릴리스에 넣으려면 `openwebui/` 전체, `/app/pipelines`, `.env.openwebui.oauth`를 포함한 복구 계약과 사전 복사·정지 후 최종 동기화·기동 후 압축을 구현한다. 실제 크기 이상의 데이터로 **복원 시험과 3회 시간 리허설**을 통과해 `stop→첫 health <=120초`를 입증해야 한다. 초안 계획은 배포 호스트의 `.omx/plans/v0113-deploy-improvement-20261007.md`에만 있고 Git에 아직 없는 미승인 자료다. 계획이 구현·검증되지 않았다면 이번 릴리스가 120초 중단 또는 완전 복구를 충족한다고 주장하지 않는다.
4. `docs/manual/kwh-deploy-guide-v0.11.4-kwh.1.md`를 **실제 적용될 workflow**와 일치하게 작성한다. 마이그레이션 예상, 현재 Compose·mount/env_file 확인, 백업·복원 범위, 디스크 필요량, Pipelines가 이미 중지된 경우, 장애 시 자동 롤백 금지 경계를 분명히 한다. 현재 workflow는 Open WebUI를 멈춘 뒤 tar를 압축하며 `.env.openwebui.oauth`를 백업하지 않고, 백업 후 `compose pull`을 반복한다. 이 결함을 해결하지 않은 채 새 보존·중단 목표를 선언하지 않는다.
5. 문서를 포함한 모든 변경을 `feature/* → integration/v0.11.4 → main`으로 전달한다. integration PR·CI와 개발 검증을 마친 뒤 최종 `v0.11.4-kwh.1` 태그를 main에 발행하고 GitHub Actions GHCR 빌드·digest와 **최종 태그 이미지의 로컬 게이트**를 확인한다. 이 배포 머신에서 이미지를 빌드하지 않는다.
6. 최종 릴리스 증적을 `Production deployment request` Issue에 게시한다. tag, main SHA, GHCR build run/digest, guide commit, 최종 게이트 결과·검사 범위, 마이그레이션 예상, Pipelines `PASS/SKIPPED/UNKNOWN`과 `check_pipelines`, 유효 UTC 작업 시간·중단/복구 정책이 서로 맞아야 한다. 소유자 승인과 실행별 `production` Environment 승인은 별개다.

## 07:55 UTC 이후 배포 에이전트의 재판정

- 원격 main/최종 tag/이미지 build·digest, 릴리스 가이드, 배포 Issue의 최신 소유자 결정과 승인 시간, runner·Environment 구성을 **그때 다시** 조회한다. 이전 RC나 이 문서의 SHA·용량·health를 현재 승인으로 승격하지 않는다.
- 실제 Open WebUI·Pipelines 상태와 Compose 출처, 모든 쓰기 mount/env_file, DB·WAL, 백업/복원 증적, 새 이미지+staging+archive의 동시 점유 공간을 비밀값 없이 확인한다. Pipelines는 이번 workflow가 직접 중지한 경우가 아니면 기동하지 않는다.
- **최종 태그·가이드·Issue 승인·복구 계약 중 하나라도 없거나 `UNKNOWN`이면 dispatch와 서비스 stop을 하지 않는다.** Environment 승인은 dispatch 뒤 GitHub가 요청할 때 별도로 받아야 한다. 마이그레이션 가능성이 있는 새 이미지 기동 뒤에는 DB/이미지를 자동 롤백하지 않는다.

이 인계 문서 자체는 배포 권한이 아니다. 오늘 정한 시간에 필수 증적이 아직 없으면 배포를 연기하고 차단 사유를 GitHub Issue와 jobs log에 남긴다.
