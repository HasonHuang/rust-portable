#!/usr/bin/env node
// Prepare npm packages for a file or folder.
//
// The script does not publish. It builds package directories, writes a
// publish.sh, prints the npm publish commands, and leaves the publish step to
// the user.
//
// Usage:
//   node docs/npm/prepare-publish.mjs <file-or-folder> [options]
//   node docs/npm/prepare-publish.mjs a.zip --scope @your-scope --name a
//
// Output: build/npm-publish/ by default.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { parseArgs } from 'node:util';

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    scope: { type: 'string' },
    name: { type: 'string' },
    version: { type: 'string', default: '1.0.0' },
    platform: { type: 'string', default: 'win32-x64' },
    'chunk-size': { type: 'string', default: '100' },
    threshold: { type: 'string', default: '50' },
    out: { type: 'string', default: 'build/npm-publish' },
    'strip-components': { type: 'string' },
    force: { type: 'boolean', default: false },
    help: { type: 'boolean', short: 'h' }
  }
});

function fail(message) {
  console.error(`[prepare-publish] ${message}`);
  process.exit(1);
}

function help() {
  console.log(`Usage:
  node docs/npm/prepare-publish.mjs <file-or-folder> [options]

Options:
  --scope <scope>          npm scope, default NPM_SCOPE or your-scope
  --name <name>            package base name, default input basename
  --version <version>      package version, default 1.0.0
  --platform <os-cpu>      default win32-x64; use any for no os/cpu
  --chunk-size <MiB>       chunk size, default 100
  --threshold <MiB>        use chunks above this size, default 50
  --out <dir>              output directory, default build/npm-publish
  --strip-components <n>   default 1 for folders, 0 for files
  --force                  replace the output directory
  --help                   show this help

The script does not publish. It prints the npm publish commands.
`);
}

if (values.help) {
  help();
  process.exit(0);
}
if (positionals.length !== 1) {
  help();
  fail('Provide exactly one input file or folder.');
}

const input = path.resolve(positionals[0]);
if (!fs.existsSync(input)) fail(`Input does not exist: ${input}`);

const inputStat = fs.statSync(input);
const isDirectory = inputStat.isDirectory();
const defaultName = isDirectory
  ? path.basename(input)
  : path.basename(input, path.extname(input));
const rawName = values.name || defaultName;
const name = rawName
  .trim()
  .toLowerCase()
  .replace(/[^a-z0-9._~-]+/g, '-')
  .replace(/^[._-]+/, '')
  .replace(/[._-]+$/, '');
if (!name || !/^[a-z0-9][a-z0-9._~-]*$/.test(name)) {
  fail(`Invalid package name: ${rawName}`);
}

const scope = (values.scope || process.env.NPM_SCOPE || 'your-scope')
  .trim()
  .toLowerCase()
  .replace(/^@/, '')
  .replace(/\/$/, '');
if (!/^[a-z0-9][a-z0-9._~-]*$/.test(scope)) {
  fail(`Invalid scope: ${values.scope || process.env.NPM_SCOPE}`);
}
if (!values.scope && !process.env.NPM_SCOPE) {
  console.warn('[prepare-publish] Using placeholder scope: your-scope');
  console.warn('[prepare-publish] Set --scope or NPM_SCOPE before publishing.');
}

const version = (values.version || '').trim();
if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
  fail(`Invalid version: ${version}`);
}

const platform = (values.platform || 'any').trim();
if (platform !== 'any') {
  const dash = platform.indexOf('-');
  if (dash < 1 || dash === platform.length - 1) {
    fail(`Invalid platform '${platform}'. Use os-cpu, for example win32-x64.`);
  }
}
const platformFields = platform === 'any'
  ? {}
  : { os: [platform.slice(0, platform.indexOf('-'))], cpu: [platform.slice(platform.indexOf('-') + 1)] };

const chunkMiB = Number(values['chunk-size']);
if (!Number.isInteger(chunkMiB) || chunkMiB < 1 || chunkMiB > 200) {
  fail('--chunk-size must be an integer from 1 to 200.');
}
const chunkBytes = chunkMiB * 1024 * 1024;

const thresholdMiB = Number(values.threshold);
if (!Number.isInteger(thresholdMiB) || thresholdMiB < 0) {
  fail('--threshold must be an integer of 0 or more.');
}

const stripComponents = values['strip-components'] === undefined
  ? (isDirectory ? 1 : 0)
  : Number(values['strip-components']);
