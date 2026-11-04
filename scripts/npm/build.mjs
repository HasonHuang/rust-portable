#!/usr/bin/env node
// Build npm packages for the Windows x64 portable bundle.
//
// The release ZIP is split into 100 MiB data chunks. Each chunk is published
// as its own npm package so that no single tarball approaches the registry's
// practical upload limit. A small platform package depends on every chunk,
// joins them back together, verifies the SHA256, and extracts the archive.
//
// Usage:
//   node scripts/npm/build.mjs            # version from VERSION
//   node scripts/npm/build.mjs r2         # revision package, e.g. 1.99.1-r2
//   NPM_SCOPE=ihason node scripts/npm/build.mjs
//   NPM_SCOPE=ihason NPM_CHUNK_MB=50 node scripts/npm/build.mjs
//
// Output: build/npm/

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const chunkMiB = Number(process.env.NPM_CHUNK_MB ?? '100');
if (!Number.isInteger(chunkMiB) || chunkMiB < 1 || chunkMiB > 200) {
  console.error(`[build-npm] Invalid NPM_CHUNK_MB '${process.env.NPM_CHUNK_MB}'. Use an integer between 1 and 200.`);
  process.exit(1);
}
const CHUNK_SIZE = chunkMiB * 1024 * 1024;
const REPOSITORY = {
  type: 'git',
  url: 'git+https://github.com/HasonHuang/rust-portable.git'
};
const HOMEPAGE = 'https://github.com/HasonHuang/rust-portable#readme';
const BUGS = { url: 'https://github.com/HasonHuang/rust-portable/issues' };
const AUTHOR = 'Hason Huang';
const KEYWORDS = ['rust', 'toolchain', 'portable', 'windows', 'mingw'];

function fail(message) {
  console.error(`[build-npm] ${message}`);
  process.exit(1);
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function pad(number) {
  return String(number).padStart(2, '0');
}

const revision = (process.argv[2] ?? '').trim();
if (revision && !/^r[0-9]+$/.test(revision)) {
  fail(`Invalid revision '${revision}'. Use r<N>, for example r2.`);
}

const version = fs.readFileSync(path.join(REPO, 'VERSION'), 'utf8').trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) {
  fail(`Invalid VERSION '${version}'. Use MAJOR.MINOR.PATCH.`);
}

const pkgVersion = revision ? `${version}-${revision}` : version;
const assetVersion = pkgVersion;
const zipName = `rust-portable-v${assetVersion}-windows-x64.zip`;
const zipPath = path.join(REPO, 'dist', zipName);
if (!fs.existsSync(zipPath)) {
  fail(`Missing ${zipPath}. Run scripts/build-windows.ps1 first.`);
}

const sumsPath = path.join(REPO, 'dist', 'SHA256SUMS');
if (!fs.existsSync(sumsPath)) {
  fail(`Missing ${sumsPath}.`);
}
const expectedHash = fs.readFileSync(sumsPath, 'utf8')
  .split(/\r?\n/)
  .map((line) => line.trim())
  .find((line) => line.endsWith(`  ${zipName}`))
  ?.split(/\s+/)[0];
if (!expectedHash || !/^[0-9a-f]{64}$/i.test(expectedHash)) {
  fail(`SHA256SUMS does not contain a valid entry for ${zipName}.`);
}

const scope = (process.env.NPM_SCOPE ?? '').trim().toLowerCase()
  .replace(/^@/, '')
  .replace(/\/$/, '');
if (scope && !/^[a-z0-9][a-z0-9._~-]*$/.test(scope)) {
  fail(`Invalid NPM_SCOPE '${scope}'.`);
}
const prefix = scope ? `@${scope}/` : '';
const metaName = `${prefix}rust-portable`;
const platformName = `${prefix}rust-portable-win32-x64`;

const size = fs.statSync(zipPath).size;
const chunkCount = Math.ceil(size / CHUNK_SIZE);
const outputRoot = path.join(REPO, 'build', 'npm');

fs.rmSync(outputRoot, { recursive: true, force: true });
fs.mkdirSync(outputRoot, { recursive: true });

const hash = crypto.createHash('sha256');
const buffer = Buffer.alloc(1024 * 1024);
const parts = [];
const fd = fs.openSync(zipPath, 'r');

try {
  for (let index = 0; index < chunkCount; index++) {
    const number = pad(index + 1);
    const partFile = `part${number}`;
    const packageName = `${platformName}-chunk-${number}`;
    const directory = path.join(outputRoot, `chunk-${number}`);
    const partPath = path.join(directory, partFile);

    fs.mkdirSync(directory, { recursive: true });
    const outFd = fs.openSync(partPath, 'w');
    let remaining = Math.min(CHUNK_SIZE, size - index * CHUNK_SIZE);
    const bytes = remaining;

    try {
      while (remaining > 0) {
        const want = Math.min(buffer.length, remaining);
        const read = fs.readSync(fd, buffer, 0, want, null);
        if (read <= 0) {
          fail(`Unexpected end of ${zipName}.`);
        }
        hash.update(buffer.subarray(0, read));
        fs.writeSync(outFd, buffer, 0, read);
        remaining -= read;
      }
    } finally {
      fs.closeSync(outFd);
    }

    writeJson(path.join(directory, 'package.json'), {
      name: packageName,
      version: pkgVersion,
      description: `rust-portable ${pkgVersion} Windows x64 data chunk ${index + 1}/${chunkCount}`,
      keywords: KEYWORDS,
      homepage: HOMEPAGE,
      bugs: BUGS,
      repository: REPOSITORY,
      author: AUTHOR,
      license: 'MIT',
      os: ['win32'],
      cpu: ['x64'],
      files: [partFile, 'README.md'],
      publishConfig: { access: 'public' }
    });

    fs.writeFileSync(path.join(directory, 'README.md'), `# ${packageName}

Data chunk ${index + 1} of ${chunkCount} for the rust-portable Windows x64 bundle.

This package contains binary data only. Install \`${metaName}\` or
\`${platformName}\` instead of installing this package directly.

The extracted bundle contains third-party toolchains with their own licenses.
See \`shared/licenses/\` and \`shared/THIRD-PARTY-NOTICES.md\` inside the bundle,
or <https://github.com/HasonHuang/rust-portable>.
`);

    parts.push({ package: packageName, file: partFile, bytes });
  }
} finally {
  fs.closeSync(fd);
}

