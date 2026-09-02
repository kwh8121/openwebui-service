# GitHub Actions 및 GHCR 릴리스 배포

> **권위**: 이 문서는 CI/CD 메커니즘(태그 규칙·GHCR 관례·이미지 빌드 정책)에 대한 권위 문서입니다. 릴리스·배포 **협업 규약**에서 충돌이 생기면 `docs/manual/github-control-plane-local-agent-handoff.ko.md`(Protocol v1.2)가 우선합니다. 실무 절차는 `docs/manual/kwh-release-routine.md`를 참조하십시오.

## 목적

Open WebUI 이미지를 프로덕션 서버 밖에서 빌드하고, immutable 이미지를 GitHub Container Registry(GHCR)에 발행하며, 검증된 이미지 태그만 배포합니다. 이렇게 하면 소스 빌드가 프로덕션의 CPU·메모리·디스크 I/O·네트워크 자원을 잠식하지 않습니다.

## 저장소 역할

| 리모트     | 역할                                                                                |
| ---------- | ----------------------------------------------------------------------------------- |
| `origin`   | `https://github.com/kwh8121/openwebui-service.git` — 운영 fork이자 유일한 push 대상 |
| `upstream` | `https://github.com/open-webui/open-webui.git` — 공식 Open WebUI, fetch 전용        |

`upstream`의 push URL은 `DISABLED`로 설정해 공식 저장소로의 실수 push를 차단합니다.

## 브랜치 및 릴리스 흐름

1. upstream 소스를 가져옵니다. **`git fetch upstream --tags`는 사용하지 않습니다** — fork에 이미 동명 태그(`v0.10.2`, `v0.11.0` 등)가 있어 `rejected (would clobber existing tag)`로 항상 실패합니다. 대신:

   ```bash
   git fetch upstream --no-tags                                    # 브랜치만 갱신
   git fetch upstream refs/tags/vX.Y.Z:refs/tags/upstream/vX.Y.Z   # 필요한 태그만 upstream/ 네임스페이스로 분리 저장
   ```

   `git fetch upstream --tags --force`는 fork의 릴리스 태그 이력을 덮어쓰므로 사용하지 않습니다.

2. 현재 `main`에서 `integration/vX.Y.Z`를 생성하거나 갱신합니다.
3. 선택한 공식 릴리스를 integration 브랜치에 병합합니다 (위에서 분리 저장한 `upstream/vX.Y.Z` 태그 참조).
4. 커스텀 변경은 `feature/*` 브랜치에서 개발하고 `--no-ff`로 integration 브랜치에 병합합니다.
5. CI를 통과시키고, **RC 태그를 발행해 GH Actions가 빌드한 이미지를 로컬 프로덕션 미러 게이트(`scripts/local-test.sh`)로 검증합니다.** 운영 호스트에 병렬 기동하던 스테이징 검증 방식은 폐기됐습니다 (`docs/plan/local-test-workflow.md` v4 참조).
6. `integration/vX.Y.Z`에서 `main`으로 pull request를 엽니다.
7. 리뷰와 로컬 게이트 통과 후에만 병합합니다.
8. 승인된 `main` 커밋에서 `vX.Y.Z-kwh.N` 형식의 릴리스 태그를 만듭니다.

`main`이 운영 진실 소스입니다. integration이나 feature 브랜치에서 직접 배포하지 않습니다.

## 이미지 빌드 정책

GitHub Actions가 다음 위치로 이미지를 빌드·push합니다.

```text
ghcr.io/kwh8121/openwebui-service
```

immutable 릴리스 태그와 커밋 태그를 사용합니다.

```text
vX.Y.Z-kwh.N          # 예: v0.11.1-kwh.2
git-<7자리-short-sha>  # 예: git-3540e97
```

GHCR 이미지 태그는 git 태그를 **`v` 접두사를 포함해 그대로** 보존합니다. 워크플로가 `docker/metadata-action`의 `type=ref,event=tag`를 `semver` 가공 없이 사용하기 때문입니다. 커밋 SHA 태그는 `type=sha,prefix=git-`을 사용하며 기본값인 7자리 short SHA가 붙습니다.

프로덕션 배포에 `main`이나 `latest` 같은 mutable 태그를 사용하지 않습니다. Buildx registry 캐시는 GHCR에 저장되어 `cache-from` / `cache-to`로 CI 실행 간 공유되며, 변경되지 않은 프론트엔드·Python 의존성 레이어를 재사용합니다. 워크플로는 `v*-kwh.*` 패턴 태그만, `linux/amd64`에 대해서만 빌드합니다 — 현재 배포 호스트와 일치합니다.

