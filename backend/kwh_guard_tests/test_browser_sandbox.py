"""Fork guard tests for KOR-71 (GH #81): browser Pyodide sandbox paths.

Runs with only pytest installed (.github/workflows/kwh-fork-guards.yaml).
The helper is loaded straight from its file, and this directory sits outside
the open_webui package, so open_webui/__init__.py (typer, uvicorn) is never
imported. pytest 9 imports the enclosing package during setup.

The wiring tests fail when an upstream merge drops the fork hook lines from
config.py or builtin.py even though the merge itself had no conflict.
"""

import importlib.util
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND = REPO_ROOT / 'backend' / 'open_webui'
CASES = json.loads((REPO_ROOT / 'src/lib/utils/kwh/browserSandboxRefCases.json').read_text(encoding='utf-8'))


def _load_helper():
    spec = importlib.util.spec_from_file_location('kwh_browser_sandbox', BACKEND / 'utils' / 'kwh_browser_sandbox.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


helper = _load_helper()


def test_shared_cases_are_browser_sandbox_refs():
    for ref in CASES['sandbox']:
        assert helper.is_browser_sandbox_ref(ref), ref


def test_shared_cases_are_not_browser_sandbox_refs():
    for ref in CASES['not_sandbox']:
        assert not helper.is_browser_sandbox_ref(ref), ref


def test_non_string_is_not_browser_sandbox_ref():
    assert not helper.is_browser_sandbox_ref(None)


def test_display_error_keeps_failure_contract():
    result = helper.browser_sandbox_display_error('/mnt/uploads/x.svg')
    # middleware.py and structuredOutput.ts detect a failed display by these keys.
    assert result['exists'] is False
    assert '/mnt/uploads/x.svg' in result['error']
    assert 'Files tab' in result['hint']
    assert 'Do not say the file was displayed' in result['hint']
    json.dumps(result)


def test_guidance_covers_display_rules():
    guidance = helper.PYODIDE_FILE_DISPLAY_GUIDANCE
    for phrase in ('display_file', 'sandbox:', 'plt.show()', 'Files tab', 'Do not claim the file was shown'):
        assert phrase in guidance, phrase


def test_config_appends_guidance_to_pyodide_prompt():
    source = (BACKEND / 'config.py').read_text(encoding='utf-8')
    assert re.search(
        r'from\s+open_webui\.utils\.kwh_browser_sandbox\s+import\s+\(?\s*PYODIDE_FILE_DISPLAY_GUIDANCE', source
    )
    assert re.search(r'CODE_INTERPRETER_PYODIDE_PROMPT\s*\+=\s*PYODIDE_FILE_DISPLAY_GUIDANCE', source)


def test_display_file_returns_browser_sandbox_error():
    source = (BACKEND / 'tools' / 'builtin.py').read_text(encoding='utf-8')
    match = re.search(r'async def display_file\(.*?\n(?=async def |def )', source, re.S)
    assert match, 'display_file not found in builtin.py'
    body = match.group(0)
    assert re.search(r'if\s+is_browser_sandbox_ref\(\s*path\s*\)', body)
    assert re.search(r'browser_sandbox_display_error\(\s*path\s*\)', body)