const actualHash = hash.digest('hex');
if (actualHash !== expectedHash.toLowerCase()) {
  fs.rmSync(outputRoot, { recursive: true, force: true });
  fail(`SHA256 mismatch for ${zipName}: expected ${expectedHash}, got ${actualHash}.`);
}

const dependencies = Object.fromEntries(parts.map((part) => [part.package, pkgVersion]));

const platformDir = path.join(outputRoot, 'platform');
fs.mkdirSync(platformDir, { recursive: true });
writeJson(path.join(platformDir, 'package.json'), {
  name: platformName,
  version: pkgVersion,
  description: `Portable Rust ${version} toolchain for Windows x64`,
  keywords: KEYWORDS,
  homepage: HOMEPAGE,
  bugs: BUGS,
  repository: REPOSITORY,
  author: AUTHOR,
  license: 'MIT',
  os: ['win32'],
  cpu: ['x64'],
  files: ['install.js', 'archive.json', 'README.md'],
  bin: { 'rust-portable-install': 'install.js' },
  scripts: { postinstall: 'node install.js' },
  dependencies,
  engines: { node: '>=18' },
  publishConfig: { access: 'public' }
});

writeJson(path.join(platformDir, 'archive.json'), {
  zip: zipName,
  size,
  sha256: actualHash,
  parts
});

fs.copyFileSync(path.join(REPO, 'scripts', 'npm', 'install.js'), path.join(platformDir, 'install.js'));

fs.writeFileSync(path.join(platformDir, 'README.md'), `# ${platformName}

Portable Rust ${version} toolchain for Windows 10/11 x64.

This package does not download anything from the network. It joins the data
chunks installed from npm, verifies the SHA256 of the archive, and extracts it
to \`rust-portable\` in the directory where npm was run. This path is
\`<install dir>\` below. Set \`RUST_PORTABLE_INSTALL_DIR\` to the exact
install directory to use a different location; the path must not contain
spaces.

After installation:

1. Run \`<install dir>\\windows\\configure-env.bat\`.
2. Open a new terminal.
3. Run \`<install dir>\\windows\\doctor.bat\`.

\`configure-env.bat\` is part of the extracted bundle, not this npm package.

If the \`postinstall\` script was skipped (for example with \`--ignore-scripts\`),
run the installer manually:

\`\`\`powershell
node node_modules/${platformName}/install.js
\`\`\`

The bundle contains third-party toolchains with their own licenses. See
\`shared/licenses/\` and \`shared/THIRD-PARTY-NOTICES.md\` in the installed bundle.
Documentation: <https://github.com/HasonHuang/rust-portable/blob/main/docs/NPM.md>
`);

const metaDir = path.join(outputRoot, 'meta');
fs.mkdirSync(metaDir, { recursive: true });
writeJson(path.join(metaDir, 'package.json'), {
  name: metaName,
  version: pkgVersion,
  description: `Portable Rust ${version} toolchain`,
  keywords: KEYWORDS,
  homepage: HOMEPAGE,
  bugs: BUGS,
  repository: REPOSITORY,
  author: AUTHOR,
  license: 'MIT',
  files: ['README.md'],
  optionalDependencies: { [platformName]: pkgVersion },
  engines: { node: '>=18' },
  publishConfig: { access: 'public' }
});

fs.writeFileSync(path.join(metaDir, 'README.md'), `# ${metaName}

Portable Rust ${version} toolchain.

This package currently supports Windows 10/11 x64 only:

\`\`\`powershell
npm install ${metaName}
\`\`\`

Do not use \`--omit=optional\`, \`--no-optional\`, or \`--ignore-scripts\`.

The platform package extracts the toolchain to \`rust-portable\` in the
directory where npm was run. After installation, run
\`rust-portable\\windows\\configure-env.bat\` in that directory.

On other platforms npm skips the platform package. See
<https://github.com/HasonHuang/rust-portable/blob/main/docs/NPM.md> for
installation and troubleshooting, and
<https://github.com/HasonHuang/rust-portable> for licenses.
`);

console.log(`[build-npm] Built ${chunkCount} chunks for ${pkgVersion}`);
console.log(`[build-npm] Archive: ${zipName} (${size} bytes)`);
console.log(`[build-npm] SHA256 : ${actualHash}`);
console.log(`[build-npm] Meta   : ${metaName}`);
console.log(`[build-npm] Output : ${outputRoot}`);
