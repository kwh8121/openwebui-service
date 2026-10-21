# 2026-10-19 Open WebUI 작업일지

## 04:03 UTC (기록 시각) — upstream v0.12.3 병합 → `v0.12.3-kwh.1` 릴리스 + 배포 가이드 (개발 에이전트)

### 수행

1. **upstream 확인.** `git fetch upstream --tags`로 `v0.12.3`(2026-10-16)을 받았다. `v0.12.2`에서 91 커밋·209 파일.
2. **병합.** `main`에서 `integration/v0.12.3`과 `feature/upstream-merge-v0.12.3`을 만들고 `v0.12.3`을 `--no-ff`로 병합했다. 충돌 0건. `insertSuggestionPrompt ?? true`, `WEBUI_NAME` 접미사 제거(`env.py`에 `WEBUI_NAME += ` 없음), Dockerfile `NODE_OPTIONS` 유지를 확인했다. 마이그레이션 변경 0건, `pyproject.toml` 변경 없음, `package.json`은 버전·`crypto:verify` 스크립트·`docx-preview` 고정만 변경.
3. **RC.** `integration/v0.12.3` tip `03936421c`에 `v0.12.3-kwh.1-rc.1` 발행. build run 39188491140 성공.
4. **RC 로컬 게이트.** `./scripts/local-test.sh v0.12.3-kwh.1-rc.1 --allow-rc --health-timeout 1200`. 부팅 138초, upgrade 0건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, pipelines 응답. 로그 ERROR 2건은 #48. 소유자가 브라우저 체크리스트를 수행하고 확인 완료를 보고했다(항목별 기록 없음).
5. **PR #64** (`integration/v0.12.3` → `main`). CI 6건 통과, `CLEAN`.
6. **병합 승인 흐름.** 에이전트의 `gh pr merge`가 권한 분류기에 한 번 차단되어(CLA 확인 여부가 불명) 소유자에게 확인을 요청했다. 소유자가 CLA 확인과 병합·태그 발행을 지시한 뒤 `--merge`로 병합했다. `main` = `5d83d91cc4da81becfa7c763b5e5f4790264979e`.
7. **최종 태그.** `5d83d91cc`에 `v0.12.3-kwh.1` 발행. build run 39195302512 성공.
8. **최종 태그 로컬 게이트.** 기존 RC 컨테이너를 내리고 `./scripts/local-test.sh v0.12.3-kwh.1 --health-timeout 1200`. 부팅 198초, upgrade 0건, `alembic current == heads`, integrity `ok`, pipelines 응답. 기동 후 `/api/config` `Koreatimes 0.12.3`, `/_app/version.json` `5d83d91cc…`, `/manifest.json` `Koreatimes`, 로그 `Traceback`·`KeyError`·`IntegrityError` 0건, ERROR 2건은 #48.
9. **digest.** OCI index `sha256:b969b7360fd9bcfde23111cfd46f7bbc84f83dc9046472bbd46d42a76b2c72d9`, amd64 `sha256:5c2359ca5fd5b043a343ec19719f449e180548702ea2aa6357b2eca3621d9afb`. `v0.12.3-kwh.1`과 `git-5d83d91`을 각각 pull해 `RepoDigests`가 같음을 확인했다.
10. **배포 가이드 작성.** `docs/manual/kwh-deploy-guide-v0.12.3-kwh.1.md`. 이번 가이드는 마이그레이션이 0건이라는 점과, 롤백의 1차 경로가 이미지 롤백(미시험)이라는 점이 직전 두 가이드와 다르다.

### 판단·한계 (PASS로 읽지 말 것)

- **마이그레이션이 없으므로 이전 사이클의 합성 데이터 시험은 하지 않았다.** 프로덕션 스냅샷 리허설도 하지 않았다(소유자 결정 대기).
- **이번 사이클에 개발 머신에서 `npm ci`·vitest·`svelte-check`·ruff를 직접 실행하지 않았다.** 근거는 PR #64의 CI 6건 통과뿐이다.
- **최종 태그 이미지로는 브라우저 체크리스트를 수행하지 않았다.** 브라우저 확인은 RC 이미지에 대한 소유자 보고이며 항목별 기록이 없다. 최종 이미지는 자동 점검과 위 세 엔드포인트 확인만 거쳤다.
- **이미지 롤백(`v0.12.2-kwh.1`)은 시험하지 않았다.** 스키마가 같으므로 가능할 것으로 예상할 뿐이다. 새 이미지가 기동 중 `config`에 추가하는 기본값 행(`Seeded 3 new config defaults`)의 영향은 확인하지 않았다.
- **upstream "스킬 동작 변경"의 프로덕션 영향은 미검증이다.** 모델에 연결된 스킬이 전체 지침을 매 메시지에 보내므로 프로덕션 스킬 5개의 연결 현황에 따라 토큰 사용이 늘 수 있다. 가이드 §3.6-2에 기록 항목을 넣었다.
- 프로덕션의 `OAUTH_TOKEN_ENDPOINT_AUTH_METHOD`, Redis 사용 여부, Google Drive 연동 사용 여부는 확인하지 않았다(env 내용을 읽지 않았다).
- `v0.12.2-kwh.1` 배포는 Issue #63 종결, run 38879280051 성공(2026-10-16)까지 조회로 확인했다. 배포 실측(소요 시간)은 이번에 읽지 않았다.
- 이 기록은 배포 승인이 아니다. 승인 댓글과 `production` Environment 승인은 소유자 몫.

