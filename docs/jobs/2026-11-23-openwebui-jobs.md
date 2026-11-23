# 2026-11-23 Open WebUI 작업일지

## 11:22 KST — upstream v0.13.4 통합·로컬 검증·배포 요청 (개발 에이전트)

### 상태 인지·결정

- [공식 upstream v0.13.4](https://github.com/open-webui/open-webui/releases/tag/v0.13.4)를 최신 릴리스로 확인하고, 직전 성공 루틴인 [2026-11-09 작업일지](./2026-11-09-openwebui-jobs.md)와 배포 완료 [Issue #74](https://github.com/kwh8121/openwebui-service/issues/74)를 따라 진행했다. Issue #74의 마지막 성공 운영 태그는 `v0.13.3-kwh.1`이다. 현재 운영 태그·DB는 직접 관측하지 않았으므로 배포 에이전트가 재확인해야 한다.
- 기존 미추적 Wire Desk 계획 문서 8개는 건드리지 않았다. 이 호스트에서 프론트엔드 프로덕션 빌드는 실행하지 않고 GitHub Actions GHCR 빌드를 권위 증적으로 사용했다.

### 수행·증적

1. `feature/upstream-merge-v0.13.4`에서 공식 tag `0666e59d26a4d056e0bacee41742486badd71cf8`을 병합하고 `integration/v0.13.4`에 no-ff 병합했다. fork의 삭제된 `actions.lock`은 유지하고, `backend/open_webui/utils/middleware.py`에서 완료된 assistant turn guard와 upstream temporary chat 제외를 결합했다. 백그라운드 작업 테스트 fixture를 저장된 채팅·mock에 맞춰 수정하고 temporary chat 회귀 테스트를 추가했다. 변경 참고는 [v0.13.4 upstream 문서](../references/openwebui-v0.13.4-release-notes.md)에 기록했다. feature merge `7627cb3d9`, integration merge `767fc1f65bb568c019bd15b44eebef065e685bed`.
2. RC `v0.13.4-kwh.1-rc.1` GHCR [build run 45095197573](https://github.com/kwh8121/openwebui-service/actions/runs/45095197573) 성공. 축적 데이터 로컬 게이트 `scripts/local-test.sh` v4.2 PASS: 자동 백업, `/health` 200까지 105초, Alembic current=heads `9f6c2a8d1b43`, 이번 부팅 upgrade 0건, SQLite integrity `ok`, Pipelines API 도달. 미인증 브라우저는 `/auth`와 `Koreatimes` title, Google 로그인 버튼, console error 0건을 확인했다. 새 RC 이미지의 백엔드 pytest는 4건 PASS.
3. [PR #76](https://github.com/kwh8121/openwebui-service/pull/76)의 Format & Build, Unit Tests, Ruff Format 3.11/3.12, requirements locks가 모두 PASS. merge commit `808f23b6f26bbce801fe293ac07c0ae30cad88fc`에 최종 annotated tag `v0.13.4-kwh.1`을 발행했다. 최종 GHCR [build run 45097636973](https://github.com/kwh8121/openwebui-service/actions/runs/45097636973) 성공. OCI index digest `sha256:e8f263ef2febc7b2f00fa2d4d0d210fbdb4db3e77865bccddec166da45f93d27`; `git-808f23b` parity 태그도 같은 digest로 pull됐다. linux/amd64 manifest digest는 `sha256:4ae7e4c90d672def6442070f436cd175cafb01fced35d28b7c5af59cddae9e50`.
4. 최종 태그 로컬 게이트 PASS: 자동 백업 Open WebUI 806MB·Pipelines 24KB, `/health` 200까지 55초, Alembic current=heads `9f6c2a8d1b43`, upgrade 0건, SQLite integrity `ok`, Pipelines API 도달. 테스트 컨테이너는 `--down`으로 종료했고 축적 데이터는 보존했다.
5. [배포 가이드](../manual/kwh-deploy-guide-v0.13.4-kwh.1.md)를 `feature/docs-v0.13.4-deploy-guide → integration/v0.13.4 → main`으로 반영했다. [PR #77](https://github.com/kwh8121/openwebui-service/pull/77) Format & Build·Unit Tests PASS, guide 참조 commit `3183ad1cfddfd10062a5d06ca6649268b813174d`. [Production deployment request Issue #78](https://github.com/kwh8121/openwebui-service/issues/78)를 제출하고 OPEN 상태·`production-deploy` 라벨·필수 tag/digest/guide/local PASS 필드를 확인했다.

### 마이그레이션·운영 주의

- `v0.13.3 → v0.13.4` 신규 Alembic revision은 0건이다. 다만 첫 기동 시 이미지 생성·편집 설정이 image connection으로 전환될 수 있으므로 신규 schema revision이 없어도 운영 배포 전 WAL-safe 백업이 필요하다.
- Tether가 Direct Connections/Integrations를 대체한다. Terminals 서버는 0.4.0 이상과 기존 0.3.x 설정의 수동 마이그레이션이 필요하다. 코딩 에이전트 모델 ID가 바뀐다. 운영에서 실제 사용 여부를 조회하고 브라우저 검수 항목별로 PASS/SKIPPED/UNVERIFIED를 구분해야 한다.
- [upstream issue #34646](https://github.com/open-webui/open-webui/issues/34646)는 PostgreSQL과 대형 터미널 채팅에서 DB pool 고갈을 보고한다. 로컬 SQLite 미러는 그 조합을 재현하지 않는다. 로컬 미러의 `fastapi-tools-v2:8000` DNS 오류 2건은 이전 릴리스에서도 관측됐고, 운영 Tool 서버 상태의 근거가 아니다.

### 검증 한계·다음 재개 지점

- OAuth 로그인·세션, 모델 대화, RAG, Tether, Terminals, 이미지 생성, 추천 카드 UX의 인증된 브라우저 조작은 로컬에서 검증하지 않았다. Issue #78의 관리자 acceptance에 남겼다.
- 다음 단계는 프로덕션 에이전트가 Issue #78과 pinned 가이드를 읽고 GitHub·실제 운영 이미지/DB·디스크·Pipelines 상태를 재조회하고, 새 백업을 검증한 뒤 소유자 및 GitHub `production` Environment 승인에 따라 배포하는 것이다. 개발 에이전트는 운영 SSH·Compose·workflow dispatch를 하지 않았다.
