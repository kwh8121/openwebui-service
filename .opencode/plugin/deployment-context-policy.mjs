const FINAL_TAG = 'v\\d+\\.\\d+\\.\\d+-kwh\\.\\d+';
const REPOSITORY = 'kwh8121/openwebui-service';
const SHELL_COMPOSITION = /[;&|`<>]|\$\(|[\n\r]/;
const SENSITIVE_TOKEN = /\b(?:git|gh|docker|docker-compose|sudo|tar)\b/;
const SHELL_INTERPRETER = /^(?:\/[^\s]+\/)?(?:bash|sh|zsh|dash|ksh|fish)\s+-(?:c|lc)\b/;
const EXECUTABLE_WRAPPER = /^(?:\/usr\/bin\/env|env|command|builtin|exec)\b/;
const ABSOLUTE_SENSITIVE_TOOL = /^\/[^\s]+\/(?:git|gh|docker|docker-compose|sudo|tar)\b/;
const TOKEN_ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=[^\s]+$/;
const TOKEN_WRAPPER = /^(?:\/[^\s]+\/)?(?:env|command|builtin|exec)$/;
const TOKEN_FRAGMENT = /['"\\$]/;

const hasFragmentedExecutable = (rawCommand) => {
	const tokens = rawCommand.trim().split(/\s+/);
	let index = 0;
	while (tokens[index] !== undefined && TOKEN_ASSIGNMENT.test(tokens[index])) {
		index += 1;
	}
	let executable = tokens[index];
	if (executable !== undefined && TOKEN_WRAPPER.test(executable)) {
		index += 1;
		while (
			tokens[index] !== undefined &&
			(tokens[index].startsWith('-') || TOKEN_ASSIGNMENT.test(tokens[index]))
		) {
			index += 1;
		}
		executable = tokens[index];
	}
	return executable !== undefined && TOKEN_FRAGMENT.test(executable);
};

const readOnlyGit = (command) =>
	/^git (?:status(?: --short)?|rev-parse --verify origin\/main|ls-remote --exit-code origin refs\/heads\/main|branch --show-current|diff (?:--check|--stat)|log --oneline -\d+|show --stat --oneline HEAD)$/.test(
		command
	);

const readOnlyGitHub = (command) =>
	new RegExp(`^gh issue view --repo ${REPOSITORY} \\d+ --json state,number,url,title,body$`).test(
		command
	) ||
	new RegExp(
		`^gh run view \\d+ --repo ${REPOSITORY} --json databaseId,status,conclusion,event,headBranch,headSha,url$`
	).test(command) ||
	new RegExp(`^gh api repos/${REPOSITORY}/commits/${FINAL_TAG}$`).test(command);

const readOnlyRuntime = (command) =>
	command === 'docker inspect openwebui --format={{json .}}' ||
	/^docker ps(?: --all)?$/.test(command) ||
	/^docker compose -f docker-compose\.deploy\.yaml (?:ps|config)$/.test(command) ||
	/^docker compose -f docker-compose\.deploy\.yaml logs(?: --no-color)?(?: --tail \d+)? openwebui$/.test(
		command
	);

const gatedMutation = (command) =>
	new RegExp(`^git tag -a ${FINAL_TAG} -m [A-Za-z0-9._-]+$`).test(command) ||
	command === 'git push origin main' ||
	new RegExp(`^git push origin refs/tags/${FINAL_TAG}$`).test(command) ||
	command === `gh workflow run deploy-approved-production-release.yaml --repo ${REPOSITORY}` ||
	/^docker compose -f docker-compose\.deploy\.yaml (?:stop openwebui|pull openwebui|up -d --no-deps openwebui)$/.test(
		command
	);

export class ContextPolicyError extends Error {
	constructor(message) {
		super(message);
		this.name = 'ContextPolicyError';
	}
}

export const classifyCommand = (rawCommand) => {
	if (hasFragmentedExecutable(rawCommand)) {
		return { kind: 'deny', reason: 'fragmented-executable' };
	}
	const compact = rawCommand.trim().replace(/\s+/g, ' ');
	const hasEnvironmentPrefix = /^[A-Za-z_][A-Za-z0-9_]*=[^\s]+\s+/.test(compact);
	const hasApprovedGitPrefix = /^GIT_MASTER=1 git\b/.test(compact);
	if (SHELL_INTERPRETER.test(compact)) {
		return { kind: 'deny', reason: 'shell-interpreter' };
	}
	if (
		SENSITIVE_TOKEN.test(compact) &&
		(SHELL_COMPOSITION.test(compact) ||
			EXECUTABLE_WRAPPER.test(compact) ||
			ABSOLUTE_SENSITIVE_TOOL.test(compact) ||
			(hasEnvironmentPrefix && !hasApprovedGitPrefix) ||
			/^GIT_MASTER=1\s+[A-Za-z_][A-Za-z0-9_]*=/.test(compact))
	) {
		return { kind: 'deny', reason: 'obscured-command' };
	}

	const command = compact.startsWith('GIT_MASTER=1 git ') ? compact.slice(13) : compact;
	if (
		SENSITIVE_TOKEN.test(command) &&
		!/^(?:git|gh|docker|docker-compose|sudo|tar)\b/.test(command)
	) {
		return { kind: 'deny', reason: 'indirect-sensitive-tool' };
	}
	if (/^git -c\b/.test(command)) {
		return { kind: 'deny', reason: 'git-config-wrapper' };
	}
	if (
		/^git push (?:-u |--set-upstream )?origin (?:refs\/heads\/)?feature\/[A-Za-z0-9._/-]+$/.test(
			command
		)
	) {
		return { kind: 'feature-push' };
	}
	if (readOnlyGit(command) || readOnlyGitHub(command) || readOnlyRuntime(command)) {
		return { kind: 'read-only' };
	}
	if (gatedMutation(command)) {
		return { kind: 'gated-mutation' };
	}
	if (/^(?:git|gh|docker|docker-compose|sudo|tar)\b/.test(command)) {
		return { kind: 'deny', reason: 'outside-allowlist' };
	}
	return { kind: 'ordinary' };
};
