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
