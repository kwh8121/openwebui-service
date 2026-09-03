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

const recordCorruptedEvidence = async (guard, expected, replacement) => {
	for (const fixture of fixtures.evidenceCommands) {
		await guard.after(
			{
				tool: 'bash',
				sessionID: ROOT_SESSION,
				callID: 'call-after',
				args: { command: fixture.command }
			},
			{ output: fixture.output.replace(expected, replacement) }
		);
	}
};

const expectGateClosed = (guard) =>
	assert.rejects(
		guard.before(
			{ tool: 'bash', sessionID: ROOT_SESSION, callID: 'call-before' },
			{ args: { command: fixtures.blockedWithoutEvidence[0] } }
		),
		ContextPolicyError
	);

test('Issue와 run, tag, SHA가 서로 묶이지 않으면 변경을 차단한다', async () => {
	// Given: each case corrupts one structured authority relationship.
	const corruptions = [
		['"state":"CLOSED"', '"state":"OPEN"'],
		['"conclusion":"success"', '"conclusion":"failure"'],
		['"headBranch":"v0.11.4-kwh.1"', '"headBranch":"v0.11.4-kwh.2"'],
		[
			'"headSha":"1111111111111111111111111111111111111111"',
			'"headSha":"2222222222222222222222222222222222222222"'
		],
		[
			'Main SHA: 1111111111111111111111111111111111111111',
			'Main SHA: 2222222222222222222222222222222222222222'
		],
		[
			'Run: https://github.com/kwh8121/openwebui-service/actions/runs/123456789',
			'Run: https://github.com/kwh8121/openwebui-service/actions/runs/987654321'
		],
		[
			'{"sha":"1111111111111111111111111111111111111111"}',
			'{"sha":"2222222222222222222222222222222222222222"}'
		]
	];

	for (const [expected, replacement] of corruptions) {
		const guard = createGuard();
		await recordCorruptedEvidence(guard, expected, replacement);

		// When / Then: incomplete or contradictory GitHub evidence cannot open the gate.
		await expectGateClosed(guard);
	}
});

test('런타임이 unhealthy이거나 컨테이너·digest가 다르면 변경을 차단한다', async () => {
	// Given: each runtime response violates one bound production invariant.
	const corruptions = [
		['"healthy"', '"unhealthy"'],
		['"/openwebui"', '"/other"'],
		['@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', ':latest'],
		[
			'@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
			'@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
		]
	];

	for (const [expected, replacement] of corruptions) {
		const guard = createGuard();
		await recordCorruptedEvidence(guard, expected, replacement);

		// When / Then: runtime drift cannot authorize a production mutation.
		await expectGateClosed(guard);
	}
});

test('비정형 JSON은 권위 증적으로 기록하지 않는다', async () => {
	// Given: an exact read-only command returns malformed JSON.
	const guard = createGuard();
	const issueFixture = fixtures.evidenceCommands[0];
	await guard.after(
		{
			tool: 'bash',
			sessionID: ROOT_SESSION,
			callID: 'call-after',
			args: { command: issueFixture.command }
		},
		{ output: '{not-json' }
	);

	// When / Then: malformed injected evidence leaves the gate closed.
	await expectGateClosed(guard);
});
