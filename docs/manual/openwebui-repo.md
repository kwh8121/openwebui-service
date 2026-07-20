제가 권장하는 구조는 이겁니다.

origin = 내 레포: kwh8121/openwebui-service

예:

이후 공식 업데이트는:

# 또는 충돌 관리가 익숙하면 rebase

git push origin main

이 방식의 장점은 명확합니다.

origin/main = 내가 운영하는 레포 상태
upstream/main = 공식 Open WebUI 상태

현재 방식보다 git status, git branch -vv, GitHub PR, CI/CD, 배포 자동화에서 훨씬 덜 헷갈립니다.

운영 추천안은:

origin = kwh8121/openwebui-service
upstream = open-webui/open-webui
배포 = kwh8121 레포에서 빌드한 고정 태그 이미지 사용

기존 운영 파일은 건드리지 않고, 같은 서비스명/포트/볼륨/네트워크를 유지해서 docker compose -f
docker-compose-build.yaml up -d --build openwebui로 공식 이미지 대신 로컬 빌드 이미지를 띄울 수 있게 하겠습니다.

• 권장 구조는 내 레포를 origin, 공식 Open WebUI를 upstream 으로 분리하는 방식입니다.

목표 구조

origin = https://github.com/kwh8121/openwebui-service.git
upstream = https://github.com/open-webui/open-webui.git

이렇게 되면 의미가 명확해집니다.

origin/main = 내가 운영/배포하는 코드
upstream/main = 공식 Open WebUI 최신 코드

전환 계획

1. 현재 상태 백업 확인

git status --short --branch
git remote -vv
git log -1 --oneline --decorate

2. origin을 내 레포로 변경

git remote set-url origin https://github.com/kwh8121/openwebui-service.git

3. 공식 Open WebUI를 upstream으로 추가

git remote add upstream https://github.com/open-webui/open-webui.git

이미 upstream이 있으면:

git remote set-url upstream https://github.com/open-webui/open-webui.git

4. 원격 상태 확인

git remote -vv

기대 결과:

upstream https://github.com/open-webui/open-webui.git (fetch)
upstream https://github.com/open-webui/open-webui.git (push)

upstream은 push하지 않을 것이므로 push URL이 보여도 문제는 없습니다. 더 엄격하게 하려면 upstream push를 막을 수도 있습니다.

git remote set-url --push upstream DISABLED

5. 공식 업데이트 가져오기

git fetch upstream --tags

6. 내 브랜치에 공식 변경 반영

보수적인 운영이면 merge 권장:

git checkout main
git merge upstream/main

히스토리를 깔끔하게 유지하고 충돌 해결에 익숙하면 rebase:

git checkout main
git rebase upstream/main

운영 레포에서는 보통 merge가 더 안전합니다.

7. 내 레포로 push

git push origin main

운영 브랜치 전략 권장

main = 실제 운영/배포 기준
dev = 개발 통합 브랜치
feature/_ = 기능 개발 브랜치
upstream/_ = 공식 Open WebUI 추적 전용

일상 흐름은 이렇게 가져가면 됩니다.

git fetch upstream --tags
git checkout main
git merge upstream/main

# 충돌 해결 및 테스트

git push origin main

Docker 운영 흐름

공식 이미지를 직접 쓰는 대신, 내 레포 코드로 빌드한 이미지를 태그로 고정하는 흐름이 좋습니다.

코드: kwh8121/openwebui-service
이미지: ghcr.io/kwh8121/openwebui-service:0.10.2-kwh.1
배포: docker-compose-build.yaml 또는 운영 compose에서 해당 이미지 사용

권장 태그 예:

0.10.2-kwh.1
0.10.2-kwh.2
0.10.3-kwh.1

최종 권장 운영 원칙

공식 변경은 upstream에서 가져온다.
내 변경은 origin에만 push한다.
운영 배포는 origin 코드로 빌드한 고정 태그 이미지를 사용한다.
공식 :main 이미지는 운영에서 직접 쓰지 않는다.
