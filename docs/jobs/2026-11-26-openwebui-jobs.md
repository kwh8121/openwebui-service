# 2026-11-26 Open WebUI 작업일지

## 12:00 KST — upstream v0.13.5 통합과 `v0.13.5-kwh.1` 릴리스 준비 (개발 에이전트)

### 상태 인지·결정

- [PR #82](https://github.com/kwh8121/openwebui-service/pull/82)(KOR-71, `integration/v0.13.4`)을 `main`에 병합했다. 태그와 배포는 하지 않았다. 이어서 upstream [v0.13.5](https://github.com/open-webui/open-webui/releases/tag/v0.13.5)를 `integration/v0.13.5`에 통합했다.
- 마지막 운영 릴리스는 Issue #74의 `v0.13.3-kwh.1`이다. Issue #78(`v0.13.4-kwh.1`)은 실행되지 않았고 이번 릴리스로 대체된다. 운영 상태는 직접 관측하지 않았다.
- 미추적 Wire Desk 계획 문서 8개는 건드리지 않았다.

### 수행·증적

1. upstream 병합 `69249cc61`. 충돌 2건을 이렇게 해결했다.
   - 브랜드 `apple-touch-icon.png`는 ours를 유지했다.
   - `ca-ES` 번역은 theirs를 받은 뒤 `i18n:parse`로 KOR-71 키를 복원했다(`a5dc64309`).
   - upstream 변경 참고는 [v0.13.5 문서](../references/openwebui-v0.13.5-release-notes.md)에 있다.
2. RC.1(`v0.13.5-kwh.1-rc.1`)에서 **fork 가드가 실패했다.**
   - upstream이 `terminalDocument`를 `machineDocument`로 이름을 바꿨다. hook은 제자리에 있었고, 병합도 충돌 없이 끝났는데 wiring 테스트의 기준점만 어긋났다. 가드가 설계대로 동작한 첫 사례다.
   - `339f2c32b`에서 두 이름을 모두 허용하게 했다. 안내 span 색상은 새 테마에 맞춰 `text-base-500`으로 바꿨다.
   - RC.1 이미지는 폐기했다.
3. RC.2(`v0.13.5-kwh.1-rc.2`): fork 가드와 GHCR 빌드가 성공했다.
   - 축적 데이터 게이트에서 Alembic upgrade 4건이 실행돼 head `5e7a2c9d4b13`에 도달했다.
   - 대화 기록 변환은 채팅 10건에 2초 걸렸다. 변환 전 메시지 26건과 변환 후 `chat_message` 26행이 일치했다(게이트 자동 백업과 대조).
   - SQLite `ok`, Pipelines 200, 브랜드 `Koreatimes`.
   - 스크립트는 `/health` 1200초 초과로 `[FAIL]`을 냈다. 변환이 끝난 뒤 Function 의존성 `pip install`이 호스트 메모리 부족(swap 2GB 가득 참) 때문에 D 상태에 걸린 것이 원인이었다. 같은 컨테이너가 직후 healthy가 되어 이미지 결함이 아닌 타임아웃 단독 실패로 판정했다. 태그는 재빌드하지 않았다.
   - RC.2 이미지 안의 백엔드 pytest는 4건 PASS(8분).
4. Linear 개발 검증(4단계): 별도 verifier lane이 PASS를 냈다(CRITICAL 0 / MEDIUM 0 / MINOR 4). KOR-72와 KOR-73은 `verify-passed`. MINOR는 후속 과제다.
   - `/` 없는 `sandbox:x.svg`는 upstream 오류로 끝난다.
   - 링크 안내에서 중첩 서식이 사라진다.
   - Python과 JS의 대소문자 폴딩에 차이가 있다.
   - wiring 테스트는 hook이 분기 안에 있는지까지는 확인하지 않는다.
5. 승인 계획을 `docs/plan/2026-11-25-kor71-pyodide-display-guard.md`로 승격하고 KOR-71에 링크했다. §12 표기를 `v0.13.5-kwh.1`로 고쳤다.
6. 배포 workflow에 선택 입력 `health_timeout_seconds`(60~3600, 기본 300)를 추가했다(`b44076d93`).
   - 소유자 결정: workflow 입력으로 추가.
   - 운영 DB의 채팅이 많으면 300초 안에 변환이 끝나지 않을 수 있어서다.
   - 하위 호환이므로 Protocol v1.2.1을 유지하고 변경 이력에 항목만 추가했다.
   - actionlint 결과 새 문제 없음, 경계값 검증 통과.
7. [PR #83](https://github.com/kwh8121/openwebui-service/pull/83): 체크 10건 PASS(fork guard 포함, API로 재확인) 뒤 병합했다. merge `57306ccec5673b601f22449e29442c32425027ea`에 최종 태그 `v0.13.5-kwh.1`을 발행했다.
   - [build run 45738277963](https://github.com/kwh8121/openwebui-service/actions/runs/45738277963) 성공.
   - OCI index `sha256:b06d11747a37b6ddd114cdc214873a106db74aabbf7b22b63057d01a15720d1a`(`git-57306cc` 동일), amd64 `sha256:2de40499a13788ed46ad59a8e21453f8c4a41a6510d8845d0a9d4f556a592f12`.
8. 최종 태그 게이트 PASS: 815초, upgrade 0건(RC.2에서 이미 변환), head 일치, SQLite `ok`, `version.json` 일치, Pipelines 200. 컨테이너는 내렸고 데이터와 백업은 보존했다.
9. [배포 가이드](../manual/kwh-deploy-guide-v0.13.5-kwh.1.md)를 작성했다.
   - 변환 뒤에는 이미지 롤백이 불가하고 백업 복원만 가능하다는 점을 명시했다.
   - 사전에 채팅·메시지 총수를 기록하고 변환 후 행 수와 대조하게 했다.
   - `health_timeout_seconds=1800`을 지정했다.
   - 타임아웃이 나도 재시작하지 말라고 적었다.

### 학습

- upstream이 이름을 바꾸면 hook이 남아 있어도 wiring 테스트의 기준점이 어긋날 수 있다. 가드가 실패하면 먼저 hook이 실제로 남아 있는지 확인하고, 기준점만 바뀐 경우에는 테스트를 넓힌다.
- 이 개발 호스트는 다른 프로젝트 컨테이너와 세션 때문에 메모리가 빠듯하다. 게이트 타임아웃이 나면 `docker top`의 프로세스 상태(D 상태 `pip`)와 swap 사용량을 먼저 본다.

### 다음 재개 지점

- 배포 가이드를 `main`에 반영한 뒤 `Production deployment request` Issue를 제출한다. Issue #78에는 대체 코멘트를 남기고 닫는다. Linear KOR-71에 배포 Issue를 링크한다.
- 운영 에이전트가 할 일:
  - 실제 운영 태그·revision(`9f6c2a8d1b43` 예상)·채팅 규모를 재조회한다.
  - WAL-safe 백업을 검증한다.
  - 소유자와 `production` Environment의 승인을 받은 뒤 `health_timeout_seconds=1800`으로 dispatch한다.
- 로컬 미검증: OAuth, 모델 대화, RAG, Machines, Arena, Docling, 운영 규모 변환 시간, KOR-71의 v0.13.5 브라우저 재확인.
