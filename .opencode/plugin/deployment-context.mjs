import { hasBoundEvidence, parseEvidenceObservation } from './deployment-context-evidence.mjs';
import { ContextPolicyError, classifyCommand } from './deployment-context-policy.mjs';

export { ContextPolicyError } from './deployment-context-policy.mjs';

export const CONTEXT_CLASSIFICATION = Object.freeze({
	AUTHORITY: '권위 증적',
	HISTORY: 'historical context',
	UNRESOLVED: 'unresolved'
});

const AUTHORITY_SOURCES = new Set(['github', 'origin-main', 'current-runtime']);
const HISTORY_SOURCES = new Set(['docs/jobs', 'openviking']);

export const classifyContextSource = (source) => {
	if (AUTHORITY_SOURCES.has(source)) {
		return CONTEXT_CLASSIFICATION.AUTHORITY;
	}
	if (HISTORY_SOURCES.has(source)) {
		return CONTEXT_CLASSIFICATION.HISTORY;
	}
	return CONTEXT_CLASSIFICATION.UNRESOLVED;
};

const commandFromArgs = (args) =>
	typeof args === 'object' && args !== null && 'command' in args && typeof args.command === 'string'
		? args.command
		: undefined;

const resolveAncestry = async (sessionID, resolveSession) => {
	const visited = new Set();
	let current = await resolveSession(sessionID);
	let depth = 0;
	while (current.parentID !== undefined) {
		if (visited.has(current.id) || depth >= 32) {
			throw new ContextPolicyError('세션 조상 관계를 안전하게 확인할 수 없습니다.');
		}
		visited.add(current.id);
		current = await resolveSession(current.parentID);
		depth += 1;
	}
	return { rootID: current.id, depth };
};

export const createDeploymentContextGuard = ({ now, resolveSession }) => {
	// 의도적으로 프로세스 메모리에만 둔다. OpenCode 재시작은 모든 권한 상태를 제거한다.
	const rootEvidence = new Map();

	return {
		before: async (input, output) => {
			if (input.tool !== 'bash') {
				return;
			}
			const command = commandFromArgs(output.args);
			if (command === undefined) {
				return;
			}
			const decision = classifyCommand(command);
			if (decision.kind === 'ordinary') {
				return;
			}
			if (decision.kind === 'deny') {
				throw new ContextPolicyError('허용 목록 밖의 민감 명령 또는 wrapper는 실행할 수 없습니다.');
			}
			const ancestry = await resolveAncestry(input.sessionID, resolveSession);
			if (decision.kind === 'read-only') {
				return;
			}
			if (ancestry.depth > 0) {
				throw new ContextPolicyError('자식 세션은 프로덕션 변경 권한을 상속할 수 없습니다.');
			}
			if (decision.kind === 'feature-push') {
				return;
			}
			const evidence = rootEvidence.get(ancestry.rootID);
			if (evidence === undefined || !hasBoundEvidence(evidence, now())) {
				throw new ContextPolicyError(
					'GitHub, origin/main 로컬·원격, 현재 런타임의 15분 이내 권위 증적이 모두 필요합니다.'
				);
			}
		},
		after: async (input, output) => {
			if (input.tool !== 'bash' || output.output.trim() === '') {
				return;
			}
			const command = commandFromArgs(input.args);
			if (command === undefined) {
				return;
			}
			const normalized = command
				.trim()
				.replace(/^GIT_MASTER=1 /, '')
				.replace(/\s+/g, ' ');
			const observation = parseEvidenceObservation(normalized, output.output, now());
			if (observation === undefined || observation.value === undefined) {
				return;
			}
			const ancestry = await resolveAncestry(input.sessionID, resolveSession);
			if (ancestry.depth > 0) {
				return;
			}
			const previous = rootEvidence.get(ancestry.rootID) ?? {};
			rootEvidence.set(ancestry.rootID, {
				...previous,
				[observation.kind]: observation
			});
		}
	};
};

const parseSession = (response, requestedID) => {
	const data =
		typeof response === 'object' && response !== null && 'data' in response
			? response.data
			: undefined;
	if (typeof data !== 'object' || data === null || !('id' in data) || typeof data.id !== 'string') {
		throw new ContextPolicyError(`세션 ${requestedID}의 루트 여부를 확인할 수 없습니다.`);
	}
	return {
		id: data.id,
		parentID: 'parentID' in data && typeof data.parentID === 'string' ? data.parentID : undefined
	};
};

export const DeploymentContextPlugin = async ({ client, directory }) => {
	const guard = createDeploymentContextGuard({
		now: Date.now,
		resolveSession: async (sessionID) =>
			parseSession(
				await client.session.get({
					path: { id: sessionID },
					query: { directory }
				}),
				sessionID
			)
	});

	return {
		'tool.execute.before': guard.before,
		'tool.execute.after': guard.after
	};
};
