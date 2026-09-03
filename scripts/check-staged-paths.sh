#!/usr/bin/env bash

set -euo pipefail

blocked_paths=()

while IFS= read -r -d '' path; do
	case "${path}" in
	.omo/* | .env* | */.env* | .opencode/opencode.json | .opencode/skills/*)
		blocked_paths+=("${path}")
		;;
	esac
done < <(GIT_MASTER=1 git diff --cached --name-only --no-renames -z --)

if ((${#blocked_paths[@]} > 0)); then
	printf '오류: 스테이징이 금지된 로컬 또는 민감 경로가 포함되어 있습니다.\n' >&2
	printf '  - %s\n' "${blocked_paths[@]}" >&2
	exit 1
fi

printf '스테이징 경로 검사를 통과했습니다.\n'
