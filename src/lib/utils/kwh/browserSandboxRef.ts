// Fork-owned (kwh). Linear KOR-71, GitHub #81.
//
// Pyodide runs in the browser, so files that execute_code writes to /mnt never
// reach the server. A `sandbox:` or `/mnt/...` image or link in a reply cannot
// load: safeImageUrl turns `sandbox:` into the placeholder logo and `/mnt/...`
// becomes a 404. The chat renderer shows a notice for these refs instead.
//
// Keep this rule in sync with backend/open_webui/utils/kwh_browser_sandbox.py.
// Both sides are tested against browserSandboxRefCases.json.

const BROWSER_SANDBOX_REF = /^(?:sandbox:|\/mnt\/|file:\/\/\/mnt\/)/i;

export const isBrowserSandboxRef = (href: unknown): boolean =>
	typeof href === 'string' && BROWSER_SANDBOX_REF.test(href.trim());
