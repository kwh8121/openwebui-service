# 2026-10-13 Open WebUI 작업일지

## 04:57 UTC (기록 시각) — v0.12.0-kwh.1 배포 요청 Issue #58 + 프로덕션 스냅샷 리허설 (개발 에이전트)

### 수행

1. **#57 병합.** 최종 배포 가이드 문서 전용 PR. 사용자가 CLA 체크 후 병합을 지시. CI 전부 green, `--merge`. `main` = `263c6f444700bf881395f22e6af06aebfe9e9bb3` = dispatch의 `guide_commit`. 태그·빌드를 일으키지 않았다.
2. **로컬 게이트 컨테이너 정리.** `./scripts/local-test.sh --down`, 8082/9099 제거, 데이터 디렉터리는 보존.
3. **열린 Issue 4건 정리 (#47 #48 #49 #34).** #47은 이번 릴리스(#54)에 fix 포함, #49는 1단계 반영(새 백업 단계는 이번 배포가 운영 러너 첫 실행), #48·#34는 이번 릴리스와 무관하게 이연.
4. **`check_pipelines` 권고안 채택.** 배포 직전 소유자가 `openwebui-pipelines-1` 상태를 확인해 결정한다. 컨테이너 `running` + 9099 200이면 `true`, 정지·미사용이면 `false`(`SKIPPED`, `PASS`로 기록하지 않음). 배포 중 Pipelines 기동·재생성은 하지 않는다(#34).
5. **배포 요청 Issue #58 제출.** 제목 `Production deployment request: v0.12.0-kwh.1`, 라벨 `production-deploy`. tag `v0.12.0-kwh.1`, SHA `b7a66193917b8344ff928c996171b99089dba12f`, run 38236137881, digest `sha256:cd4957b2…c985`, 가이드 commit `263c6f444700bf881395f22e6af06aebfe9e9bb3`, 롤백 태그 `v0.11.4-kwh.1`(마지막 배포 run이 2026-10-07이므로 이후 변경 없음, 배포 직전 재확인 필요). 소유자 결정 반영: 퇴근 후 오후 6시 30분경 창구, 프로덕션 보유 현황(모델 9·지식기반 2·프롬프트 8·스킬 5·도구 8·함수 29), 승인 전 복원 시험.
6. **스냅샷 요청.** #58 코멘트로 배포 에이전트에게 읽기 전용·무중단 스냅샷을 요청(`sqlite3 .backup` + 나머지 tar, OAuth env·pipelines 제외). 소유자가 `scp`로 수령.
7. **프로덕션 스냅샷 리허설 (개발 PC).** 스냅샷 `rehearsal-20261013-020036`. 원본은 건드리지 않고 복사본(`rehearsal-work`)에서 `OPENWEBUI_LOCAL_TEST_DATA`/`PIPELINES_LOCAL_TEST_DATA`를 지정해 `scripts/local-test.sh --no-backup --health-timeout 1800`.
   - SHA256 3건 OK. 전달 시 디렉터리 권한 755 → 수령 후 700/600으로 조정.
   - 사전 상태: `alembic_version` `d4c1a8e37b62`, integrity `ok`, model 370(사용자 정의 9 + 기본 모델 항목 361)·tool 8·function 29·skill 5·knowledge 2·prompt 8·chat 472·user 39·group 3.
   - 1단계 `v0.11.4-kwh.1`(복원 시험): 부팅 153초, upgrade 0건, `alembic current == heads`, integrity `ok`, 함수 모듈 로드.
   - 2단계 `v0.12.0-kwh.1`: 부팅 146초, `Running upgrade` 6줄(순서 일치), `alembic current == heads`(`b8f2c6d91a04`), integrity `ok`, `/api/config` `Koreatimes 0.12.0`. 로그 `Traceback`·`KeyError`·`IntegrityError` 0건. ERROR 2건은 #48의 기존 도구 서버 DNS 실패.
   - 사후 개수 전부 동일. history 행 model 370·tool 8·function 29·skill 5, `version_id` NULL 0건.
8. **결과 코멘트 #58** (`issuecomment-6138001812`). 컨테이너 제거 후 게시.
9. **사본 삭제.** 사용자 지시로 개발 PC의 `~/projects/rehearsal-20261013-020036`(2.8 GB)과 `~/projects/rehearsal-work`(3.7 GB) 삭제했다. 저장소 밖 경로였고 git에 들어간 적 없다.

### 판단·한계 (PASS로 읽지 말 것)

- backfill이 **실제 프로덕션 행(412행)** 에서 오류 없이 동작했고, 약 3.7 GB 규모에서 마이그레이션 6건이 부팅 시간(마이그레이션 없는 부팅 153초 vs 있는 부팅 146초)에 가려질 만큼 짧았다. 이로써 이전에 미검증이던 backfill과 규모 위험이 해소됐다.
- **프로덕션에서의 소요 시간은 보장하지 않는다.** 개발 PC와 프로덕션 호스트의 하드웨어가 다르다.
- **deploy workflow의 새 백업 단계(`umask 077`, 모드 600 검사, env 사본)는 검증하지 않았다.** 이번 배포가 운영 러너 첫 실행이다.
- 스냅샷은 온라인 방식이라 **실제 배포 백업(정지 후 tar)의 복원이 아니다.** 데이터 복원 가능성만 확인했다.
- 마이그레이션 후 `v0.11.4-kwh.1`로 이미지만 되돌리는 롤백은 시험하지 않았다. 기본 복구 경로는 백업 복원이라는 가이드 판단은 그대로다.
- 브라우저 로그인·화면 확인은 하지 않았다.
- 이 리허설은 배포 승인이 아니다. 승인 댓글과 `production` Environment 승인은 소유자 몫.

### 다음 재개 지점

- 호스트의 원본 스냅샷(`/home/ubuntu/rehearsal-20261013-020036`) 삭제 시점은 소유자가 배포 에이전트에게 지시한다.
- 소유자 승인 + `production` Environment 승인 → 배포 에이전트가 workflow dispatch(`tag=v0.12.0-kwh.1`, `issue_number=58`, `guide_commit=263c6f444700bf881395f22e6af06aebfe9e9bb3`, `check_pipelines=<배포 직전 결정>`).
- 배포 직전: 현재 DB revision `d4c1a8e37b62`, 디스크 여유, digest 대조(가이드 §3.5-1), Model/Tool/Function/Skill/Knowledge/Prompt 개수 재기록(9·8·29·5·2·8).
- 배포 후: 가이드 §6~7 점검, 제목 생성 로그에 `KeyError` 없음(#47), 개수 대조. 결과를 #58에 기록하고 필요하면 #47 종결.
- 열린 Issue #48·#49·#34는 이번 릴리스와 별개로 유지.
- 로컬 환경 정리: `~/openwebui-local-test-data.rolled-back-20261012-193551` 삭제 여부는 사용자 결정.

## 23:50 UTC (기록 시각) — v0.12.0-kwh.1 프로덕션 배포 결과 기록 (개발 에이전트)

위 04:57 UTC 섹션의 "다음 재개 지점" 이후 일어난 일을 GitHub Issue #58·#49와 Actions run에서 **재조회해** 기록한다. 배포는 배포 에이전트와 소유자가 수행했고 개발 에이전트는 실행하지 않았다.

### 경과

1. **#59 병합.** 일지 PR, `main` = `890e871ebcf9c1ddeef92b3edd514c9043e4d481`.
2. **소유자 승인 댓글 게시.** #58 `issuecomment-6139361484`(06:03 UTC). 소유자 지시에 따라 개발 에이전트가 소유자 계정으로 작성하고 그 사실을 첫머리에 명시했다. 승인 범위: 태그·SHA·digest·`guide_commit` 고정, 수용한 한계, 배포 에이전트 사전 확인 6가지, 중단 조건.
3. **dispatch 사전 점검과 한계.** 러너 온라인, 태그 대상·`guide_commit`(main 포함)·GHCR digest(최종 태그와 parity 태그 동일) 확인. `check_pipelines=false`(소유자: 정지·미사용). 개발 에이전트가 `gh workflow run`으로 dispatch를 시도했으나 권한 검사에서 "프로덕션 배포"로 차단돼 **실행하지 않았다.** 우회하지 않고 소유자가 GitHub UI에서 직접 입력하도록 입력값을 안내했다(프로토콜과 일치).
4. **배포 run `38376927749`: success.** 소유자 dispatch·Environment 승인 후 실행. dispatch 코멘트 09:39:56, job 09:39:52–09:48:04 UTC(8분 12초, 승인 대기 제외).
5. **workflow 진행 증적(#58, github-actions).**
   - 체크포인트: 백업 `/home/ubuntu/prod-backup-preupgrade-20261013-094236-v0.11.4-kwh.1.tar.gz`(2.5G, mode 600), env 사본 `….env`(mode 600, 내용 미기록). 마이그레이션 진행 중.
   - 성공: 이미지 `…@sha256:cd4957b2d23de3632f3cbf06d6c165702599962e8b7034be275e7414caf1c985`(#58 기록과 일치), 기술 스모크 PASS(컨테이너 running, health/version/manifest, 로그 정상), Pipelines `SKIPPED (intentionally disabled)`.
6. **브라우저 검수.** 소유자가 "검수 완료, 문제 없음"을 보고했고 배포 에이전트가 #58에 `Browser acceptance: PASS`, `Release accepted`로 기록했다. **항목별 관찰은 기록되지 않았다.** 신규 결함 없음.
7. **#58 CLOSED.** 배포 에이전트가 세션 핸드오프 코멘트를 남겼다(10:04 UTC).
8. **이슈 정리.** #47(수정 배포 완료) CLOSED, #48(기존 선택적 DNS 현상, 수용·무변경) CLOSED — 해결된 것이 아니라 수용 결정. 열린 이슈는 #34, #49.

### 실측으로 확인된 것

- **리허설 예측이 맞았다.** 마이그레이션 6건이 전체 job 8분 12초 안에 끝났고, 시간이 부담이 되지 않았다.
- **새 백업 단계가 운영에서 처음 실행돼 성공했다(#49 1단계).** 이미지 pull은 정지 전(09:39:57–09:42:36, 2분 39초)에 끝났고 새 컨테이너는 `up --pull never`로 기동. 백업 tar 2,660,671,162 bytes mode `0600`, env 사본 749 bytes mode `0600`. 백업 단계 4분 28초(09:42:36–09:47:04).
- **중단 시간:** 기존 컨테이너 종료 09:42:47 → health 대기 단계 완료 09:47:58, 관측 상한 약 5분 11초. 이전 배포(약 6분) 대비 pull 단축 외 구조는 그대로(정지 후 압축).
- 이전 immutable 이미지 `v0.11.4-kwh.1`이 호스트에 남아 있다.

### 판단·한계 (PASS로 읽지 말 것)

- **복원 가능성은 증명되지 않았다.** 배포 백업 tar는 `tar -tzf` 목록 검사만 통과했다. 리허설의 복원 시험은 온라인 스냅샷이었으므로 이를 대체하지 않는다.
- 실패 경로(작업 중 실패·중단 시 남는 파일의 권한·복구)는 운영에서 시험되지 않았다.
- 배포 후 항목별 개수 대조(Model/Tool/Function/Skill/Knowledge/Prompt)는 #58에 기록되지 않았다. 브라우저 검수 PASS와 스모크 PASS가 근거이며, 개수 증적은 없다.
- 브라우저 검수는 전체 단위 보고라서 항목별 증적이 없다.

### 학습·운영 메모

- `gh workflow run`은 권한 검사에서 프로덕션 배포로 차단된다. 개발 에이전트는 dispatch하지 않는다. 입력값 안내까지가 범위다.
- 배포 머신의 로컬 `main`이 원격보다 오래될 수 있다. 배포 세션은 로컬 문서를 최신으로 오인하지 말고 GitHub를 재조회한다(핸드오프에 명시됨).
- 배포 에이전트는 호스트의 리허설 스냅샷 `/home/ubuntu/rehearsal-20261013-020036`(0700)과 실제 백업(0600)을 소유자 지시 전까지 삭제하지 않는다.

### 다음 재개 지점

- **#49 후속(미구현·미실측):** 실제 배포 백업 tar·env 사본을 격리 환경에서 복원해 SQLite 무결성, `/app/pipelines` 포함, 앱 기동, 데이터 개수를 확인한다. 중단 시간 단축 2단계(실행 중 비 DB 파일 사전 복사 → 정지 후 최종 변경분과 SQLite 일관 백업 확정 → 무결성 확인 후 새 이미지 기동 → 이후 압축)는 다음 승인 릴리스 전에 격리 복원 시험과 실패 경로 검증이 필요하다. workflow가 stop-to-healthy·백업·전체 소요를 일관되게 기록하도록 개선한다.
- #34(Pipelines 안전 재기동)는 별도 유지보수 요청으로 이연 유지.
- 호스트 보존 파일(리허설 스냅샷, 실제 백업) 삭제 시점은 소유자가 배포 에이전트에게 지시.
- 개발 PC `~/openwebui-local-test-data.rolled-back-20261012-193551` 삭제 여부는 사용자 결정.
- 다음 upstream 릴리스 통합은 새 `integration/vX.Y.Z`에서 시작.
