---
name: deployment-context
description: 새 OpenCode 세션에서 프로덕션 관련 요청의 현재 권위 증적과 장기 이력, 미해결 항목을 분리할 때 사용한다.
---

# 배포 컨텍스트

**스킬 규약 버전: 1.1.0**

## 목적

세션이 바뀌어도 과거 성공 기록을 현재 실행 권한으로 승격하지 않는다. 프로덕션 관련 요청을 받으면 현재 GitHub·`origin/main`·런타임 증적을 다시 수집하고, 장기 이력과 미해결 정보를 별도 레인으로 유지한다.

## 필수 분류

### `권위 증적`

- CLOSED GitHub 배포 Issue의 최종 tag·main SHA·run ID·image digest
- completed/success Actions run의 같은 ID·tag·SHA와 GitHub tag의 같은 SHA
- Issue·run·tag와 같은 로컬 `origin/main`·원격 `main` 40자 SHA
- 이름이 `openwebui`이고 running/healthy이며 Issue와 같은 digest로 고정된 현재 이미지

세 출처는 모두 현재 세션에서 수집한다. 플러그인의 유효 시간은 15분이며 OpenCode 재시작 시 수집 상태가 초기화된다.

### `historical context`

- `docs/jobs/`의 append-only 작업 기록
- 해당 문서를 장기 컨텍스트로 제공하는 OpenViking

이 레인은 과거 결정과 반복 실수를 설명하지만 배포 승인, 현재 SHA, 현재 런타임 상태를 증명하지 않는다.

### `unresolved`

- 현재 사용할 수 없는 Linear 통합
- GitHub, Git, 런타임 사이의 불일치
- 출처나 관측 시각이 없는 주장
- 무시된 로컬 `.omo` 기준선
- Mem0에서 나온 프로젝트 정보

Linear가 없으면 통합이 막혔다고 명시하고 가짜 이슈, 상태, 관계를 만들지 않는다. Mem0는 권위 또는 장기 프로젝트 이력 경로로 사용하지 않는다.

## 실행 규칙

1. 먼저 `/deployment-context`로 읽기 전용 수집을 수행한다.
2. 로컬·원격 main SHA를 직접 비교한다. 불일치하면 `unresolved`다.
3. GitHub Issue, Actions run, tag, 로컬·원격 main의 run ID·tag·SHA가 모두 일치하는지 확인한다.
4. 현재 런타임은 조회만 한다. `openwebui`의 running/healthy 상태와 digest-pinned `Config.Image`가 Issue image digest와 일치해야 한다.
5. 최종 tag, 보호 ref push, workflow dispatch, GitHub 변경, Docker·Compose 변경, `sudo`, `tar`를 실행하기 전 플러그인 게이트를 통과해야 한다.
6. 자식 세션에 push나 분류된 변경을 맡기지 않는다. feature push도 루트 세션에서만 허용한다.
7. 정확한 읽기 전용 allowlist와 제한된 증적 대상 변경 형식만 직접 실행한다.
8. 실행 파일 토큰의 따옴표 결합, 역슬래시, `$` 확장, 문자열 연결은 해석하지 않고 거부한다. 절대 도구 경로, `env`·`command` wrapper, `git -c`, shell `-c`·`-lc`, 메타문자, 파이프, 리다이렉션, 명령 치환으로 민감 도구를 감싸지 않는다.
9. PR merge, release 생성, Issue 삭제, 쓰기 `gh api`, Compose `run`·`exec`, Docker `cp`·`commit`·image prune는 권위 증적이 있어도 허용되지 않는다.

## 구현 경계

강제 지점은 `.opencode/plugin/deployment-context.mjs`의 `tool.execute.before`다. 이 훅은 허용 판단 전에 세션 조상을 확인한다. 읽기 전용 명령이 성공한 뒤 `tool.execute.after`가 JSON을 파싱해 Issue·run·tag·SHA·digest·런타임 상태와 관측 시각을 프로세스 메모리에 기록한다. 디스크 승인 파일은 만들지 않는다. `permission.ask`를 사용하지 않으며 그 결과에 의존하지 않는다.

이 스킬은 DEFER 또는 DROP으로 분류된 저중단 배포 workflow, 실행 정책, Dockerfile, Compose 후보, live-system 스크립트를 가져오거나 활성화하지 않는다.
