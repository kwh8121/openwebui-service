// Fork guard tests for KOR-71 (GitHub #81). Run in CI by
// .github/workflows/kwh-fork-guards.yaml (job kwh-guard-frontend).
//
// The wiring tests fail when an upstream merge drops the fork branches from
// MarkdownInlineTokens.svelte even though the merge itself had no conflict.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

import { isBrowserSandboxRef } from './browserSandboxRef';
import cases from './browserSandboxRefCases.json';

const RENDERER = resolve(
	process.cwd(),
	'src/lib/components/chat/Messages/Markdown/MarkdownInlineTokens.svelte'
);

describe('isBrowserSandboxRef', () => {
	it.each(cases.sandbox)('treats %j as a browser sandbox ref', (ref) => {
		expect(isBrowserSandboxRef(ref)).toBe(true);
	});

	it.each(cases.not_sandbox)('leaves %j alone', (ref) => {
		expect(isBrowserSandboxRef(ref)).toBe(false);
	});

	it('rejects non-string input', () => {
		expect(isBrowserSandboxRef(undefined)).toBe(false);
		expect(isBrowserSandboxRef(null)).toBe(false);
	});
});

describe('MarkdownInlineTokens wiring', () => {
	const source = readFileSync(RENDERER, 'utf-8');

	it('imports the fork helper', () => {
		expect(source).toMatch(
			/import\s*\{\s*isBrowserSandboxRef\s*\}\s*from\s*'\$lib\/utils\/kwh\/browserSandboxRef'/
		);
	});

	// Upstream renamed terminalDocument to machineDocument in v0.13.5; accept both.
	it('guards image tokens after the machine document branch', () => {
		const terminal = source.search(
			/(?:terminal|machine)Document\?\.localPath\(\s*token\.href\s*\)/
		);
		const guard = source.search(/\{:else if isBrowserSandboxRef\(\s*token\.href\s*\)\s*\}/);
		const fallback = source.search(/<Image\s+src=\{token\.href\}/);
		expect(terminal).toBeGreaterThan(-1);
		expect(guard).toBeGreaterThan(terminal);
		expect(fallback).toBeGreaterThan(guard);
	});

	it('guards link tokens before the generic link branches', () => {
		const guard = source.search(/\{:else if isBrowserSandboxRef\(\s*linkToken\.href\s*\)\s*\}/);
		const link = source.search(/\{:else if token\.tokens && !linkToken\.isAutolink\}/);
		expect(guard).toBeGreaterThan(-1);
		expect(link).toBeGreaterThan(guard);
	});
});
