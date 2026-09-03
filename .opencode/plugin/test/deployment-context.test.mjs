import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import {
	CONTEXT_CLASSIFICATION,
	ContextPolicyError,
	classifyContextSource,
	createDeploymentContextGuard
} from '../deployment-context.mjs';

const fixtureUrl = new URL('./fixtures/deployment-context-cases.json', import.meta.url);
const fixtures = JSON.parse(await readFile(fixtureUrl, 'utf8'));

const ROOT_SESSION = 'session-root';
const CHILD_SESSION = 'session-child';
const START_TIME = Date.parse('2026-09-02T12:00:00Z');

const createHarness = () => {
	let now = START_TIME;
	const guard = createDeploymentContextGuard({
		now: () => now,
		resolveSession: async (sessionID) => ({
			id: sessionID,
			parentID: sessionID === CHILD_SESSION ? ROOT_SESSION : undefined
		})
	});

	return {
		guard,
		advance: (milliseconds) => {
			now += milliseconds;
		}
	};
};

const runBefore = (guard, sessionID, command) =>
	guard.before({ tool: 'bash', sessionID, callID: 'call-before' }, { args: { command } });

const recordEvidence = async (guard, sessionID = ROOT_SESSION) => {
	for (const fixture of fixtures.evidenceCommands) {
		await guard.after(
			{
				tool: 'bash',
				sessionID,
				callID: 'call-after',
				args: { command: fixture.command }
			},
			{ output: fixture.output }
		);
	}
};

test('컨텍스트 출처를 권위 증적, 이력, 미해결로 분류한다', () => {
	// Given: fresh-session sources from each documented context lane.
	const sources = ['github', 'docs/jobs', 'linear'];

	// When: the sources are classified.
	const classifications = sources.map(classifyContextSource);

	// Then: each source lands in its machine-consumed classification.
	assert.deepEqual(classifications, [
		CONTEXT_CLASSIFICATION.AUTHORITY,
		CONTEXT_CLASSIFICATION.HISTORY,
		CONTEXT_CLASSIFICATION.UNRESOLVED
	]);
});

test('Mem0는 권위 증적으로 분류되지 않는다', () => {
	// Given: Mem0 is presented as a possible context source.
	const source = 'mem0';

	// When: the source is classified.
	const classification = classifyContextSource(source);

	// Then: it remains unresolved rather than authoritative.
	assert.equal(classification, CONTEXT_CLASSIFICATION.UNRESOLVED);
});

test('증적 없는 새 세션은 분류된 프로덕션 변경을 차단한다', async () => {
	// Given: a root session with no in-memory evidence.
	const { guard } = createHarness();

	for (const command of fixtures.blockedWithoutEvidence) {
		// When / Then: each classified sink is denied before execution.
		await assert.rejects(runBefore(guard, ROOT_SESSION, command), ContextPolicyError);
	}
});

test('읽기 전용 조회와 feature 브랜치 push는 증적 없이 허용한다', async () => {
	// Given: a root session with no in-memory evidence.
	const { guard } = createHarness();

	for (const command of fixtures.allowedWithoutEvidence) {
		// When / Then: non-production work passes the before hook.
		await assert.doesNotReject(runBefore(guard, ROOT_SESSION, command));
	}
});

test('최신 권위 증적을 모두 수집한 루트 세션만 분류된 변경을 통과한다', async () => {
	// Given: successful GitHub, origin/main, and runtime inspections.
	const { guard } = createHarness();
	await recordEvidence(guard);

	// When / Then: a classified sink passes only in that root session.
	await assert.doesNotReject(runBefore(guard, ROOT_SESSION, fixtures.blockedWithoutEvidence[0]));
});

test('로컬 origin/main과 원격 main SHA가 다르면 변경을 차단한다', async () => {
	// Given: all evidence commands ran, but the remote main SHA differs.
	const { guard } = createHarness();
	for (const fixture of fixtures.evidenceCommands) {
		const output = fixture.command.includes('ls-remote')
			? '2222222222222222222222222222222222222222 refs/heads/main'
			: fixture.output;
		await guard.after(
			{
				tool: 'bash',
				sessionID: ROOT_SESSION,
				callID: 'call-after',
				args: { command: fixture.command }
			},
			{ output }
		);
	}

	// When / Then: drift keeps the production mutation gate closed.
	await assert.rejects(
		runBefore(guard, ROOT_SESSION, fixtures.blockedWithoutEvidence[0]),
		ContextPolicyError
	);
});

test('루트 증적을 수집해도 자식 세션의 분류된 변경은 차단한다', async () => {
	// Given: fresh evidence belongs to the root session.
	const { guard } = createHarness();
	await recordEvidence(guard);

	// When / Then: the child cannot inherit mutation authority.
	await assert.rejects(
		runBefore(guard, CHILD_SESSION, fixtures.blockedWithoutEvidence[0]),
		ContextPolicyError
	);
});

test('자식 세션은 feature 브랜치 push도 실행할 수 없다', async () => {
	// Given: feature push is otherwise allowed for a root session.
	const { guard } = createHarness();
	const featurePush = fixtures.allowedWithoutEvidence.at(-1);

	// When / Then: ancestry is resolved before the feature exemption.
	await assert.rejects(runBefore(guard, CHILD_SESSION, featurePush), ContextPolicyError);
});

test('증적 유효 시간이 지나면 분류된 변경을 다시 차단한다', async () => {
	// Given: formerly complete evidence is older than the policy window.
	const { guard, advance } = createHarness();
	await recordEvidence(guard);
	advance(15 * 60 * 1000 + 1);

	// When / Then: stale authority is denied.
	await assert.rejects(
		runBefore(guard, ROOT_SESSION, fixtures.blockedWithoutEvidence[0]),
		ContextPolicyError
	);
});

test('분류된 sink의 메타문자와 중첩 shell은 기본 거부한다', async () => {
	// Given: commands that obscure classified sinks through shell composition.
	const { guard } = createHarness();
	await recordEvidence(guard);

	for (const command of fixtures.composedSinkCommands) {
		// When / Then: composition is denied even with fresh evidence.
		await assert.rejects(runBefore(guard, ROOT_SESSION, command), ContextPolicyError);
	}
});
