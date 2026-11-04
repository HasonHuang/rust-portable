#!/usr/bin/env node
'use strict';

// Joins the npm data chunks, verifies the resulting ZIP, and extracts the
// portable Rust toolchain into `rust-portable` in the directory where npm was
// run. The install path must not contain spaces.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { createRequire } = require('node:module');
const { pipeline } = require('node:stream/promises');
const { Transform } = require('node:stream');

const archive = require('./archive.json');
const pkg = require('./package.json');
const requireFromHere = createRequire(__filename);

function log(message) {
  console.log(`[rust-portable] ${message}`);
}

function fail(message) {
  console.error(`[rust-portable] ${message}`);
  process.exitCode = 1;
  throw new Error(message);
}

function isComplete(directory) {
  return fs.existsSync(path.join(directory, 'windows', 'cargo', 'bin', 'cargo.exe'))
    && fs.existsSync(path.join(directory, 'windows', 'configure-env.bat'));
}

function invocationDirectory() {
  if (process.env.INIT_CWD) return path.resolve(process.env.INIT_CWD);
  if (process.env.npm_config_local_prefix) return path.resolve(process.env.npm_config_local_prefix);

  const cwd = process.cwd();
  const marker = `${path.sep}node_modules${path.sep}`;
  const index = cwd.indexOf(marker);
  return index === -1 ? cwd : cwd.slice(0, index);
}

function installedVersion(directory) {
  try {
    return fs.readFileSync(path.join(directory, 'VERSION'), 'utf8').trim();
  } catch {
    return '';
  }
}

function looksLikeInstall(directory) {
  return fs.existsSync(path.join(directory, '.installed'))
    || fs.existsSync(path.join(directory, 'windows', 'configure-env.bat'));
}

function isEmptyDirectory(directory) {
  try {
    return fs.readdirSync(directory).length === 0;
  } catch {
    return false;
  }
}

async function main() {
  if (process.platform !== 'win32' || process.arch !== 'x64') {
    fail(`Unsupported platform ${process.platform}/${process.arch}. This package supports Windows 10/11 x64 only.`);
  }
  if (!Array.isArray(archive.parts) || archive.parts.length === 0) {
    fail('archive.json does not list any data chunks.');
  }

  const defaultDestination = path.join(invocationDirectory(), 'rust-portable');
  const destination = path.resolve(process.env.RUST_PORTABLE_INSTALL_DIR || defaultDestination);
  if (/\s/.test(destination)) {
    fail(`Install path contains spaces: ${destination}\nSet RUST_PORTABLE_INSTALL_DIR to a path without spaces, for example C:\\rust-portable.`);
  }

  const installParent = path.dirname(destination);
  const marker = path.join(destination, '.installed');

  if (fs.existsSync(destination)) {
    if (isComplete(destination) && installedVersion(destination) === pkg.version) {
      log(`${pkg.version} is already installed at ${destination}`);
      printNextSteps(destination);
      return;
    }
    if (!looksLikeInstall(destination) && !isEmptyDirectory(destination)) {
      fail(`Destination is not a rust-portable install: ${destination}\nChoose another RUST_PORTABLE_INSTALL_DIR.`);
    }
    if (process.env.RUST_PORTABLE_FORCE !== '1') {
      const existing = installedVersion(destination);
      const detail = existing ? `rust-portable ${existing}` : 'an existing directory';
      fail(`Destination already contains ${detail}: ${destination}\nRemove it, or set RUST_PORTABLE_FORCE=1 to replace it.`);
    }
  }

  const temporaryZip = path.join(os.tmpdir(), `rust-portable-${pkg.version}-${process.pid}.zip`);
  const staging = path.join(installParent, `.staging-${pkg.version}-${process.pid}`);
  const hash = crypto.createHash('sha256');
  let written = 0;

  fs.mkdirSync(installParent, { recursive: true });
  fs.rmSync(staging, { recursive: true, force: true });
  fs.mkdirSync(staging, { recursive: true });
  fs.writeFileSync(temporaryZip, '');

  try {
    for (const part of archive.parts) {
      const packageJson = requireFromHere.resolve(`${part.package}/package.json`);
      const partPath = path.join(path.dirname(packageJson), part.file);
      if (!fs.existsSync(partPath)) {
        fail(`Missing data chunk: ${partPath}`);
      }
      log(`Adding ${part.package}/${part.file}`);
      const meter = new Transform({
        transform(chunk, encoding, callback) {
          hash.update(chunk);
          written += chunk.length;
          callback(null, chunk);
        }
      });
      await pipeline(
        fs.createReadStream(partPath),
        meter,
        fs.createWriteStream(temporaryZip, { flags: 'a' })
      );
    }

    const actualHash = hash.digest('hex');
    if (written !== archive.size || actualHash !== archive.sha256) {
      fail(`Archive verification failed: ${written}/${archive.size} bytes, SHA256 ${actualHash}.`);
    }
    log(`Verified ${archive.zip} (${written} bytes, SHA256 ${actualHash})`);

    const tar = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe');
    if (!fs.existsSync(tar)) {
      fail(`Windows tar.exe was not found at ${tar}. Windows 10 1803 or newer is required.`);
    }

    log(`Extracting to ${staging}`);
    execFileSync(tar, ['-xf', temporaryZip, '-C', staging, '--strip-components=1'], {
      stdio: 'inherit'
    });

    if (!isComplete(staging)) {
      fail('Extraction finished but windows\\cargo\\bin\\cargo.exe or windows\\configure-env.bat is missing.');
    }

    if (fs.existsSync(destination)) {
      if (isComplete(destination) && installedVersion(destination) === pkg.version) {
        log(`${pkg.version} is already installed at ${destination}`);
        printNextSteps(destination);
        return;
      }
      if (!looksLikeInstall(destination) && !isEmptyDirectory(destination)) {
        fail(`Destination is not a rust-portable install: ${destination}\nChoose another RUST_PORTABLE_INSTALL_DIR.`);
      }
      if (process.env.RUST_PORTABLE_FORCE !== '1') {
        fail(`Destination already exists: ${destination}\nRemove it, or set RUST_PORTABLE_FORCE=1 to replace it.`);
      }
      fs.rmSync(destination, { recursive: true, force: true });
    }

    fs.renameSync(staging, destination);
    fs.writeFileSync(marker, `${pkg.version}\n${archive.sha256}\n`);
    log(`Installed to ${destination}`);
    log('The npm data chunks remain in node_modules; remove that project\'s node_modules to reclaim the space.');
    printNextSteps(destination);
  } finally {
    fs.rmSync(temporaryZip, { force: true });
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function printNextSteps(destination) {
  const windows = path.join(destination, 'windows');
  console.log('');
  log('Next steps:');
  log(`  1. Run "${path.join(windows, 'configure-env.bat')}"`);
  log('  2. Open a new terminal');
  log(`  3. Run "${path.join(windows, 'doctor.bat')}"`);
}

main().catch((error) => {
  if (!process.exitCode) {
    console.error(error.stack || String(error));
    process.exitCode = 1;
  }
});
