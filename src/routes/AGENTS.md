<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-07-20 | Updated: 2026-07-20 -->

# routes

## Purpose
SvelteKit file-based router. Each folder is a URL segment; `+page.svelte` renders a page, `+layout.svelte` wraps children, `+layout.js` runs on both server and client for load logic, and `+error.svelte` is the error boundary. `(app)` is a **route group** (parentheses in the folder name are hidden from the URL) — it holds all pages that require an authenticated session and shares a common layout with sidebar, header, and socket wiring.

## Key Files

| File | Description |
|------|-------------|
| `+layout.svelte` | Root layout — theme, i18n bootstrap, global toast/notification host, Socket.IO connection |
| `+layout.js` | Root load — reads config, hydrates auth state before rendering |
| `+error.svelte` | Root error boundary rendered on load or render failure |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `(app)/` | Authenticated app shell (route group; not a URL segment). Contains `admin/`, `automations/`, `c/` (chats), `calendar/`, `channels/`, `home/`, `notes/`, `playground/`, `workspace/`, plus the app-level `+layout.svelte` and default `+page.svelte`. |
| `auth/` | Sign-in / sign-up / OAuth callback flows — unauthenticated |
| `error/` | Standalone error routes (e.g. hard failures that bypass the app shell) |
| `s/` | Public shared chat viewer — `s/[id]` renders a chat by share ID |
| `watch/` | Live/streaming viewer routes |

## For AI Agents

### Working In This Directory
- Follow SvelteKit conventions strictly: use `+page.svelte`, `+layout.svelte`, `+page.js`/`+page.server.js` — not arbitrary filenames.
- New authenticated pages go under `(app)/`. Do not create a peer top-level folder unless the page must be reachable while signed out.
- Route groups (folders with parentheses) do not appear in the URL — do not use them to disambiguate paths, only to share layouts.
- Load functions in `+layout.js` run on both server and client with `adapter-static`; keep them free of Node-only APIs.
- Reference shared code with `$lib/...`; never with relative paths that climb out of `src/`.

### Testing Requirements
- Type check: `npm run check` (SvelteKit sync + svelte-check).
- Component/page tests: `npm run test:frontend -- src/routes/<path>` (Vitest).
- Manual smoke: `npm run dev` (Vite on 5173) alongside `../backend/dev.sh` (port 8080); the layout wires Socket.IO to the backend.

### Common Patterns
- Route folders are grouped by feature under `(app)/` — mirror an existing folder's structure when adding a peer.
- Long-lived UI (sidebar, chat pane, header) lives in `(app)/+layout.svelte`; per-page state lives in the page's own `+page.svelte`.
- Query params and route params are read from `$page.url.searchParams` and `$page.params` respectively.

## Dependencies

### Internal
- Every route imports heavily from `../lib/` (`$lib/components`, `$lib/apis`, `$lib/stores`, `$lib/i18n`).
- Root layout wires `socket.io-client` to the backend Socket.IO server (`../../backend/open_webui/socket/`).

### External
- `@sveltejs/kit`, `svelte@5`, `svelte-sonner` (toasts), `socket.io-client`, `i18next` — see `../../package.json`.

<!-- MANUAL: -->