### 다음 재개 지점

- 가이드·일지 PR(`feature/docs-v0123-deploy-guide` → `integration/v0.12.3` → `main`) 병합. 문서 전용이라 새 태그·이미지 재빌드는 없다.
- 병합 후 `guide_commit`(`main` 커밋 전체 SHA) 확정 → `Production deployment request` Issue 제출(tag `v0.12.3-kwh.1`, SHA `5d83d91cc4da81becfa7c763b5e5f4790264979e`, run 39195302512, 위 digest, 롤백 태그 `v0.12.2-kwh.1`).
- 소유자 결정: 프로덕션 스냅샷 리허설 여부, `check_pipelines` 값(배포 직전 컨테이너 상태 기준), 스킬 연결 현황 확인.
- 로컬 게이트 컨테이너(8082·9099)가 떠 있다. 소유자 확인이 끝나면 `./scripts/local-test.sh --down`.
- 열린 Issue #48·#49·#34는 이번 릴리스와 별개로 유지.

## 04:21 UTC (기록 시각) — 가이드 PR 병합 + 배포 요청 Issue #66 + 게이트 정리 (개발 에이전트)

### 수행

1. **PR #65 병합.** 가이드·일지 문서 전용 PR. CI 3건 통과, `CLEAN`, `--merge`. `main` = `dd826a33113e48253dfe464c5fa0a1819cfa9786` = Issue의 `guide_commit`. 새 태그·이미지 빌드를 일으키지 않았다. 병합 전 CLA 확인은 소유자 지시로 생략(이후 PR에도 동일).
2. **배포 요청 Issue #66 제출.** 제목 `Production deployment request: v0.12.3-kwh.1`, 라벨 `production-deploy`. tag `v0.12.3-kwh.1`, SHA `5d83d91cc4da81becfa7c763b5e5f4790264979e`, run 39195302512, index digest `sha256:b969b736…72d9`, 가이드 commit `dd826a33113e48253dfe464c5fa0a1819cfa9786`, 롤백 태그 `v0.12.2-kwh.1`(run 38879280051 이후 더 새로운 배포 run 없음을 조회로 확인, 배포 직전 재확인 필요). 마이그레이션 0건, `check_pipelines`는 소유자 결정으로 남겼다.
3. **로컬 게이트 컨테이너 정리.** `./scripts/local-test.sh --down`, 8082·9099 제거, 남은 `local-test` 컨테이너 0개. 데이터 디렉터리(`~/openwebui-local-test-data`, `~/openwebui-local-test-pipelines`)는 보존.

### 판단·한계 (PASS로 읽지 말 것)

- Issue 제출은 승인이 아니다. 소유자 승인 댓글과 `production` Environment 실행별 승인은 별개다.
- 위 01~04:03 섹션의 한계(스냅샷 리허설 미수행, 이미지 롤백·백업 복원 미시험, 최종 이미지 브라우저 체크 미수행, 스킬 동작 변경의 프로덕션 영향 미검증)는 그대로 유효하다.
- 게이트 컨테이너를 내렸으므로, 최종 이미지로 브라우저 확인을 하려면 `./scripts/local-test.sh v0.12.3-kwh.1`로 다시 올려야 한다(부팅 약 200초).

### 다음 재개 지점

- 소유자 결정: 프로덕션 스냅샷 리허설 여부, `check_pipelines` 값(배포 직전 컨테이너 상태 기준), 스킬 연결 현황 확인.
- 소유자 승인 + `production` Environment 승인 → workflow dispatch(`tag=v0.12.3-kwh.1`, `issue_number=66`, `guide_commit=dd826a33113e48253dfe464c5fa0a1819cfa9786`, `check_pipelines=<소유자 결정>`).
- 배포 직전: 현재 DB revision `0bd252b206fb`, 디스크 여유, digest 대조(가이드 §3.5-1), 개수 재기록(가이드 §3.6-1·§3.6-2).
- 배포 후: 가이드 §6~7 점검(`Running upgrade` 없음, 버전 `v0.12.3`, Encrypted channels 꺼짐), 결과를 #66에 기록.
- 열린 Issue #48·#49·#34는 이번 릴리스와 별개로 유지.
