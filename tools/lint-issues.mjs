// lint-issues.mjs - sincroniza lint/findings.json (lo publica el plugin v3.0.0
// desde Studio) con los issues del repo. Sin dependencias: Node 20 + fetch.
//
// Clave de dedup: `path::code` embebida en el cuerpo como <!-- lint-key: ... -->.
// La linea no forma parte de la clave (cambia al editar el script).

import { readFile } from "node:fs/promises";

const token = process.env.GITHUB_TOKEN;
const repo = process.env.GITHUB_REPOSITORY; // "owner/repo"
if (!token || !repo) {
	console.error("Faltan GITHUB_TOKEN o GITHUB_REPOSITORY");
	process.exit(1);
}

const API = "https://api.github.com";
const HEADERS = {
	Authorization: `Bearer ${token}`,
	Accept: "application/vnd.github+json",
	"X-GitHub-Api-Version": "2022-11-28",
	"Content-Type": "application/json",
};
const MAX_CREACIONES = 50;

async function api(pathname, options = {}) {
	const res = await fetch(`${API}${pathname}`, { headers: HEADERS, ...options });
	if (!res.ok) {
		throw new Error(`${options.method || "GET"} ${pathname} -> ${res.status}: ${await res.text()}`);
	}
	return res.status === 204 ? null : res.json();
}

async function listarIssuesLint() {
	const issues = [];
	for (let page = 1; page <= 5; page++) {
		const lote = await api(
			`/repos/${repo}/issues?labels=lint&state=all&per_page=100&page=${page}`
		);
		// la API de issues incluye PRs; los filtramos
		for (const issue of lote) {
			if (!issue.pull_request) issues.push(issue);
		}
		if (lote.length < 100) break;
	}
	return issues;
}

const SEV_LABEL = { error: "lint:error", warn: "lint:warn", info: "lint:info" };
const SEV_EMOJI = { error: "🔴", warn: "🟡", info: "🔵" };

function cuerpoDe(f) {
	const emoji = SEV_EMOJI[f.severity] || "⚪";
	return [
		`<!-- lint-key: ${f.path}::${f.code} -->`,
		``, 
		`${emoji} **${f.code}** en \`${f.path}\`, línea ${f.line}`,
		``, 
		`**Problema:** ${f.message}`,
		``, 
		`**Cómo arreglarlo:** ${f.fix}`,
		``, 
		`---`,
		`_Detectado por el auto-lint del plugin (lint/findings.json). Este issue se cierra solo cuando el hallazgo desaparece del análisis._`,
	].join("\n");
}

function tituloDe(f) {
	const corta = f.path.length > 60 ? "…" + f.path.slice(-59) : f.path;
	return `[lint] ${f.code} · ${corta}`;
}

async function main() {
	let findings;
	try {
		const payload = JSON.parse(await readFile("lint/findings.json", "utf8"));
		findings = payload.findings || [];
		console.log(`lint/findings.json: ${payload.total ?? findings.length} hallazgo(s), capturado ${payload.capturado_at}`);
	} catch (err) {
		console.log("No hay lint/findings.json legible; nada que hacer.", err.message);
		return;
	}

	const issues = await listarIssuesLint();
	const porClave = new Map();
	for (const issue of issues) {
		const m = /<!-- lint-key: (.+?) -->/.exec(issue.body || "");
		if (m) porClave.set(m[1], issue);
	}

	const clavesVivas = new Set();
	let creados = 0, reabiertos = 0;
	for (const f of findings) {
		const clave = `${f.path}::${f.code}`;
		clavesVivas.add(clave);
		const issue = porClave.get(clave);
		if (!issue) {
			if (creados >= MAX_CREACIONES) continue;
			await api(`/repos/${repo}/issues`, {
				method: "POST",
				body: JSON.stringify({
					title: tituloDe(f),
					body: cuerpoDe(f),
					labels: ["lint", SEV_LABEL[f.severity] || "lint"],
				}),
			});
			creados++;
		} else if (issue.state === "closed") {
			await api(`/repos/${repo}/issues/${issue.number}`, {
				method: "PATCH",
				body: JSON.stringify({ state: "open" }),
			});
			await api(`/repos/${repo}/issues/${issue.number}/comments`, {
				method: "POST",
				body: JSON.stringify({
					body: `Reapareció en el último análisis (línea ${f.line}). Reabro.`,
				}),
			});
			reabiertos++;
		}
	}

	let cerrados = 0;
	for (const [clave, issue] of porClave) {
		if (issue.state === "open" && !clavesVivas.has(clave)) {
			await api(`/repos/${repo}/issues/${issue.number}/comments`, {
				method: "POST",
				body: JSON.stringify({
					body: "Ya no aparece en el último análisis del plugin. Lo cierro como resuelto — si reaparece, se reabre solo.",
				}),
			});
			await api(`/repos/${repo}/issues/${issue.number}`, {
				method: "PATCH",
				body: JSON.stringify({ state: "closed", state_reason: "completed" }),
			});
			cerrados++;
		}
	}

	console.log(`Sincronizado: ${creados} creados, ${reabiertos} reabiertos, ${cerrados} cerrados.`);
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
