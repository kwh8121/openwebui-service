"""Exercise deployment workflow shell steps without touching production services."""

import os
import re
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


WORKFLOW = Path(__file__).resolve().parents[1] / 'workflows/deploy-approved-production-release.yaml'
EXPRESSIONS = {
    'inputs.tag': 'v0.11.4-kwh.1',
    'inputs.issue_number': '49',
    'inputs.guide_commit': 'abc123',
    'github.repository': 'kwh8121/openwebui-service',
    'github.server_url': 'https://github.com',
    'github.run_id': '12345',
}


def step_script(name):
    lines = WORKFLOW.read_text().splitlines()
    marker = f'      - name: {name}'
    start = lines.index(marker)
    run = next(i for i in range(start + 1, len(lines)) if lines[i] == '        run: |')
    body = []
    for line in lines[run + 1 :]:
        if line and not line.startswith('          '):
            break
        body.append(line)
    script = textwrap.dedent('\n'.join(body))

    def substitute(match):
        return EXPRESSIONS[match.group(1).strip()]

    return re.sub(r'\$\{\{\s*([^}]+?)\s*\}\}', substitute, script)


class DeployBackupWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.env_file = self.root / 'github-env'
        self.env_file.touch()
        self.calls = self.root / 'docker-calls'
        self.env = os.environ.copy()
        self.env.update(
            PATH=f'{self.bin}:{os.defpath}',
            GITHUB_ENV=str(self.env_file),
            DEPLOY_DIR=str(self.root),
            COMPOSE_FILE=str(self.root / 'compose.yaml'),
            COMPOSE_PROJECT='test',
            DATA_DIR=str(self.root / 'data'),
            ENV_FILE=str(self.root / 'oauth.env'),
            PIPELINES_DATA=str(self.root / 'pipelines'),
            BACKUP_DIR=str(self.root),
            RUNNER_TEMP=str(self.root),
            MOCK_DOCKER_CALLS=str(self.calls),
            MOCK_GH_ARGS=str(self.root / 'gh-args'),
        )

    def mock(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\nset -euo pipefail\n' + textwrap.dedent(body))
        path.chmod(0o755)

    def run_step(self, name):
        return subprocess.run(
            ['bash', '-c', step_script(name)],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_rollback_anchor_fails_when_compose_ps_errors(self):
        self.mock('docker', 'if [[ "$*" == *"ps -q openwebui"* ]]; then exit 7; fi\n')
        result = self.run_step('Capture current running image (rollback anchor)')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('CURRENT_IMAGE=unknown', self.env_file.read_text())

    def test_rollback_anchor_fails_when_container_is_absent(self):
        self.mock('docker', 'if [[ "$*" == *"ps -q openwebui"* ]]; then exit 0; fi\n')
        result = self.run_step('Capture current running image (rollback anchor)')
        self.assertNotEqual(result.returncode, 0)

    def test_rollback_anchor_records_existing_image(self):
        self.mock(
            'docker',
            """
            if [[ "$*" == *"ps -q openwebui"* ]]; then echo abc123; exit 0; fi
            if [[ "$*" == *"inspect abc123"* ]]; then
              echo ghcr.io/kwh8121/openwebui-service:v0.11.3-kwh.1
              exit 0
            fi
            exit 9
            """,
        )
        result = self.run_step('Capture current running image (rollback anchor)')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('CURRENT_TAG=v0.11.3-kwh.1', self.env_file.read_text())

    def test_env_copy_failure_does_not_stop_service(self):
        self.mock('docker', 'echo "$*" >> "$MOCK_DOCKER_CALLS"\n')
        self.env['CURRENT_TAG'] = 'v0.11.3-kwh.1'
        result = self.run_step('Stop openwebui and back up data')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_env_copy_path_survives_archive_failure(self):
        Path(self.env['ENV_FILE']).write_text('secret=fake\n')
        self.env['CURRENT_TAG'] = 'v0.11.3-kwh.1'
        self.mock('docker', 'echo "$*" >> "$MOCK_DOCKER_CALLS"\n')
        self.mock('tar', 'exit 2\n')
        result = self.run_step('Stop openwebui and back up data')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('stop openwebui', self.calls.read_text())
        self.assertIn('BACKUP_ENV_COPY_PATH=', self.env_file.read_text())
        self.assertNotIn('BACKUP_PATH=', self.env_file.read_text())

    def test_successful_backup_records_both_owner_only_files(self):
        Path(self.env['ENV_FILE']).write_text('secret=fake\n')
        self.env['CURRENT_TAG'] = 'v0.11.3-kwh.1'
        self.mock('docker', 'echo "$*" >> "$MOCK_DOCKER_CALLS"\n')
        self.mock(
            'tar',
            """
            if [[ "$1" == "-czf" ]]; then touch "$2"; fi
            """,
        )
        result = self.run_step('Stop openwebui and back up data')
        self.assertEqual(result.returncode, 0, result.stderr)
        values = dict(line.split('=', 1) for line in self.env_file.read_text().splitlines())
        self.assertEqual(Path(values['BACKUP_PATH']).stat().st_mode & 0o777, 0o600)
        self.assertEqual(Path(values['BACKUP_ENV_COPY_PATH']).stat().st_mode & 0o777, 0o600)

    def test_start_uses_prepulled_image_without_another_pull(self):
        self.mock(
            'docker',
            """
            echo "$*" >> "$MOCK_DOCKER_CALLS"
            if [[ "$*" == *"pull openwebui"* ]]; then exit 8; fi
            """,
        )
        result = self.run_step('Bring up new image')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('pull openwebui', self.calls.read_text())
        self.assertIn('up -d --no-deps --pull never openwebui', self.calls.read_text())

    def test_failure_comment_reports_previous_image_restart(self):
        self.env['CURRENT_TAG'] = 'v0.11.3-kwh.1'
        self.mock('docker', 'echo "$*" >> "$MOCK_DOCKER_CALLS"\n')
        self.mock('gh', 'printf "%s\\n" "$@" > "$MOCK_GH_ARGS"\n')
        restart = self.run_step('Restore previous service after pre-start failure')
        self.assertEqual(restart.returncode, 0, restart.stderr)
        self.assertIn('up -d --no-deps openwebui', self.calls.read_text())
        self.env['ROLLBACK_STATUS'] = dict(line.split('=', 1) for line in self.env_file.read_text().splitlines())[
            'ROLLBACK_STATUS'
        ]
        comment = self.run_step('Post failure comment')
        self.assertEqual(comment.returncode, 0, comment.stderr)
        self.assertIn(
            'previous image restarted (health unverified)',
            (self.root / 'gh-args').read_text(),
        )

    def test_log_collection_failure_fails_smoke(self):
        self.mock(
            'docker',
            """
            if [[ "$*" == *"ps openwebui --format"* ]]; then echo running; exit 0; fi
            if [[ "$*" == *"logs --tail 100 openwebui"* ]]; then exit 8; fi
            exit 9
            """,
        )
        result = self.run_step('Technical smoke — logs + container state')
        self.assertNotEqual(result.returncode, 0)

    def test_log_keyword_still_fails_smoke(self):
        self.mock(
            'docker',
            """
            if [[ "$*" == *"ps openwebui --format"* ]]; then echo running; exit 0; fi
            if [[ "$*" == *"logs --tail 100 openwebui"* ]]; then echo Traceback; exit 0; fi
            exit 9
            """,
        )
        result = self.run_step('Technical smoke — logs + container state')
        self.assertNotEqual(result.returncode, 0)

    def test_clean_logs_pass_smoke(self):
        self.mock(
            'docker',
            """
            if [[ "$*" == *"ps openwebui --format"* ]]; then echo running; exit 0; fi
            if [[ "$*" == *"logs --tail 100 openwebui"* ]]; then echo 'Application startup complete'; exit 0; fi
            exit 9
            """,
        )
        result = self.run_step('Technical smoke — logs + container state')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_success_and_failure_comments_include_env_copy(self):
        self.mock('gh', 'printf "%s\\n" "$@" > "$MOCK_GH_ARGS"\n')
        self.env.update(
            NEW_DIGEST='sha256:123',
            BACKUP_PATH='/tmp/archive.tar.gz',
            BACKUP_ENV_COPY_PATH='/tmp/oauth.env',
            PIPELINES_STATUS='SKIPPED',
            GUIDE_PATH='docs/manual/guide.md',
        )
        for name in ('Post success comment', 'Post failure comment'):
            with self.subTest(name=name):
                result = self.run_step(name)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('/tmp/oauth.env', (self.root / 'gh-args').read_text())

    def test_failure_comment_handles_backup_not_created(self):
        self.mock('gh', 'printf "%s\\n" "$@" > "$MOCK_GH_ARGS"\n')
        result = self.run_step('Post failure comment')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'gh-args').read_text().count('not-created'), 2)


if __name__ == '__main__':
    unittest.main()
