# Open WebUI Jobs Log — 2026-07-21

> Resume: `claude --resume 4c3bc5d0-fce4-4c2b-9d41-7b8e258c2d0f

## 요약

- 계층형 `AGENTS.md` 문서화(level 1–2, 10개 디렉토리) 완료
- 릴리스 워크플로(`feature/*` → `integration/vX.Y.Z` → `main`)에 따라 `main`까지 병합
- 문서 전용 변경이므로 태그/이미지 재빌드/배포는 생략
- 최종 `main` HEAD: `8b68b8a62 Merge pull request #2 from kwh8121/integration/v0.10.2`

## 작업 흐름

### 1. feature 브랜치 생성 및 AGENTS.md 작성

- 브랜치: `feature/agents-md-deepinit`
- 신규 파일 10개 (각 `<!-- Parent: ../AGENTS.md -->` 포함):

| 파일                           | 라인 | 크기 |
| ------------------------------ | ---- | ---- |
| `backend/AGENTS.md`            | 53   | 2.5K |
| `backend/open_webui/AGENTS.md` | 69   | 4.6K |
| `src/AGENTS.md`                | 50   | 2.4K |
| `src/lib/AGENTS.md`            | 63   | 4.1K |
| `src/routes/AGENTS.md`         | 55   | 3.2K |
| `docs/AGENTS.md`               | 50   | 2.3K |
| `scripts/AGENTS.md`            | 40   | 1.8K |
| `test/AGENTS.md`               | 37   | 1.6K |
| `pipelines/AGENTS.md`          | 49   | 2.7K |
| `.github/AGENTS.md`            | 49   | 2.3K |

- 루트 `AGENTS.md`는 기존 수동 작성 유지 (미변경)
- 검증: 부모 참조 11개 모두 유효 / 오르판 없음 / trailing whitespace 0

### 2. Integration 브랜치 동기화 및 병합

- 발견: `origin/integration/v0.10.2`가 `main`보다 2 커밋 뒤처짐 (PR #1은 이미 병합됨)
- 절차:
  1. `git checkout -b integration/v0.10.2 origin/integration/v0.10.2`
  2. `git merge main --ff-only` (fdd489419 → a76cf2ac2)
  3. `git merge --no-ff feature/agents-md-deepinit`

### 3. PR #2 생성

- URL: <https://github.com/kwh8121/openwebui-service/pull/2>
- Base: `main`, Head: `integration/v0.10.2`
- Title: `docs: add hierarchical AGENTS.md for level 1-2 directories`
- 본문: 리포 PR 템플릿(Checklist / Changelog Entry / CLA) 준수

### 4. CI 실패 대응 (Prettier)

- **1차 CI**: Format & Build ❌ / Ruff ✅ / Unit Tests ✅
- 원인: `.prettierrc` 규칙에 따른 헤딩 뒤 빈 줄 부재 + 테이블 컬럼 미정렬
- 로컬 포맷팅 장애물 3가지:
  1. Node v24.14.1 / npm 11.12.1이 `package.json` engines(`>=18.13.0 <=22.x.x`) 벗어남 → `npm install`이 exit 0로 종료하지만 실제로는 설치 안 됨
  2. `.prettierrc`의 `pluginSearchDirs: ["."]`가 로컬 `node_modules`에서 `prettier-plugin-svelte`를 강제 참조
  3. RTK(Rust Token Killer) 프록시가 `prettier`, `gh pr checks --watch` 출력을 가로채 잘못된 성공/집계 반환
- 해결:

  ```bash
  npm install --no-save --engine-strict=false --no-audit --no-fund --ignore-scripts \
    prettier@3.3.3 prettier-plugin-svelte@3.2.6
  ./node_modules/.bin/prettier --write <AGENTS.md files>
  ```

- 결과: 10 files, +174 -114

### 5. 최종 CI 통과 및 병합

| Check              | Status  | Duration |
| ------------------ | ------- | -------- |
| Format & Build     | ✅ pass | 3m21s    |
| Ruff Format (3.11) | ✅ pass | 9s       |
| Ruff Format (3.12) | ✅ pass | 14s      |
| Unit Tests         | ✅ pass | 37s      |

- `gh pr merge 2 --repo kwh8121/openwebui-service --merge`
- MERGED at 2026-07-21T06:22:23Z
- 로컬 `main`은 `origin/main`과 동기화 완료

## 커밋 / PR

- `b011825c4` `docs: add hierarchical AGENTS.md for level 1-2 directories` (feature/agents-md-deepinit)
- `1cf8da592` `merge: add hierarchical AGENTS.md documentation` (`--no-ff` 병합 커밋, integration/v0.10.2)
- `dcba1c957` `style: apply prettier to AGENTS.md files` (CI 대응)
- `8b68b8a62` `Merge pull request #2 from kwh8121/integration/v0.10.2` (main HEAD)
- **PR #2**: <https://github.com/kwh8121/openwebui-service/pull/2>

## 학습 사항

- **Node/npm 엔진 불일치**: 로컬 Node v24를 사용 중이지만 프로젝트는 `<=22.x.x` 요구. 전체 install 실패는 exit 0로 숨어 있음. 빠른 우회는 `npm install --engine-strict=false --no-save --ignore-scripts <필요 패키지>`.
- **Prettier 실행 전제**: `.prettierrc`의 `pluginSearchDirs: ["."]`로 `prettier-plugin-svelte`가 로컬 `node_modules`에 반드시 있어야 함. `.md`만 포맷할 때도 동일.
- **RTK 프록시 주의**: `prettier`, `gh pr checks --watch` 등의 stdout을 요약/왜곡. Raw 확인은 `rtk proxy "<cmd>"`.
- **integration/vX.Y.Z 재사용**: 이미 `main`으로 병합된 integration 브랜치도 재사용 가능. 사용 전 `main` 동기화(`--ff-only` merge) 후 feature를 `--no-ff` 병합하면 히스토리가 깔끔.
- **PR 템플릿 vs fork 규칙**: PR 템플릿은 upstream 원본이라 "target `dev`" 문구가 있으나 이 fork에서는 `main`이 정답. CLA 섹션은 반드시 보존.
- **병합 전략**: PR #1과 동일하게 `gh pr merge --merge`로 병합 커밋 방식 유지 (스쿼시/리베이스 사용 안 함).

## 다음 후보 작업

- 깊이 3 이상 (`backend/open_webui/routers/`, `src/lib/components/*/`, `src/routes/(app)/*/` 등)까지 AGENTS.md 확장
- 다음 upstream 릴리스(`v0.10.3+`) 오면 새 `integration/vX.Y.Z` 브랜치로 통합
- 로컬 Node 버전을 `.nvmrc`/`mise`로 22.x 고정하여 engine 경고 제거
