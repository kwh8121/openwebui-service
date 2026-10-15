# 2026-10-15 Open WebUI 작업일지

## 02:21 UTC (기록 시각) — upstream v0.12.2 통합 + RC 게이트 (개발 에이전트)

### 시작 점검

- 시작 시 `main` = `origin/main`(`b38b5c744`), 열린 PR 없음. 열린 Issue는 #34·#49.
- `git fetch upstream --tags`로 **v0.12.1**(10-14 16:06 UTC)과 **v0.12.2**(10-14 21:07 UTC, Latest)를 확인. 프로덕션은 `v0.12.0-kwh.1`. `v0.12.0`에서 210 커밋·247 파일.

### 분석 (병합 전, 읽기 전용)

- `merge-tree`로 병합 예측: 텍스트 충돌 0건. fork 파일(`docker.yaml`, `Dockerfile`, `env.py`, 브랜드 자산)은 upstream 변경과 겹치지 않았다. `middleware.py`·`Chat.svelte`·`main.py`는 upstream 변경이 있으나 자동 병합.
- 병합 결과에서 fork 핵심 줄 유지 확인: #47 가드(`ctx.get('assistant_message')` 후 `ctx['model']` 엄격 접근), `insertSuggestionPrompt ?? true`, `BUILD_CHANNEL=main`. upstream은 `background_tasks_handler`에서 후속 질문 용도로 `assistant_message`를 `.get()`으로 읽도록 바꿨으나 충돌하지 않는다.
- 신규 Alembic 마이그레이션 2건, 선형: `b8f2c6d91a04` → `c92da83b017f`(`app` 테이블, `channel_member` 재작성, `message.app_id`) → `0bd252b206fb`(`auth` 누락 행 보강, 빈 비밀번호). 새 Apps 기능은 기본 비활성.
- 릴리스 노트 관점: v0.12.1은 "0.12.0 이후 재연결 루프(서버 부하)" 수정, v0.12.2는 채널 메타데이터 서버측 보관·검색 컬렉션 이름 접근 검사 강화·SCIM 관리자 삭제 차단 등 보안성 수정을 포함.

### 결정 (사용자 선택)

- **통합 기준:** 현재 `main`에서 `integration/v0.12.2` 분기. **게이트 모드:** 기본(누적 데이터 + 자동 백업). **진행 확인:** push·integration 병합·RC 태그는 되돌릴 수 없어(`integration/*` ruleset, immutable 태그) 실행 직전에 사용자 확인을 받았다.
- **문서 방식:** 지난 사이클과 같음 — 가이드 초안(`<TBD>`)과 일지를 통합 PR에 포함, 최종본은 문서 전용 PR.

### 수행