if (!Number.isInteger(stripComponents) || stripComponents < 0) {
  fail('--strip-components must be an integer of 0 or more.');
}

const out = path.resolve(values.out);
if (out === path.parse(out).root || out === path.resolve('.')) {
  fail('--out must be a dedicated directory, not the current directory or a drive root.');
}
const contains = (parent, child) => {
  const left = process.platform === 'win32' ? parent.toLowerCase() : parent;
  const right = process.platform === 'win32' ? child.toLowerCase() : child;
  return right === left || right.startsWith(left.endsWith(path.sep) ? left : left + path.sep);
};
if (contains(out, input) || contains(input, out)) {
  fail('--out must not overlap the input path.');
}
if (fs.existsSync(out)) {
  const entries = fs.readdirSync(out);
  if (entries.length > 0 && !values.force) {
    fail(`Output directory is not empty: ${out}\nRemove it, or use --force.`);
  }
  if (values.force) fs.rmSync(out, { recursive: true, force: true });
}
fs.mkdirSync(out, { recursive: true });

function pad(number) {
  return String(number).padStart(2, '0');
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit' });
  if (result.error) fail(`${command} failed: ${result.error.message}`);
  if (result.status !== 0) fail(`${command} failed with exit code ${result.status}`);
}

function zipDirectory(directory, zipPath) {
  const parent = path.dirname(directory);
  const base = path.basename(directory);

  if (process.platform === 'win32') {
    const tar = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe');
    if (!fs.existsSync(tar)) fail(`tar.exe was not found at ${tar}.`);
    run(tar, ['-a', '-c', '-f', zipPath, '-C', parent, base]);
    return;
  }

  const result = spawnSync('zip', ['-q', '-r', zipPath, base], { cwd: parent, stdio: 'inherit' });
  if (result.error && result.error.code === 'ENOENT') {
    fail('zip was not found. Install zip, or pass a ZIP file instead of a folder.');
  }
  if (result.status !== 0) fail('zip failed.');
}

function sha256File(file) {
  const hash = crypto.createHash('sha256');
  const fd = fs.openSync(file, 'r');
  const buffer = Buffer.alloc(1024 * 1024);
  try {
    while (true) {
      const read = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (read === 0) break;
      hash.update(buffer.subarray(0, read));
    }
  } finally {
    fs.closeSync(fd);
  }
  return hash.digest('hex');
}

