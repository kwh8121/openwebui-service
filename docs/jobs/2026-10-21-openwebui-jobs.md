# 2026-10-21 Open WebUI 작업일지

## 09:24 UTC (기록 시각) — v0.12.3-kwh.1 프로덕션 배포 결과 기록 + Issue #66 종결 (개발 에이전트)

### 수행

1. **배포 승인·실행.** 소유자가 Issue #66에 승인 댓글(09:12 UTC)을 남겼고, `Deploy approved production release` run [39575648854](https://github.com/kwh8121/openwebui-service/actions/runs/39575648854)가 `openwebui-prod-runner`에서 실행됐다(09:16 UTC dispatch). 입력은 `tag=v0.12.3-kwh.1`, `guide_commit=dd826a33113e48253dfe464c5fa0a1819cfa9786`. `check_pipelines`는 `false`(Pipelines `SKIPPED`, 의도적 중지)로 기록됐다.
2. **백업.** 정지 후 백업 `/home/ubuntu/prod-backup-preupgrade-20261021-091659-v0.12.2-kwh.1.tar.gz`(2.7G, mode 600)와 env 사본(mode 600, 내용 미기록). 호스트에 보존 중.
3. **결과.** 09:22 UTC `Deployment success`. 배포 이미지 digest `sha256:b969b7360fd9bcfde23111cfd46f7bbc84f83dc9046472bbd46d42a76b2c72d9`로 가이드 §1의 OCI index digest와 같다. 기술 스모크 PASS(컨테이너 실행, health·version·manifest, 로그 정상). dispatch부터 success까지 약 6분(승인 대기 제외).
4. **브라우저 인수.** workflow는 "사용자 브라우저 인수(OAuth, 모델 대화, 업로드/RAG, 브랜드, 도구) 대기"로 남겼다. 소유자가 "배포 완료"라고 보고했다.
5. **Issue #66 종결.** 결과 요약 코멘트를 남기고 종결했다.

### 판단·한계 (PASS로 읽지 말 것)

- 위 결과는 workflow가 #66에 남긴 코멘트와 소유자 보고에 근거한다. 개발 에이전트는 프로덕션 컨테이너·DB·로그를 직접 조회하지 않았다.
- **소유자의 "배포 완료"는 항목별 기록이 없는 보고다.** 가이드 §7의 개수 대조(Model/Tool/Function/Skill/Knowledge/Prompt, 채널), `Running upgrade` 0줄, 버전 `v0.12.3`·`(build · …)` 접미사 없음, Encrypted channels 꺼짐, 스킬 연결 모델의 응답 지연은 이 기록으로 확인되지 않았다.
- 이미지 롤백과 백업 복원은 시험되지 않았다. 필요하지 않았다.
- 스킬 동작 변경(모델 연결 스킬이 전체 지침을 전송)의 프로덕션 영향은 여전히 미검증이다.

### 다음 재개 지점

- 호스트의 배포 백업(2.7G)과 이전 이미지 정리 시점은 소유자가 배포 에이전트에게 지시한다.
- 소유자가 필요하면 스킬 연결 현황과 토큰 사용 변화를 관찰한다.
- 열린 Issue #48·#49·#34는 이번 릴리스와 별개로 유지.
- 다음 upstream 릴리스가 나오면 `integration/vX.Y.Z`부터 같은 루틴을 재시작한다.