1. `integration/v0.12.2` 분기, `feature/upstream-merge-v0.12.2`에서 `v0.12.2` 병합. 충돌 0건(`ad4380508`). integration 병합 후 원격 tip `a503c35383541b45025242ea96523c275d20f3fe`.
2. 정적 검사(Node 22): `npm ci` 1,155 패키지, `i18n:parse` 변경 0건, prettier(병합이 바꾼 파일 247개 중 대상) 통과, vitest 4/4, ruff 추적 파일 통과(지적 4건은 untracked `docs/plan/` 문서), `svelte-check` 5,918건(직전 6,040건) — 병합이 만든 신규 오류 없음. `Chat.svelte:986`의 `insertSuggestionPrompt` 타입 오류는 fork 기존 항목.
3. RC 태그 `v0.12.2-kwh.1-rc.1` → `a503c3538`. GHCR 빌드 run 38665238494 success(headSha 일치, 약 9분).
4. 로컬 게이트 `./scripts/local-test.sh v0.12.2-kwh.1-rc.1 --allow-rc --health-timeout 900`: **PASS**. 부팅 171초(전체 17분 56초, 이미지 pull·자동 백업 포함), `Running upgrade` 2건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, pipelines 응답. `/usr/bin/docker logs` 41줄에서 `Traceback`·`KeyError`·`IntegrityError`·`OperationalError` 0건. ERROR 2건은 #48의 기존 도구 서버 DNS 실패. `/api/config` `Koreatimes 0.12.2`, `/_app/version.json` = RC 태그 대상 SHA, manifest 200. 자동 백업 `20261015-103154-v0.12.2-kwh.1-rc.1.tar.gz`.
5. **마이그레이션 데이터 보존 검증 (합성).** 로컬 DB에는 채널·메시지가 0건이라 `channel_member` 재작성과 `auth` 보강이 실제 데이터를 다루지 못했다. 직전 백업 사본에 채널 2·멤버 6·메시지 20(한글 포함)·`auth` 없는 사용자 1을 심고 RC 이미지의 alembic으로 적용해 전후를 비교했다: `channel_member`·`message`·`channel` 내용 동일, integrity ok, FK 위반 0, 새 컬럼 NULL, 체크 제약이 둘 다 NULL인 행을 거부, 기존 `auth` 3행 불변, 누락 사용자에 빈 비밀번호 `auth` 행 추가. 임시 DB는 비교 후 삭제. **합성 데이터이며 프로덕션 실데이터가 아니다.**
6. **Playwright MCP 설치.** 사용자 지시로 `@playwright/mcp@0.0.83`을 사용자 스코프에 등록(`--browser chromium --headless --isolated`, 기존 Chromium `chromium-1243` 지정). 설치 전에는 `chrome-devtools-mcp`(Chrome 실행 파일 없음)와 `browser-use`(실행 중 Chrome 없음)가 모두 시작되지 않았다. 세션 재시작 후 사용했다.
7. **브라우저 검증 (로컬 RC 게이트).** 사용자가 제공한 로컬 테스트 계정으로 로그인(자격 증명은 이 일지·저장소에 기록하지 않는다). 로그인 화면, "What's New"(`v0.12.2`, Koreatimes), 채널 생성, 한글 메시지 전송과 **새로고침 후 유지**, 채널 옵션 Notifications(전체/멘션만), `@` 멘션 목록(Users·Models), 멤버 패널 모두 정상, 콘솔 오류 0건. 이 검증은 로컬 DB에 채널이 없던 상태에서 새로 만든 채널이라 **기존 채널 데이터의 UI 표시는 아니다.** 로컬 DB에 테스트 채널 `rc-gate-test` 1개와 메시지 1건이 남았다(백업으로 복원 가능).
8. 배포 가이드 초안 `docs/manual/kwh-deploy-guide-v0.12.2-kwh.1.md` 작성(`<TBD>` 10곳). 이전 가이드와 달라지는 점만 기록: 마이그레이션 2건, `channel_member` 재작성, 빈 비밀번호 `auth` 보강, 롤백 대상 `v0.12.0-kwh.1`, 직전 배포 실측, 채널 스모크 항목. Playwright가 저장소 루트에 만든 임시 산출물(`.playwright-mcp/`, 스크린샷)은 삭제해 커밋에 들어가지 않게 했다.

### 판단·한계 (PASS로 읽지 말 것)

