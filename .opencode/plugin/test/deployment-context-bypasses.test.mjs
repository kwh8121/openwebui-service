import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import { ContextPolicyError, createDeploymentContextGuard } from '../deployment-context.mjs';

const fixtureUrl = new URL('./fixtures/deployment-context-cases.json', import.meta.url);
const fixtures = JSON.parse(await readFile(fixtureUrl, 'utf8'));
const ROOT_SESSION = 'session-root';

const createGuard = () =>
	createDeploymentContextGuard({
		now: () => Date.parse('2026-09-02T12:00:00Z'),
		resolveSession: async (sessionID) => ({ id: sessionID, parentID: undefined })
	});

const recordEvidence = async (guard) => {
	for (const fixture of fixtures.evidenceCommands) {
		await guard.after(
			{
				tool: 'bash',
				sessionID: ROOT_SESSION,
				callID: 'call-after',
				args: { command: fixture.command }
			},
			{ output: fixture.output }
		);
	}
};

test('절대 경로, wrapper, git -c, 중첩 shell 우회를 항상 차단한다', async () => {
	// Given: complete evidence cannot legitimize an obscured executable.
	const guard = createGuard();
	await recordEvidence(guard);
	const wrapperBypasses = [
		...fixtures.alwaysDeniedBypasses.slice(0, 6),
		'FOO=bar git push origin main',
		'xargs git push origin main'
	];

	for (const command of wrapperBypasses) {
		// When / Then: each wrapper is rejected before execution.
		await assert.rejects(
			guard.before(
				{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
				{ args: { command } }
			),
			ContextPolicyError
		);
	}
});

test('정확한 읽기 전용 allowlist의 변형은 실행하지 않는다', async () => {
	// Given: commands resemble inspection but are not exact approved forms.
	const guard = createGuard();
	const nearMisses = [
		'gh issue list --repo kwh8121/openwebui-service',
		'docker inspect other --format={{json .}}',
		'git diff --output=/tmp/diff.txt'
	];

	for (const command of nearMisses) {
		// When / Then: no approximate read-only classification is accepted.
		await assert.rejects(
			guard.before(
				{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
				{ args: { command } }
			),
			ContextPolicyError
		);
	}
});

test('비허용 gh mutation 우회를 항상 차단한다', async () => {
	// Given: complete evidence exists but only the deployment workflow is eligible for gating.
	const guard = createGuard();
	await recordEvidence(guard);
	const githubBypasses = fixtures.alwaysDeniedBypasses.slice(6, 10);

	for (const command of githubBypasses) {
		// When / Then: merge, release, delete, and API writes are denied.
		await assert.rejects(
			guard.before(
				{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
				{ args: { command } }
			),
			ContextPolicyError
		);
	}
});

test('비허용 Docker와 Compose mutation 우회를 항상 차단한다', async () => {
	// Given: complete evidence exists but the commands are outside the mutation allowlist.
	const guard = createGuard();
	await recordEvidence(guard);
	const runtimeBypasses = fixtures.alwaysDeniedBypasses.slice(10);

	for (const command of runtimeBypasses) {
		// When / Then: run, exec, cp, commit, and image prune are denied.
		await assert.rejects(
			guard.before(
				{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
				{ args: { command } }
			),
			ContextPolicyError
		);
	}
});

test('실행 파일 토큰의 quote, backslash, expansion, concatenation을 차단한다', async () => {
	// Given: shell syntax would reconstruct a sensitive executable name.
	const guard = createGuard();
	await recordEvidence(guard);

	for (const command of fixtures.fragmentedExecutableBypasses) {
		// When / Then: raw lexical fragmentation is rejected without shell interpretation.
		await assert.rejects(
			guard.before(
				{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
				{ args: { command } }
			),
			ContextPolicyError
		);
	}
});
