#!/usr/bin/env node
// Publish the packages produced by scripts/npm/build.mjs.
//
// Chunks are published first, then the platform package, then the meta
// package. A failed publish stops the run so the registry never exposes a
// meta package whose chunks are missing.
//
// Usage:
//   node scripts/npm/publish.mjs
//   node scripts/npm/publish.mjs --dry-run
//   NPM_PROVENANCE=1 node scripts/npm/publish.mjs   # optional; CI with id-token only

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const dryRun = process.argv.includes('--dry-run');
const root = path.join(REPO, 'build', 'npm');

if (!fs.existsSync(root)) {
  console.error('[publish-npm] build/npm does not exist. Run scripts/npm/build.mjs first.');
  process.exit(1);
}

// Node 20+ refuses to spawn .cmd files without a shell on Windows. Calling
// npm's JavaScript entry point directly avoids shell quoting problems with
// repository paths that contain spaces.
function npmInvocation() {
  if (process.platform !== 'win32') {
    return { file: 'npm', prefix: [] };
  }
  const candidates = [
    process.env.npm_execpath,
    path.join(path.dirname(process.execPath), 'node_modules', 'npm', 'bin', 'npm-cli.js')
  ].filter(Boolean);
  for (const candidate of candidates) {
    if (candidate.endsWith('.js') && fs.existsSync(candidate)) {
      return { file: process.execPath, prefix: [candidate] };
    }
  }
  return { file: 'npm.cmd', prefix: [] };
}

const npm = npmInvocation();

function run(args) {
  console.log(`\n> npm ${args.join(' ')}`);
  const result = spawnSync(npm.file, [...npm.prefix, ...args], { stdio: 'inherit' });
  if (result.error) {
    console.error(result.error);
    process.exit(1);
  }
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function whoami() {
  const result = spawnSync(npm.file, [...npm.prefix, 'whoami'], { encoding: 'utf8' });
  return result.status === 0 ? result.stdout.trim() : '';
}

function isPublished(name, version) {
  const result = spawnSync(
    npm.file,
    [...npm.prefix, 'view', `${name}@${version}`, 'version', '--json'],
    { encoding: 'utf8' }
  );
  return result.status === 0;
}

const user = whoami();
if (!user && !dryRun) {
  console.error('[publish-npm] Not logged in to npm. Run `npm login` or set NODE_AUTH_TOKEN.');
  process.exit(1);
}
if (user) {
  console.log(`[publish-npm] Publishing as ${user}`);
}

const chunkDirs = fs.readdirSync(root)
  .filter((name) => /^chunk-[0-9]+$/.test(name))
  .sort()
  .map((name) => path.join(root, name));

if (chunkDirs.length === 0) {
  console.error('[publish-npm] No chunk packages found in build/npm.');
  process.exit(1);
}

const ordered = [
  ...chunkDirs,
  path.join(root, 'platform'),
  path.join(root, 'meta')
];

for (const directory of ordered) {
  const manifest = path.join(directory, 'package.json');
  if (!fs.existsSync(manifest)) {
    console.error(`[publish-npm] Missing ${manifest}`);
    process.exit(1);
  }
  const { name, version } = JSON.parse(fs.readFileSync(manifest, 'utf8'));
  console.log(`\n[publish-npm] ${name}@${version}`);

  if (!dryRun && isPublished(name, version)) {
    console.log('[publish-npm] Already published, skipping.');
    continue;
  }

  const args = [
    'publish',
    directory,
    '--access', 'public',
    '--tag', 'latest',
    '--fetch-timeout=1800000',
    '--fetch-retries=2'
  ];
  if (process.env.NPM_PROVENANCE === '1') {
    args.push('--provenance');
  }
  if (dryRun) {
    args.push('--dry-run');
  }
  run(args);
}

console.log(`\n[publish-npm] ${dryRun ? 'Dry run complete' : 'All packages published'}.`);