`main` 병합 전에 integration 브랜치에서 `vX.Y.Z-kwh.N-rc.1` 같은 RC 태그를 만들어 검증용 이미지를 생성할 수 있습니다. 최종 태그는 병합된 `main` 커밋에서만 만듭니다.

워크플로에는 `contents: read`와 `packages: write` 권한이 필요합니다. private GHCR 이미지를 pull하는 프로덕션 서버는 별도의 read-only 패키지 토큰을 사용해야 하며, GitHub Actions의 `GITHUB_TOKEN`을 서버로 복사해서는 안 됩니다.

## 배포 정책

`docker-compose-build.yaml`은 개발 빌드 전용이며 `build:` 섹션을 유지합니다. 프로덕션 배포 정의로 사용해서는 안 됩니다.

`docker-compose.deploy.yaml`이 프로덕션 정의입니다. 이 파일은:

- `build:` 섹션이 없습니다.
- `ghcr.io/kwh8121/openwebui-service:${OPENWEBUI_IMAGE_TAG}`를 참조합니다.
- 기존 포트·네트워크·환경 파일·bind mount를 보존합니다.
- 컨테이너 교체 시에도 `/app/backend/data`와 `/app/pipelines`를 유지합니다.

`docker-compose.local-test.yaml`이 검증용 정의입니다. 로컬에서 openwebui + pipelines를 프로덕션과 동일한 구성으로 기동하며, 별도 데이터 디렉터리와 localhost 전용 포트를 사용합니다. `scripts/local-test.sh`가 이를 구동합니다.

`docker-compose.staging.yaml`은 **폐기 경로**입니다. 운영 호스트에 co-located된 compose 수준 격리만 제공해 물리 격리가 없으며, 이미지 결함이 자원 경합을 통해 프로덕션 컨테이너에 파급될 수 있습니다. 로컬 프로덕션 미러 게이트로 대체됐습니다. 어떤 경우에도 프로덕션 데이터 디렉터리를 마운트해서는 안 됩니다.

**프로덕션 배포는 GitHub Issue 핸드오프로 수행합니다.** `Production deployment request` Issue를 제출하면 opencode 프로덕션 에이전트가 `deploy-approved-production-release.yaml` 워크플로로 실행합니다. 이 워크플로가 태그·계보·가이드 검증, 롤백 이미지 확보, digest pin, SQLite WAL-safe 백업, `--no-deps` 재기동, 스모크 검증을 자동 수행합니다. 계약 상세는 `docs/manual/github-control-plane-local-agent-handoff.ko.md`(Protocol v1.2)를 따릅니다. 로컬 에이전트가 프로덕션에 직접 SSH로 배포하지 않습니다.

워크플로가 내부적으로 사용하는 배포 형태는 고정 이미지 태그로 Open WebUI만 재생성하는 방식입니다.

```bash
docker compose -f docker-compose.deploy.yaml pull openwebui
docker compose -f docker-compose.deploy.yaml up -d --no-deps openwebui
```

배포 전 `/app/backend/data`와 `/app/pipelines`를 백업합니다. 배포 후 health 엔드포인트·인증·모델 요청·RAG 검색·파일 업로드·pipeline 연결을 검증합니다. 롤백은 이전 이미지 태그를 복원하는 방식입니다. **이미지 롤백이 DB 마이그레이션을 되돌리지는 않습니다.**

## 모델 캐시 고려사항

Dockerfile은 non-slim 이미지 빌드 중 embedding·Whisper 자산을 내려받습니다. 런타임의 `/app/backend/data` bind mount가 이 이미지 레이어 캐시를 가릴 수 있습니다.

로컬 검증에서는 이 문제가 해결돼 있습니다. `scripts/local-test.sh`가 이미지 pull 직후 `docker create` + `docker cp`로 이미지의 `/app/backend/data/cache`를 host bind mount에 seed하므로, 첫 실행 시 HuggingFace에서 약 250 MB를 재다운로드하는 일이 없습니다. 릴리스에 새 번들 모델이 추가됐을 때는 `--reseed-cache` 플래그로 강제 재복사합니다. 상세는 `docs/plan/local-test-workflow.md` v4.1.

프로덕션에서 이 동작(예: slim 빌드 전환, 모델 캐시 별도 영속화)을 바꾸려면, 먼저 로컬 프로덕션 미러 게이트에서 첫 RAG·오디오 요청과 cold-start 시간을 확인하십시오.
