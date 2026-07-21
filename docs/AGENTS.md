<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# docs

## Purpose

Internal research notes, security policy, and operator/integration guides for the Open WebUI deployment maintained in this repository. `SECURITY.md` is the upstream security policy; the `openwebui-*-research.md` files are internal write-ups scoped to feature areas (chat, RAG, security, operations, extensibility, workspace collaboration). `manual/` holds operator playbooks for specific integrations.

## Key Files

| File                                            | Description                                         |
| ----------------------------------------------- | --------------------------------------------------- |
| `SECURITY.md`                                   | Security policy — vulnerability reporting and scope |
| `openwebui-research-index.md`                   | Index into the other research documents             |
| `openwebui-access-security-research.md`         | Access control, auth, and permission model notes    |
| `openwebui-chat-research.md`                    | Chat pipeline and message flow notes                |
| `openwebui-extensibility-research.md`           | Plugin/pipeline/tool extensibility surface          |
| `openwebui-knowledge-rag-research.md`           | Knowledge base and RAG retrieval design notes       |
| `openwebui-operations-research.md`              | Deployment and ops considerations                   |
| `openwebui-newsroom-blueprint.md`               | Newsroom-specific workflow blueprint                |
| `openwebui-workspace-collaboration-research.md` | Multi-user workspace collaboration notes            |

## Subdirectories

| Directory | Purpose                                                                                                                                   |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `manual/` | Operator/integration notes — GHCR release, OAuth registration, migrations, Korean locale, upstream repo pointers (see `manual/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- These are living documents. When updating a research doc, keep the front-matter/section structure intact and add dated entries rather than rewriting history.
- `SECURITY.md` should generally track upstream — do not diverge without a specific reason.
- New research files should follow the `openwebui-<topic>-research.md` naming pattern and be added to `openwebui-research-index.md`.

### Testing Requirements

- None — these are prose documents. Prettier will still format `.md` files via `npm run format`.

### Common Patterns

- Markdown, no front-matter. Reference other docs with relative links.

## Dependencies

### Internal

- Referenced from PR descriptions and the root `AGENTS.md` guidance.

### External

- None.

<!-- MANUAL: -->
