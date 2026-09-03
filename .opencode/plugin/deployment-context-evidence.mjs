const REPOSITORY = 'kwh8121/openwebui-service';
const IMAGE_REPOSITORY = `ghcr.io/${REPOSITORY}`;
const FINAL_TAG = /^v\d+\.\d+\.\d+-kwh\.\d+$/;
const SHA = /^[0-9a-f]{40}$/;
const DIGEST = /^sha256:[0-9a-f]{64}$/;
const EVIDENCE_WINDOW_MS = 15 * 60 * 1000;

const parseJsonObject = (output) => {
	try {
		const value = JSON.parse(output);
		return typeof value === 'object' && value !== null && !Array.isArray(value) ? value : undefined;
	} catch (error) {
		if (error instanceof SyntaxError) {
			return undefined;
		}
		throw error;
	}
};

const stringField = (object, key) =>
	key in object && typeof object[key] === 'string' ? object[key] : undefined;

const numberField = (object, key) =>
	key in object && typeof object[key] === 'number' ? object[key] : undefined;

const parseIssue = (output, issueNumber) => {
	const value = parseJsonObject(output);
	if (
		value === undefined ||
		stringField(value, 'state') !== 'CLOSED' ||
		numberField(value, 'number') !== issueNumber
	) {
		return undefined;
	}
	const title = stringField(value, 'title');
	const body = stringField(value, 'body');
	const url = stringField(value, 'url');
	if (
		title === undefined ||
		body === undefined ||
		url !== `https://github.com/${REPOSITORY}/issues/${issueNumber}`
	) {
		return undefined;
	}
	const tag = title.match(/^Production deployment request: (v\d+\.\d+\.\d+-kwh\.\d+)$/)?.[1];
	const sha = body.match(/^Main SHA: ([0-9a-f]{40})$/m)?.[1];
	const runID = body.match(
		new RegExp(`^Run: https://github\\.com/${REPOSITORY}/actions/runs/(\\d+)$`, 'm')
	)?.[1];
	const digest = body.match(/^Image digest: (sha256:[0-9a-f]{64})$/m)?.[1];
	if (
		tag === undefined ||
		sha === undefined ||
		runID === undefined ||
		digest === undefined ||
		!body.includes(`Tag: ${tag}`)
	) {
		return undefined;
	}
	return { issueNumber, tag, sha, runID: Number(runID), digest };
};

const parseRun = (output, requestedRunID) => {
	const value = parseJsonObject(output);
	const runID = value === undefined ? undefined : numberField(value, 'databaseId');
	const tag = value === undefined ? undefined : stringField(value, 'headBranch');
	const sha = value === undefined ? undefined : stringField(value, 'headSha');
	const url = value === undefined ? undefined : stringField(value, 'url');
	if (
		value === undefined ||
		runID !== requestedRunID ||
		stringField(value, 'status') !== 'completed' ||
		stringField(value, 'conclusion') !== 'success' ||
		stringField(value, 'event') !== 'workflow_dispatch' ||
		tag === undefined ||
		!FINAL_TAG.test(tag) ||
		sha === undefined ||
		!SHA.test(sha) ||
		url !== `https://github.com/${REPOSITORY}/actions/runs/${requestedRunID}`
	) {
		return undefined;
	}
	return { runID, tag, sha };
};

const parseTag = (output, tag) => {
	const value = parseJsonObject(output);
	const sha = value === undefined ? undefined : stringField(value, 'sha');
	return sha !== undefined && SHA.test(sha) ? { tag, sha } : undefined;
};

const parseRuntime = (output) => {
	const value = parseJsonObject(output);
	const config = value !== undefined && 'Config' in value ? value.Config : undefined;
	const state = value !== undefined && 'State' in value ? value.State : undefined;
	const health =
		typeof state === 'object' && state !== null && 'Health' in state ? state.Health : undefined;
	const image =
		typeof config === 'object' && config !== null ? stringField(config, 'Image') : undefined;
	const digest = image?.match(
		new RegExp(`^${IMAGE_REPOSITORY.replaceAll('.', '\\.')}@(sha256:[0-9a-f]{64})$`)
	)?.[1];
	if (
		stringField(value ?? {}, 'Name') !== '/openwebui' ||
		typeof state !== 'object' ||
		state === null ||
		stringField(state, 'Status') !== 'running' ||
		typeof health !== 'object' ||
		health === null ||
		stringField(health, 'Status') !== 'healthy' ||
		digest === undefined ||
		!DIGEST.test(digest)
	) {
		return undefined;
	}
	return { container: 'openwebui', digest };
};

export const parseEvidenceObservation = (command, output, observedAt) => {
	let match = command.match(
		new RegExp(`^gh issue view --repo ${REPOSITORY} (\\d+) --json state,number,url,title,body$`)
	);
	if (match?.[1] !== undefined)
		return { kind: 'issue', observedAt, value: parseIssue(output, Number(match[1])) };
	match = command.match(
		new RegExp(
			`^gh run view (\\d+) --repo ${REPOSITORY} --json databaseId,status,conclusion,event,headBranch,headSha,url$`
		)
	);
	if (match?.[1] !== undefined)
		return { kind: 'run', observedAt, value: parseRun(output, Number(match[1])) };
	match = command.match(
		new RegExp(`^gh api repos/${REPOSITORY}/commits/(v\\d+\\.\\d+\\.\\d+-kwh\\.\\d+)$`)
	);
	if (match?.[1] !== undefined)
		return { kind: 'tag', observedAt, value: parseTag(output, match[1]) };
	if (command === 'git rev-parse --verify origin/main')
		return {
			kind: 'originLocal',
			observedAt,
			value: SHA.test(output.trim()) ? output.trim() : undefined
		};
	if (command === 'git ls-remote --exit-code origin refs/heads/main')
		return {
			kind: 'originRemote',
			observedAt,
			value: output.match(/^([0-9a-f]{40})\s+refs\/heads\/main\s*$/)?.[1]
		};
	if (command === 'docker inspect openwebui --format={{json .}}')
		return { kind: 'runtime', observedAt, value: parseRuntime(output) };
	return undefined;
};

export const hasBoundEvidence = (state, now) => {
	const entries = [
		state.issue,
		state.run,
		state.tag,
		state.originLocal,
		state.originRemote,
		state.runtime
	];
	if (
		entries.some(
			(entry) =>
				entry === undefined ||
				entry.value === undefined ||
				now - entry.observedAt > EVIDENCE_WINDOW_MS
		)
	)
		return false;
	const issue = state.issue.value;
	const run = state.run.value;
	const tag = state.tag.value;
	const runtime = state.runtime.value;
	return (
		issue.sha === run.sha &&
		issue.sha === tag.sha &&
		issue.sha === state.originLocal.value &&
		issue.sha === state.originRemote.value &&
		issue.tag === run.tag &&
		issue.tag === tag.tag &&
		issue.runID === run.runID &&
		issue.digest === runtime.digest
	);
};