function shellQuote(value) {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

function posixPath(value) {
  return value.split(path.sep).join('/');
}

function printCommands(directories) {
  const commands = [
    'npm login',
    'npm whoami',
    ...directories.map((directory) => `npm publish ${shellQuote(posixPath(directory))} --access public --tag latest`)
  ];

  console.log('');
  console.log('Publish commands:');
  for (const command of commands) console.log(`  ${command}`);
  console.log('');
  console.log('Add --dry-run to an npm publish command to preview it.');

  const script = path.join(out, 'publish.sh');
  fs.writeFileSync(script, `#!/usr/bin/env bash\nset -euo pipefail\n${commands.join('\n')}\n`);
  console.log(`Publish script: ${script}`);
}

let payloadPath;
if (isDirectory) {
  payloadPath = path.join(out, `${name}.zip`);
  console.log(`[prepare-publish] Packing folder: ${input}`);
  zipDirectory(input, payloadPath);
} else {
  payloadPath = input;
}

const payloadName = path.basename(payloadPath);
const size = fs.statSync(payloadPath).size;
const sha256 = sha256File(payloadPath);
const fullName = `@${scope}/${name}`;

console.log(`[prepare-publish] Payload: ${payloadPath}`);
console.log(`[prepare-publish] Size: ${size} bytes`);
console.log(`[prepare-publish] SHA256: ${sha256}`);

const useChunks = size > thresholdMiB * 1024 * 1024;
const packageDirectories = [];

if (!useChunks) {
  const directory = path.join(out, 'package');
  fs.mkdirSync(directory, { recursive: true });
  fs.copyFileSync(payloadPath, path.join(directory, payloadName));
  fs.writeFileSync(path.join(directory, 'README.md'), `# ${fullName}\n\nPayload: \`${payloadName}\`\n`);

  writeJson(path.join(directory, 'package.json'), {
    name: fullName,
    version,
    description: `Package for ${payloadName}`,
    files: [payloadName, 'README.md'],
    publishConfig: { access: 'public' }
  });

  packageDirectories.push(directory);
  console.log('[prepare-publish] Mode: single package');
  console.log(`[prepare-publish] Package: ${fullName}@${version}`);
  console.log('[prepare-publish] The package contains the payload file. It does not extract the file.');
} else {
  const chunkCount = Math.ceil(size / chunkBytes);
  const parts = [];
  const fd = fs.openSync(payloadPath, 'r');
  const buffer = Buffer.alloc(1024 * 1024);

  try {
    for (let index = 0; index < chunkCount; index++) {
      const number = pad(index + 1);
      const directory = path.join(out, `chunk-${number}`);
      const partFile = `part${number}`;
      const partPath = path.join(directory, partFile);
      const want = Math.min(chunkBytes, size - index * chunkBytes);
      let remaining = want;

      fs.mkdirSync(directory, { recursive: true });
      const outFd = fs.openSync(partPath, 'w');
      try {
        while (remaining > 0) {
          const read = fs.readSync(fd, buffer, 0, Math.min(buffer.length, remaining), null);
          if (read <= 0) fail(`Unexpected end of payload: ${payloadPath}`);
          fs.writeSync(outFd, buffer, 0, read);
          remaining -= read;
        }
      } finally {
        fs.closeSync(outFd);
      }

      const packageName = platform === 'any'
        ? `${fullName}-chunk-${number}`
        : `${fullName}-${platform}-chunk-${number}`;
      writeJson(path.join(directory, 'package.json'), {
        name: packageName,
        version,
        description: `Payload chunk ${number} for ${payloadName}`,
        ...platformFields,
        files: [partFile, 'README.md'],
        publishConfig: { access: 'public' }
      });
      fs.writeFileSync(path.join(directory, 'README.md'), `# ${packageName}\n\nBinary chunk ${number} for ${payloadName}.\n`);
      parts.push({ package: packageName, file: partFile, bytes: want });
      packageDirectories.push(directory);
    }
  } finally {
    fs.closeSync(fd);
  }

  const loaderName = platform === 'any' ? `${fullName}-loader` : `${fullName}-${platform}`;
  const loaderDir = path.join(out, 'loader');
  const metaDir = path.join(out, 'meta');
  fs.mkdirSync(loaderDir, { recursive: true });
  fs.mkdirSync(metaDir, { recursive: true });

  writeJson(path.join(loaderDir, 'archive.json'), {
    payload: payloadName,
    size,
    sha256,
    installDir: name,
    stripComponents,
    parts
  });

  writeJson(path.join(loaderDir, 'package.json'), {
    name: loaderName,
    version,
    description: `Loader for ${payloadName}`,
    ...platformFields,
    files: ['install.js', 'archive.json', 'README.md'],
    scripts: { postinstall: 'node install.js' },
    dependencies: Object.fromEntries(parts.map((part) => [part.package, version])),
    engines: { node: '>=18' },
    publishConfig: { access: 'public' }
  });
  fs.writeFileSync(path.join(loaderDir, 'install.js'), installJs());
  fs.writeFileSync(path.join(loaderDir, 'README.md'), `# ${loaderName}\n\nJoins ${chunkCount} chunks, verifies SHA256, and extracts ${payloadName}.\n`);

  writeJson(path.join(metaDir, 'package.json'), {
    name: fullName,
    version,
    description: `Package for ${payloadName}`,
    files: ['README.md'],
    optionalDependencies: { [loaderName]: version },
    publishConfig: { access: 'public' }
  });
  fs.writeFileSync(path.join(metaDir, 'README.md'), `# ${fullName}\n\nInstall this package. The loader extracts ${payloadName} to \`${name}\` in the install directory.\n`);

  packageDirectories.push(loaderDir, metaDir);
  console.log(`[prepare-publish] Mode: chunked (${chunkCount} chunks)`);
  console.log(`[prepare-publish] Meta: ${fullName}@${version}`);
  console.log(`[prepare-publish] Loader: ${loaderName}@${version}`);
}

console.log(`[prepare-publish] Output: ${out}`);
printCommands(packageDirectories);

function installJs() {
  return String.raw`#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync, spawnSync } = require('node:child_process');
const { createRequire } = require('node:module');

const archive = require('./archive.json');
const pkg = require('./package.json');
const requireFromHere = createRequire(__filename);

function log(message) {
  console.log('[npm-payload] ' + message);
}

function fail(message) {
  console.error('[npm-payload] ' + message);
  process.exitCode = 1;
  throw new Error(message);
}

function invocationDirectory() {
  if (process.env.INIT_CWD) return path.resolve(process.env.INIT_CWD);
  if (process.env.npm_config_local_prefix) return path.resolve(process.env.npm_config_local_prefix);
  const cwd = process.cwd();
  const marker = path.sep + 'node_modules' + path.sep;
  const index = cwd.indexOf(marker);
  return index === -1 ? cwd : cwd.slice(0, index);
}

function isComplete(directory) {
  return fs.existsSync(path.join(directory, '.installed'));
}

function stripTopLevel(directory) {
  const entries = fs.readdirSync(directory);
  if (entries.length !== 1) fail('Cannot strip top-level directory: ' + directory);
  const top = path.join(directory, entries[0]);
  if (!fs.statSync(top).isDirectory()) fail('Cannot strip top-level directory: ' + top);
  for (const entry of fs.readdirSync(top)) {
    fs.renameSync(path.join(top, entry), path.join(directory, entry));
  }
  fs.rmdirSync(top);
}

async function main() {
  if (!Array.isArray(archive.parts) || archive.parts.length === 0) {
    fail('archive.json has no parts.');
  }

  const defaultDir = path.join(invocationDirectory(), archive.installDir || pkg.name.split('/').pop());
  const destination = path.resolve(process.env.NPM_PAYLOAD_INSTALL_DIR || defaultDir);
  if (/\s/.test(destination)) {
    fail('Install path contains spaces: ' + destination);
  }
  if (fs.existsSync(destination)) {
    if (isComplete(destination)) {
      log(pkg.version + ' is already installed at ' + destination);
      return;
    }
    if (fs.readdirSync(destination).length > 0) {
      fail('Destination is not an npm-payload install: ' + destination);
    }
  }

  const temporaryZip = path.join(os.tmpdir(), 'npm-payload-' + pkg.version + '-' + process.pid + '.zip');
  const staging = path.join(path.dirname(destination), '.staging-' + pkg.version + '-' + process.pid);
  const hash = crypto.createHash('sha256');
  let written = 0;

  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.rmSync(staging, { recursive: true, force: true });
  fs.mkdirSync(staging, { recursive: true });
  fs.writeFileSync(temporaryZip, '');

  try {
    for (const part of archive.parts) {
      const packageJson = requireFromHere.resolve(part.package + '/package.json');
      const partPath = path.join(path.dirname(packageJson), part.file);
      if (!fs.existsSync(partPath)) fail('Missing part: ' + partPath);
      const data = fs.readFileSync(partPath);
      hash.update(data);
      written += data.length;
      fs.appendFileSync(temporaryZip, data);
    }

    const actualHash = hash.digest('hex');
    if (written !== archive.size || actualHash !== archive.sha256) {
      fail('Verification failed: ' + written + '/' + archive.size + ' bytes, SHA256 ' + actualHash);
    }
    log('Verified ' + archive.payload + ' (' + written + ' bytes)');

    if (process.platform === 'win32') {
      const tar = path.join(process.env.SystemRoot || 'C:/Windows', 'System32', 'tar.exe');
      if (!fs.existsSync(tar)) fail('tar.exe was not found at ' + tar);
      const args = ['-xf', temporaryZip, '-C', staging];
      if (archive.stripComponents > 0) args.push('--strip-components=' + archive.stripComponents);
      execFileSync(tar, args, { stdio: 'inherit' });
    } else {
      const result = spawnSync('unzip', ['-q', temporaryZip, '-d', staging], { stdio: 'inherit' });
      if (result.error || result.status !== 0) fail('unzip failed. Install unzip, or use Windows.');
      if (archive.stripComponents === 1) stripTopLevel(staging);
      else if (archive.stripComponents > 1) fail('stripComponents > 1 is not supported on this platform.');
    }

    if (fs.existsSync(destination)) {
      if (fs.readdirSync(destination).length > 0) fail('Destination changed during install: ' + destination);
      fs.rmdirSync(destination);
    }
    fs.renameSync(staging, destination);
    fs.writeFileSync(path.join(destination, '.installed'), pkg.version + '\n' + archive.sha256 + '\n');
    log('Installed to ' + destination);
  } finally {
    fs.rmSync(temporaryZip, { force: true });
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

main().catch((error) => {
  if (!process.exitCode) {
    console.error(error.stack || String(error));
    process.exitCode = 1;
  }
});
`;
}
