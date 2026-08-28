# Open WebUI Jobs Log — 2026-08-10

## 요약

- Orca ADE 도입 관련 초기 진단: Windows 설치된 Orca가 WSL의 `gh` CLI를 감지하지 못함 (설정 위치 = `Local Windows`). 해결책 두 방향(Windows에 gh 설치 vs Orca 원격 서버로 WSL 연결) 제시. 프로젝트가 WSL 기반이라 원격 서버 방식 권장.
- Orca `Automations` 기능 확인: cron/preset 트리거 기반 반복 프롬프트 실행. `orca automations create` CLI로 관리. Artifacts는 공식 문서 부재(404) 상태로 UI 사이드바 항목만 존재.
- Linear MCP 서버 로컬 등록: `claude mcp add --transport http linear-server https://mcp.linear.app/mcp`. OAuth 인증 완료 (koreatimes 워크스페이스 연결).
- Linear 이슈 조회: 온보딩 4건만 존재 (KOR-1~4). 실작업 이슈 아직 없음.
- Linear MCP 도구 54개 카탈로그화 완료. 이 프로젝트에서의 4가지 활용 시나리오(A: 릴리스 워크플로우 이관, B: 개발↔검증 에이전트 인계, C: jobs log 이관, D: GitHub PR ↔ Linear 이슈 자동 연결) 정리.

## 시나리오 B 채택 결정

사용자가 개발↔검증 에이전트 인계 표면으로 **Linear 이슈 기반 시나리오 B**를 선택. Linear 실사용 경험 및 효용성 평가를 겸해 단계별 테스트 진행 예정.

**시나리오 B 개요**:

- 개발 에이전트: `save_issue`로 "검증 요청" 이슈 생성 (feature 브랜치·커밋 SHA 포함)
- 검증 에이전트: `list_issues --label "verify-request"`로 pickup → 결과를 `save_comment`로 회신
- Linear가 assignee/status/label로 인계 상태 자동 추적

## Linear MCP 도구 카탈로그 (54개)

**이슈**: `list_issues`, `get_issue`, `save_issue`, `list_issue_statuses`, `get_issue_status`, `list_issue_labels`, `create_issue_label`
**댓글/상태**: `list_comments`, `save_comment`, `delete_comment`, `get_status_updates`, `save_status_update`, `delete_status_update`
**프로젝트/마일스톤/사이클**: `list_projects`, `get_project`, `save_project`, `list_project_labels`, `list_milestones`, `get_milestone`, `save_milestone`, `list_cycles`
**문서**: `list_documents`, `get_document`, `save_document`, `search_documentation`
**팀/사용자/워크스페이스**: `list_teams`, `get_team`, `list_users`, `get_user`, `get_workspace`
**릴리스**: `list_releases`, `get_release`, `save_release`, `list_release_notes`, `get_release_note`, `save_release_note`, `list_release_pipelines`
**Diff/리뷰**: `list_diffs`, `get_diff`, `get_diff_threads`, `save_diff_comment`, `delete_diff_comment`, `resolve_diff_thread`, `submit_diff_review`, `merge_diff`
**첨부**: `get_attachment`, `create_attachment`, `create_attachment_from_upload`, `prepare_attachment_upload`, `delete_attachment`, `extract_images`
**에이전트 스킬**: `list_agent_skills`, `get_agent_skill`

## 학습 사항

- **Orca gh 미감지 원인 = 환경 격리**: Windows 데스크톱 앱이 WSL PATH를 보지 못하는 게 근본 원인. 도구 부재가 아님. 이 프로젝트처럼 WSL 안에 저장소·스크립트가 있으면 Orca 원격 서버 연결이 맞다.
- **Linear 페어링 URL 보안 주의**: `orca://pair?code=...` 링크의 `code=` 뒤 문자열은 `deviceToken` + `publicKey`이므로 유출 시 재발급 필요. 채팅/이슈에 원문 붙여넣기 금지.
- **Linear MCP OAuth flow의 WSL 특이성**: `localhost:port/callback` 리다이렉트가 WSL에서 Windows 브라우저와 연결되지 않아 "연결 실패" 페이지가 뜨지만 정상. 주소창 URL을 그대로 복사해 `complete_authentication`에 전달하면 됨.
- **문서화되지 않은 UI 기능은 GitHub 저장소 확인**: Orca Artifacts처럼 공식 문서에 없는 기능은 `github.com/stablyai/orca`에서 확인이 확실함.
