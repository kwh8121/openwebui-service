# GitHub Control Plane — Local ↔ Production Agent Handoff Protocol

Protocol version: **v1.0** (2026-07-31)

This document is the top-of-hierarchy authority for how the local development
agent (running in the maintainer's WSL2 workstation) and the production
deployment agent (running on the production host) coordinate releases through
GitHub. It supersedes `docs/manual/kwh-release-routine.md §7` (manual SSH
deploy path, deprecated) and takes precedence over other release docs when in
conflict.

## Purpose

Remove the maintainer's manual copy-paste between local and production
terminals. GitHub becomes the single coordination surface: Issues carry the
handoff evidence, GitHub Actions carries the executable steps, and the
`production` Environment approval is the human gate. Each agent operates in
its own lane and reads/writes only through GitHub-observable artifacts.

## 1. Prerequisites

This protocol is executable only when the following infrastructure exists.
Halt and escalate if any is missing on a real release:

| Requirement | Location | Status as of protocol v1.0 |
|---|---|---|
| Production `Environment` with required reviewer `kwh8121` | GitHub repo → Environments | ✅ exists (created 2026-07-30) |
| Per-release deploy guide template | `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md` | ✅ example at `v0.11.0-kwh.1` |
| GHCR image build workflow | `.github/workflows/docker.yaml` (trigger `v*-kwh.*` tag) | ✅ exists |
| Self-hosted runner bound to `production` Environment | Prod host, runner label documented | ⚠️ implementation deferred; interim mode uses human production agent |
| `Deploy approved production release` workflow | `.github/workflows/deploy-approved-production-release.yaml` | ⚠️ implementation deferred; interim mode uses per-release deploy guide executed by production agent |
| `Production deployment request` Issue form | `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` | ⚠️ implementation deferred; interim mode uses free-form Issue matching §6.1 schema |

**Interim mode (protocol v1.0)**: while the ⚠️ items are being implemented,
the production deployment agent may be a human operator who reads the Issue +
per-release deploy guide and executes the steps manually. The Contracts in §6
still bind both agents. Fully automated Layer B (workflow dispatch) is a
target for protocol v1.1.

## 2. Actors and Boundaries

| Actor | Owns | Never does |
|---|---|---|
| **Local development agent** (WSL2) | Code changes on `feature/*`, integration into `integration/vX.Y.Z`, local production-mirror verification, RC and final tag creation, GHCR build wait, per-release deploy guide authoring, Issue evidence submission | SSH to production, run `docker compose` on production, create production backups, execute deployment, dispatch the deployment workflow |
| **Production deployment agent** (prod host) | Reading the Issue + per-release deploy guide, executing the deploy (either by dispatching the workflow or by following the guide manually in interim mode), production backup, technical smoke, Issue reply comments per §6.2, incident handling per §7 | Modify code, create tags, rewrite tags, act without an Issue reference |
| **Maintainer (`kwh8121`)** | Approve production `Environment` gate, perform browser-only acceptance checks per §6.3, adjudicate incidents per §7, sign off release completion | Directly SSH between hosts as a manual relay of agent outputs; commit or push on behalf of the local agent from production; skip Environment approval |

## 3. Coordination Surface

Every state transition is a GitHub artifact:

```
Local agent          GitHub                      Production agent      Maintainer
────────────────     ──────────────────────      ──────────────────    ──────────
git push tag         → Actions Run (build)
                     → GHCR image + digest
Issue evidence   ──▶ Issue (open, form-filled)
                     Deploy guide file @ SHA
                                                                        Environment approve
                     ← Dispatch workflow      ←  Prod agent triggers
                     Actions Run (deploy)     ←  or begins manual exec
                                                 Backup created
                                                 Migration ran
                     ← Issue reply comment    ←  §6.2 (a) dispatched
                     ← Issue reply comment    ←  §6.2 (b) progress
                     ← Issue reply comment    ←  §6.2 (c) success
                                                                        Browser acceptance
                     ← Issue reply comment    ←                        §6.3 sign-off
                     Issue closed
```

## 4. Required Release Flow

1. Develop changes on `feature/*` and merge through `integration/vX.Y.Z`.
2. Local production-mirror verification (`scripts/local-test.sh <RC tag> --allow-rc`) must pass before opening the PR to `main`.
3. Complete required CI checks; merge PR to `main`.
4. Create the final annotated tag on the merged `main` commit. Only this format:

   ```text
   v<major>.<minor>.<patch>-kwh.<release>
   ```

5. Wait for **Build and publish GHCR release image** to succeed. Record the Run URL and the image digest.
6. Local production-mirror re-verification (`scripts/local-test.sh <final tag>`) against the final tag before requesting deployment.
7. Author the per-release deploy guide at `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`, matching the §5 template.
8. Commit the deploy guide via `feature/docs-* → integration/vX.Y.Z → main` flow so the file is reachable at a stable path on `main`.
9. Open the **Production deployment request** Issue populated per §6.1.
10. Stop. The local agent does not send terminal commands to the maintainer and does not dispatch any deployment workflow.

## 5. Per-Release Deploy Guide Template (Layer B)

Every per-release deploy guide (`kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`) MUST include these sections in this order. The production agent parses this structure. Example instance: `docs/manual/kwh-deploy-guide-v0.11.0-kwh.1.md`.

1. **Release identifiers** — version, main tip SHA, GHCR image tag, image digest (or explicit "agent fetches — see §3.4"), git-SHA parity tag, Actions Run URL, base upstream tag, fork carryovers summary, rollback target tag.
2. **Deployment overview** — what changes, upstream + fork feature summary, list of Alembic migrations that will run (with SHAs), fork carryovers preserved list.
3. **Prerequisites verification** — path checks, compose project name check, current running image check, GHCR auth + image digest capture, environment file sanity, disk space check.
4. **Pre-deployment backup (MANDATORY)** — WAL-safe procedure (stop → tar), backup path recording, integrity verification, optional online sqlite `.backup` alternative.
5. **Deployment execution** — compose env exports, dry-run config verification, `pull openwebui`, `up -d --no-deps openwebui`, immediate post-up sanity.
6. **Migration monitoring** — expected Alembic log lines, "startup complete" marker, health poll, escalation threshold.
7. **Post-deployment smoke checklist** — split by owner:
   7.1 Authentication verification (may include configuration caveats)
   7.2 Data integrity (upgrade migration verification)
   7.3 Fork carryovers (Koreatimes brand, insertSuggestionPrompt, etc.)
   7.4 Functional smoke (models, pipelines, RAG)
   7.5 Version-specific spot check (e.g., UI redesign for v0.11.x)
8. **Rollback procedure** — image-only rollback (§8.1) and full rollback with data restore (§8.2), including the failed-upgrade retention directive.
9. **Success markers to record** — table of values the production agent must capture and post back in the Issue reply.
10. **Appendix A. Environment-variable reference** — full compose env inventory for this deploy.
11. **Appendix B. External references** — the applicable doc hierarchy (this handoff → ghcr-release-deployment → kwh-release-routine → this guide).

The template is release-scoped: rollback target, digest, and migration list differ per release. Do not reuse without editing.

## 6. Contracts

### 6.1 Local Agent → Issue Evidence

Issue title: `Production deployment request: v<X.Y.Z>-kwh.<N>`

Required fields (form or free-form matching this schema):

- **Final immutable release tag** — `vX.Y.Z-kwh.N` (never `main`, never `latest`, never an RC).
- **Full commit SHA targeted by the tag** — 40-char main tip.
- **Successful GHCR build Run URL** — Actions Run link.
- **GHCR image digest** — `sha256:<64-hex>` (fetched via `docker inspect` after pull, or GHCR web UI).
- **Per-release deploy guide** — `docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md` at commit `<SHA>` (link to the exact commit).
- **Local verification results** — one line per phase: RC local verification pass/fail, final-tag local re-verification pass/fail, verifier tool version (e.g., v4.2), verifier commit SHA if applicable.
- **Migration expectation and compatibility risk** — count and IDs of Alembic migrations that will run, any known non-reversibility.
- **Fork carryover validation** — brand assets present, `insertSuggestionPrompt=true` default preserved, `WEBUI_NAME` suffix removal preserved, tool version tags.
- **Known issues and browser-only checks required** — list of items the maintainer must eyeball post-deploy.
- **Current immutable rollback tag** — the tag currently running in production.

Never include: OAuth credentials, package tokens, API keys, database contents, cookies, user data.

### 6.2 Production Agent → Issue Replies

The production agent posts one comment per lifecycle event. Fixed schemas:

**(a) Dispatched / Started**
```markdown
Deployment started.
Run: <Actions Run URL, or "manual (interim mode)">
Runner: <label, or "human operator">
Following guide: <deploy guide URL at commit SHA>
ETA: ~<N> min
```

**(b) Progress checkpoint** (post at least after backup, after migration)
```markdown
Backup: <path> (<size>)
Migrations applied: <N> / <expected>
Health: <state, e.g., waiting/healthy>
```

**(c) Success**
```markdown
Deployed successfully.
Image digest: sha256:<64-hex>
Technical smoke: PASS
  - /health returned 200
  - container logs clean (no Traceback|ERROR|Failed to start)
  - key API endpoints reachable
Backup retention: <path>
Awaiting user browser acceptance per §6.3.
```

**(d) Failure**
```markdown
FAILED at <stage from deploy guide, e.g., §4 backup / §5 execution / §6 migration / §7 smoke>.
Cause: <one-line summary>
Logs:
<fenced code block, ≤50 lines, or a link to a paste>
Rollback status: <auto-rolled-back to <tag> | halted, awaiting maintainer decision>
Guide section referenced: §<N>.<M>
Next action required: <local agent | maintainer | ready to retry>
```

### 6.3 Maintainer → Issue Acceptance

After the production agent posts (c) Success, the maintainer performs browser-only acceptance and posts one final comment:

```markdown
Browser acceptance: <PASS | PASS with follow-up | FAIL>
Checked:
- Auth: <observation>
- Brand (logo, splash, instance name, favicon): <observation>
- Suggestion card UX: <observation>
- Model chat: <observation>
- RAG upload + citation: <observation>
- Pipelines listing/connect: <observation>
- Version-specific: <observation>
Follow-up items (if any): <list, each with a suggested next-release ticket>
Release accepted / rejected.
```

After a PASS comment, the Issue is closed. A FAIL comment triggers §7 incident handling.

## 7. Incident Handling

Standing matrix. The production agent chooses actions from this table without waiting for guidance unless a row explicitly says "await maintainer".

| Trigger | Production agent immediate action | Local agent follow-up | Maintainer role |
|---|---|---|---|
| Pre-deploy backup failure (§4 of deploy guide) | Halt, no image change, post §6.2 (d) with `Rollback status: not applicable (nothing deployed)` | Diagnose (disk, permissions, tar exit code semantics) | — |
| Image pull failure (§5) | Halt, post (d) with `Rollback status: not applicable` | Verify tag exists and digest matches | If GHCR access issue, rotate token |
| Alembic migration failure (§6) | Stop new container, keep failed data dir aside as `openwebui.failed-upgrade-<TS>`, restore from pre-deploy backup, bring up prior image, post (d) with `Rollback status: auto-rolled-back-with-data-restore` | Reproduce locally, cut next `-kwh.<N+1>` tag with fix, re-run full protocol | Re-approve Environment for the retry |
| Health FAIL <3 min without migration success | Image rollback only (§8.1 of guide), post (d) with `Rollback status: auto-rolled-back-image-only` | Diagnose, cut next `-kwh.<N+1>` tag | Re-approve Environment for retry |
| Health FAIL >3 min with migration success | Full rollback: image + data restore (§8.2), post (d) with `Rollback status: full-rolled-back` | Diagnose, cut next `-kwh.<N+1>` tag | Re-approve Environment for retry |
| Technical smoke partial fail (some endpoints OK, some FAIL) | Do not auto-rollback, post (d) with `Rollback status: halted, awaiting maintainer decision` and specify what passed/failed | Wait for maintainer decision, prepare hotfix if requested | Post decision comment: `rollback` or `accept-and-hotfix-next-release` |
| Browser acceptance fail (post-deploy, maintainer initiates) | On explicit rollback request from maintainer comment, execute §8.2 and post (d) | If rollback: prepare hotfix. If accept-with-follow-up: track items for next release. | Explicit comment: `please rollback` or `accept with follow-up: <list>` |

Rollback authority summary:
- Auto-rollback conditions: migration failure, image pull success but container health fail within thresholds.
- Requires maintainer decision: partial smoke failure, post-deploy browser acceptance failure.
- Rollback re-deploy (bringing up prior tag) always re-uses the same immutable rollback target tag from §6.1; never a new tag.

Never create a corrective tag by rewriting an existing tag. Always cut `-kwh.<N+1>` after a verified fix.

## 8. State Awareness (how the local agent learns of deploy completion)

The local agent is a session-scoped process; it cannot poll indefinitely.

**Primary path**: the maintainer, upon seeing the production agent's §6.2 (c) or (d) Issue reply, resumes the local agent session and either quotes or links the Issue comment. The local agent then proceeds with follow-up (next release preparation, hotfix scoping, or acknowledgement).

**Fallback path**: the local agent, before ending its session, may hand the maintainer a short "when you receive the following, please send it back to me" instruction. The maintainer relays the (c) or (d) comment verbatim.

**Not supported**:
- Long-duration polling (`ScheduleWakeup` beyond a session) — Claude Code sessions do not persist across restarts.
- Webhook-driven session resume — no infrastructure exists in this project.
- Automated Issue-comment listening from the local agent side.

Deployments typically take 15–45 minutes in interim mode (human production agent + manual execution) or 8–15 minutes in target mode (workflow dispatch). Plan session boundaries accordingly.

## 9. Rules

- Never request a production deploy for `main`, `latest`, an RC tag, or a tag outside the final-tag pattern.
- Never treat tag creation as a completed production deploy. The production Actions workflow (or, in interim mode, the production agent's §6.2 (c) reply) is the official deployment record.
- Never instruct the maintainer to copy SSH, Docker Compose, backup, or rollback commands between local and production hosts. All executable steps for the production agent live inside the per-release deploy guide (which the production agent reads from the repo at a specific commit), never inside chat or free-form maintainer relay.
- Do not create a corrective tag by rewriting an existing tag. Cut a new immutable final tag after the fix is verified.
- The maintainer is the only party that can approve the production `Environment`. The production agent never bypasses this gate.
- The production agent must not act without a specific Issue reference. Every workflow dispatch or manual execution carries the Issue number.
- If the production agent reports migration or health failure, pause release work until §7 concludes. Image rollback may not reverse database migrations.
- Rollback re-deployments do not require a new tag; they redeploy the previous immutable tag from §6.1.
- Between-release communication (bug reports, feature requests, hotfix scoping) is out of scope for this protocol. Use standard GitHub Issues with labels `bug`, `enhancement`, or `hotfix` and reference the relevant release tag in the body.

## 10. Completion Criteria

A release is complete only when all of the following are recorded on the deployment Issue and the Issue is closed:

1. The production Actions run (or manual execution in interim mode) succeeded — evidenced by production agent's §6.2 (c) Success comment.
2. The deployed image digest and backup path were reported by the production agent — inside §6.2 (c) body.
3. Technical smoke checks passed — inside §6.2 (c) body.
4. The maintainer completed browser-only acceptance checks and posted §6.3 with `Release accepted` — or recorded accepted follow-up items with a link to their tracking Issues.

Absence of any one of these means the release is still open, regardless of the tag existing.

## 11. Versioning and References

**Protocol version**: v1.0 (2026-07-31)

**Compatible with**:
- Per-release deploy guide template v1.0 (defined in §5).
- Existing `.github/workflows/docker.yaml` (v*-kwh.* tag build).
- `production` GitHub Environment (created 2026-07-30).

**Deferred to future protocol versions**:
- v1.1 target: `.github/workflows/deploy-approved-production-release.yaml` implementation so Layer B execution is workflow-driven, removing the interim manual mode.
- v1.1 target: `.github/ISSUE_TEMPLATE/production_deployment_request.yaml` so §6.1 evidence is form-validated.
- v1.2 target (optional): automated local agent session resume on Issue comments.

**Document hierarchy (top authoritative first)**:

1. **This document** (`docs/manual/github-control-plane-local-agent-handoff.ko.md`) — coordination protocol between agents and the maintainer.
2. `docs/manual/github-actions-ghcr-release-deployment.md` — CI/CD pipeline mechanics (tag semantics, image build workflow, GHCR conventions).
3. `docs/manual/kwh-release-routine.md` — general release routine reference. §7 (manual SSH deploy) is **deprecated** by v1.0 of this protocol; retain other sections as informational context.
4. Per-release deploy guides (`docs/manual/kwh-deploy-guide-v<X.Y.Z>-kwh.<N>.md`) — release-specific execution artifacts consumed by the production agent.

**On conflict**: (1) wins over (2); (2) wins over (3) for pipeline mechanics; per-release guides (4) may override (3) for the specific release but never override (1) or (2).

**Changelog**:

- 2026-07-31 — v1.0: initial versioned release. Adds Prerequisites, Actors table, Coordination Surface diagram, Per-Release Deploy Guide Template (§5), Production Agent Reply Contract (§6.2), Maintainer Acceptance Contract (§6.3), Incident Handling matrix (§7), State Awareness (§8), Versioning (§11). Explicitly deprecates `kwh-release-routine.md §7`. Codifies interim mode until Layer B automation lands.
- 2026-07-30 — v0 draft: initial actor/scope/rules by local development agent; deployment guide `v0.11.0-kwh.1` shipped and executed in interim mode.