- **프로덕션 실데이터 검증이 없다.** 합성 데이터는 행 수가 작고 실환경의 특이한 값(긴 메시지, 복잡한 `meta` JSON, 삭제된 채널)을 다루지 못했다. 프로덕션 스냅샷 리허설 여부는 소유자 결정이다.
- **프로덕션에서 채널을 쓰는지, 채널·멤버·메시지 개수가 얼마인지 모른다.** 쓰지 않는다면 `channel_member` 재작성 위험은 크게 낮아진다.
- **RC 수동 확인(OAuth, RAG, 제목 생성 #47)은 아직 기록되지 않았다.** 이 일지 작성 시점의 미완 항목이다.
- 이미지 롤백·실제 배포 백업 복원·DB downgrade는 여전히 시험되지 않았다(#49).
- Playwright 검증은 `--headless --isolated` 로컬 브라우저에서 한 것이며 Google OAuth 로그인은 시험하지 못했다.

### 다음 재개 지점

- 사용자: RC 수동 확인(OAuth·RAG·제목 생성) → 프로덕션 스냅샷 리허설 여부 결정 → 통합 PR(`integration/v0.12.2` → `main`) CLA 체크·병합.
- 병합 후: 최종 태그 `v0.12.2-kwh.1`을 병합된 `main` tip에 발행(사용자 승인) → GHCR 빌드 → 최종 이미지 게이트 → 가이드 최종본(문서 전용 PR) → 배포 요청 Issue(소유자 승인, `check_pipelines`는 배포 직전 결정, 배포 전 개수 기록).
- 로컬 게이트 컨테이너(8082/9099)는 수동 확인이 끝나면 `./scripts/local-test.sh --down`으로 정리.

## 13:00 UTC — PR #61 병합, 최종 태그, 최종 이미지 게이트, 가이드 최종본

### 수행

1. 사용자가 PR #61의 CLA를 체크한 것을 확인(처음 확인 시점에는 미체크여서 병합을 보류했다). CI 5건 통과 후 draft 해제·`--merge` 병합. 병합 커밋 `2668079eba4ed40d96afeaaedc813208230bd053`, 로컬 `main` 동기화.
2. 사용자가 RC 수동 확인(OAuth, RAG, 제목 생성 #47)에서 문제가 없다고 알림. 자동화 증거가 아닌 사용자 보고로 기록한다.
3. 사용자 요청으로 RC 로컬 게이트 컨테이너를 내림(데이터 보존).
4. 사용자 승인("승인") 후 최종 태그 `v0.12.2-kwh.1`(annotated)을 `2668079eb`에 발행·push. GHCR 빌드 run 38676268849 success. index digest `sha256:407b59b2…67be4`, amd64 `sha256:fbeecae4…922cf`, parity 태그 `git-2668079`가 같은 이미지.
5. 최종 이미지 게이트: 테스트 채널이 든 직전 데이터를 `~/openwebui-local-test-data.pre-final-gate-aside`로 옮기고, RC 직전 백업(`20261015-103154-…rc.1.tar.gz`)을 새 data 디렉터리에 풀어 `./scripts/local-test.sh v0.12.2-kwh.1 --no-backup --health-timeout 900` 실행. **PASS** — 부팅 122초, upgrade 2건, `alembic current == heads`(`0bd252b206fb`), integrity `ok`, `Traceback`·`KeyError`·`IntegrityError` 0건, `/api/config` `Koreatimes 0.12.2`, `/_app/version.json` = `2668079eb…`, manifest 200. ERROR 2건은 #48 기존 항목.
6. 가이드 최종본: `<TBD>` 10곳을 채움(태그 target, digest, parity 태그, 빌드 run, RC 수동 확인, 최종 게이트). 프로덕션 스냅샷 리허설은 소유자 미결정으로 기록.

### 한계

- 최종 게이트도 로컬 누적 데이터 기준이며 프로덕션 실데이터 검증이 아니다. 리허설 여부는 미결정.
- 이미지 롤백·실제 배포 백업 복원·DB downgrade 미시험(#49).

### 다음 재개 지점

- 가이드 최종본 문서 전용 PR(CLA 사용자 체크 후 병합) → 병합 커밋 전체 SHA가 `guide_commit`.
- 이후 `Production deployment request` Issue 초안(소유자 승인, `check_pipelines`는 배포 직전 결정, 배포 전 개수 기록, 리허설 여부 확정).
- 최종 이미지 게이트 컨테이너(8082/9099)는 `./scripts/local-test.sh --down`으로 정리 대기, `~/openwebui-local-test-data.pre-final-gate-aside`는 정리 여부 사용자 결정 대기.
