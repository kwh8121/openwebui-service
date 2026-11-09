# 2026-11-09 Open WebUI 작업일지

## 11:55 UTC (기록 시각) — upstream v0.13.3 통합 및 최종 릴리스 준비 (개발 에이전트)

### 상태 인지·결정

- 공식 upstream [v0.13.3](https://github.com/open-webui/open-webui/releases/tag/v0.13.3)을 확인했다. 처음 참고한 검색 결과의 v0.13.0은 오래된 정보였고 사용자의 지적에 따라 GitHub release API와 공식 tag를 재조회해 바로잡았다.
- 사용자 요청에 따라 GitHub Issue #49와 #34를 종결했다. 현재 프로덕션 기준은 배포 완료 Issue #71의 `v0.12.4-kwh.1`이며, 배포 직전 프로덕션 에이전트가 실제 런타임을 다시 확인해야 한다.
- 기존 미추적 Wire Desk 문서 8개는 건드리지 않았다.

### 수행·증적

1. `feature/upstream-merge-v0.13.3`에서 공식 tag를 병합하고 `integration/v0.13.3`에 no-ff 병합했다. fork Docker workflow·브랜드 자산, `insertSuggestionPrompt ?? true`, `WEBUI_NAME` 접미사 제거, `BUILD_CHANNEL=main`, middleware guard를 보존했다. upstream의 사용하지 않는 `actions.lock`은 제거했다. upstream 변경 참고는 `docs/references/openwebui-v0.13.3-release-notes.md`에 기록했다. feature merge `dc8692222`, integration merge `616c53719`.
2. RC.1 `v0.13.3-kwh.1-rc.1` GHCR [run 42590328381](https://github.com/kwh8121/openwebui-service/actions/runs/42590328381) 성공. 축적 데이터의 업그레이드 전 자동 백업을 생성했고 Open WebUI·Pipelines tar 전체 검사를 통과했다. 최초 로컬 게이트는 호스트 디스크 I/O 대기와 저장된 Function의 `yfinance` 계열 의존성 설치 중 `/health` 1200초 타임아웃. 동일 이미지·데이터 재검증은 PASS: Alembic 신규 6건, head `9f6c2a8d1b43`, SQLite integrity `ok`, `/health` 200, Pipelines API 200.
3. 백엔드 pytest 3건이 upstream의 신규 `get_verified_user_by_id(user.id)` 확인 때문에 기존 `user=object()` fixture에서 실패했다. `feature/v0.13.3-background-test-fixture`에서 fixture만 실제 사용자 ID와 인증 조회 mock으로 수정했다. 동일 RC 이미지에서 3건 PASS, Ruff format PASS, 제품 코드 변경 없음. feature commit `b09e647af`, integration merge `de2661c182a588ccf6b03c62a5dd7c4ca85f7926`.
4. RC.2 `v0.13.3-kwh.1-rc.2` GHCR [run 42604702666](https://github.com/kwh8121/openwebui-service/actions/runs/42604702666) 성공. 같은 축적 데이터 로컬 게이트 PASS: `/health` 200(227초), Alembic current=heads `9f6c2a8d1b43`, SQLite integrity `ok`, Pipelines API 200, 이번 부팅 upgrade 0건.
5. [PR #72](https://github.com/kwh8121/openwebui-service/pull/72)의 Format & Build, Unit Tests, Ruff Format 3.11/3.12, RC.2 build 모두 PASS. merge commit `25afc16dc2c4c39ac7271c331fa2aff9ebadcdc1`으로 `main`에 병합했다. 최종 annotated tag `v0.13.3-kwh.1`을 이 SHA에 발행했고 GHCR [run 42607439192](https://github.com/kwh8121/openwebui-service/actions/runs/42607439192) 성공했다.
6. `v0.13.3-kwh.1` 최종 GHCR OCI index digest `sha256:f75f101cb58e3186b93115e499c69f571ab23c054d4b6e809c82c9e42ede493c`; `git-25afc16` parity tag도 동일 digest임을 확인했다. 최종 로컬 게이트는 축적 데이터에서 자동 백업 후 PASS: `/health` 200(439초), Alembic current=heads `9f6c2a8d1b43`, SQLite integrity `ok`, Pipelines API 200, upgrade 0건. 배포 가이드 `docs/manual/kwh-deploy-guide-v0.13.3-kwh.1.md`는 [PR #73](https://github.com/kwh8121/openwebui-service/pull/73)으로 `main` merge commit `04ed7eedeab7e46a429db36d0345f0e2c435e2d6`에 반영했다. [배포 요청 Issue #74](https://github.com/kwh8121/openwebui-service/issues/74)를 제출하고 `OPEN` 상태와 본문을 확인했다.

### 마이그레이션·롤백

`0bd252b206fb → c41f8d9e2a10 → 6f8c2a91d4e7 → e42c8f710a36 → 8bc7e5a902d1 → 6a23bd107e54 → 9f6c2a8d1b43` (6건). 운영 배포 후 이전 이미지로만 되돌리는 것은 안전한 복구 경로가 아니다. 배포 직전 WAL-safe 백업과 검증된 full restore가 필요하다. 롤백 실행은 관리자 명시 승인 대상이다.

### 검증 한계·다음 재개 지점

- 로컬 npm 설치는 이전 `node_modules`의 비정상적으로 느린 파일시스템 순회 때문에 중단했다. 기존 디렉터리는 원위치로 복구했고, PR CI의 Frontend Format & Build·Unit Tests가 통과했다. 로컬 svelte-check는 upstream baseline 오류 때문에 합격 기준이 아니며 실행하지 않았다.
- 브라우저 OAuth 로그인, 채팅·RAG, 탭/사이드 채팅, HTTP 편집, Open Terminal, Pipe 호환성은 자동 게이트만으로 판정할 수 없어 배포 Issue의 관리자 검수 항목으로 남긴다.
- 로컬 축적 데이터에 저장된 Tool 서버 `fastapi-tools-v2:8000` DNS 오류 2건은 기존 미러 환경에서도 관측된 항목이다. 서버 0개로 초기화됐고 로컬 게이트는 PASS했다. 프로덕션의 실제 Tool 서버 상태는 배포 전에 조회한다.
- 다음 단계는 프로덕션 에이전트가 Issue #74와 배포 가이드를 따라 실제 컨테이너·DB·디스크·백업·Pipelines 상태를 다시 조회하고, 소유자 및 GitHub `production` Environment 승인 후 배포하는 것이다. 배포 workflow의 health timeout은 300초인 반면 최종 로컬 부팅은 439초였으므로 시작 로그와 호스트 I/O를 주시한다. 개발 에이전트는 프로덕션 workflow를 dispatch하지 않았다.
