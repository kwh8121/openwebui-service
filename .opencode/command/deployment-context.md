---
description: 새 세션의 배포 컨텍스트를 읽기 전용 증적으로 다시 판정한다
agent: deployment-context
---

# 배포 컨텍스트 확인

**명령 규약 버전: 1.1.0**

실행 인자: `$ARGUMENTS`

다음 순서로 읽기 전용 조회만 수행하고 결과를 `권위 증적`, `historical context`, `unresolved`로 나눠 보고한다.

1. `gh issue view --repo kwh8121/openwebui-service <번호> --json state,number,url,title,body`로 CLOSED Issue의 최종 tag·main SHA·run URL·image digest를 읽는다.
2. `gh run view <run-id> --repo kwh8121/openwebui-service --json databaseId,status,conclusion,event,headBranch,headSha,url`과 `gh api repos/kwh8121/openwebui-service/commits/<최종-tag>`를 사용한다. run은 completed/success여야 하며 Issue·run·tag의 ID, tag, SHA가 일치해야 한다.
3. `GIT_MASTER=1 git rev-parse --verify origin/main`과 `GIT_MASTER=1 git ls-remote --exit-code origin refs/heads/main`의 40자 SHA가 Issue·run·tag SHA와 모두 같은지 확인한다. 이 명령은 ref를 갱신하지 않는다.
4. 현재 런타임은 `docker inspect openwebui --format={{json .}}`로 읽는다. 컨테이너 이름은 `openwebui`, 상태는 running/healthy, `Config.Image`는 Issue와 같은 `ghcr.io/kwh8121/openwebui-service@sha256:<digest>`여야 한다.
5. `docs/jobs/`와 OpenViking은 장기 이력 참고에만 사용한다. 배포 승인과 현재 상태는 GitHub 및 현재 조회 결과로 다시 확인한다.
6. Linear는 현재 사용할 수 없는 통합으로 `unresolved`에 기록한다. Linear 항목이나 링크를 가정하거나 생성하지 않는다.
7. Mem0와 로컬 `.omo` 증적은 권위 입력에서 제외한다.

마지막에 다음 형식으로 답한다.

- `권위 증적`: 출처, 식별자, 관측 시각, 서로 일치하는 값
- `historical context`: jobs 문서 또는 OpenViking에서 얻은 관련 이력
- `unresolved`: 누락, 불일치, 접근 불가 통합
- `허용 작업`: 읽기 전용 조사 및 `feature/*` 작업만, 또는 모든 필수 증적이 최신이고 일치할 때의 분류된 변경 후보

이 명령은 배포, tag 생성, workflow dispatch, Docker·Compose 변경, `sudo`, `tar`, 백업 또는 복구를 수행하지 않는다.

명령은 위 형식을 그대로 직접 실행한다. 실행 파일 이름에 따옴표, 역슬래시, `$` 확장 또는 문자열 결합을 사용하지 않는다. 절대 도구 경로, `env`·`command`, `git -c`, shell `-c`·`-lc`, 파이프·리다이렉션·명령 치환으로 감싸지 않는다. 자식 세션은 읽기 전용 조사만 할 수 있으며 feature push도 할 수 없다.
