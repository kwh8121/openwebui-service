"""Fork-owned (kwh) guidance for files that live in the browser Pyodide sandbox.

Pyodide runs in the user's browser, so files written to ``/mnt/...`` by
``execute_code`` never reach the server. ``display_file`` cannot open them, and
``sandbox:`` or ``/mnt/...`` links in a reply render as a placeholder or a dead
link. See GitHub kwh8121/openwebui-service#81 and Linear KOR-71.

Keep this module free of open_webui imports: the fork guard CI loads it on its
own with only pytest installed.
"""

import re

_BROWSER_SANDBOX_REF = re.compile(r'^(?:sandbox:|/mnt/|file:///mnt/)', re.IGNORECASE)

PYODIDE_FILE_DISPLAY_GUIDANCE = """

##### Showing Files to the User

- Files in `/mnt/` exist only in the user's browser. The server cannot see them, so `display_file` cannot open them.
- Never call `display_file` for a `/mnt/` path, and never write Markdown images or links that point to `sandbox:` or `/mnt/` paths. They do not render for the user.
- To show a chart or figure, draw it with matplotlib and call `plt.show()`; the image is then shown in the chat automatically.
- For other output files, tell the user the file path and that they can preview or download it from the Files tab of this chat, in this browser, while Code Interpreter is on. The file may not exist on other devices or browsers.
- If a tool reports that a file could not be displayed, say so plainly. Do not claim the file was shown."""


def is_browser_sandbox_ref(path: str) -> bool:
    """Return True if ``path`` points into the browser Pyodide sandbox."""
    if not isinstance(path, str):
        return False
    return bool(_BROWSER_SANDBOX_REF.match(path.strip()))


def browser_sandbox_display_error(path: str) -> dict:
    """Failure result for ``display_file`` called with a browser sandbox path.

    Keeps the ``exists: False`` and ``error`` keys that callers use to detect
    a failed display.
    """
    return {
        'error': (
            f'{path} is in the browser code sandbox (Pyodide). The server cannot read it, so it was not displayed.'
        ),
        'exists': False,
        'hint': (
            'Do not say the file was displayed, and do not link to sandbox: or /mnt/ paths. '
            'Tell the user to open the Files tab of this chat, in this browser with Code Interpreter on, '
            'to preview or download it. It may not exist on other devices or browsers. '
            'For charts, use matplotlib plt.show() so the image appears in the chat.'
        ),
    }
