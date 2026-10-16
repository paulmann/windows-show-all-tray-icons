#!/usr/bin/env node
'use strict';

/**
 * trayiconguard — npm wrapper for the TrayIconGuard Windows binary.
 *
 * The package does not bundle the executable: it downloads the release asset, verifies its
 * SHA-256 against the project's update feed, caches it and runs it. That keeps the npm
 * package tiny and guarantees that the binary you get is the one the project published.
 */

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const https = require('node:https');
const { spawnSync } = require('node:child_process');

const REPO = 'paulmann/windows-show-all-tray-icons';
const DEFAULT_FEED = `https://raw.githubusercontent.com/${REPO}/main/update/stable.json`;
const PKG = require('../package.json');

const bold = (s) => (process.stdout.isTTY ? `\u001b[1m${s}\u001b[0m` : s);
const dim = (s) => (process.stdout.isTTY ? `\u001b[2m${s}\u001b[0m` : s);

function cacheDir() {
  const base = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
  return path.join(base, 'TrayIconGuard', 'npm');
}

function exePath(version) {
  return path.join(cacheDir(), `TrayIconGuard-${version}.exe`);
}

function log(msg) {
  process.stderr.write(`${msg}\n`);
}

function fail(msg, code = 1) {
  log(`error: ${msg}`);
  process.exit(code);
}

function usage() {
  const text = `
${bold('trayiconguard')} ${PKG.version} — keep every Windows tray icon visible

Usage: trayiconguard <command> [options]

Commands
  install                  download the exe (SHA-256 verified) and start the GUI wizard
  download                 download + verify the exe into the cache, do not run it
  run [--minimized]        run the cached exe (downloads it on first use)
  status [--json]          print tray state (--json for machine-readable output)
  promote-all              promote every hidden icon now, then exit
  autostart on|off         add/remove the HKCU Run entry
  update                   check the git feed and install a newer version non-interactively
  uninstall                remove shortcuts, autostart and the installed copy
  exe [--print]            print the path of the cached executable
  version                  print the wrapper and binary version
  help                     this text

Options
  --version <v>            use a specific release version (default: the feed's version)
  --url <url>              direct exe URL (skips the feed; SHA-256 then comes from the feed
                           only if the versions match, otherwise verification is skipped)
  --feed <url>             alternative feed URL (env: TRAYICONGUARD_FEED)
  --force                  re-download even if the cached file exists
  --machine <dir>          install for all users into <dir> (needs an elevated shell)
  --minimized              start hidden in the notification area
  --no-verify              skip the SHA-256 check (discouraged)
  -h, --help               this text

Examples
  npx trayiconguard install
  npx trayiconguard status --json
  npx trayiconguard autostart on
  npx trayiconguard update
`;
  process.stdout.write(text.trimStart());
}

function parseArgs(argv) {
  const out = { command: 'help', flags: {}, rest: [] };
  const withValue = new Set(['--version', '--url', '--feed', '--machine']);
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '-h' || a === '--help') out.flags.help = true;
    else if (a === '--json') out.flags.json = true;
    else if (a === '--force') out.flags.force = true;
    else if (a === '--minimized') out.flags.minimized = true;
    else if (a === '--no-verify') out.flags.noVerify = true;
    else if (a === '--print') out.flags.print = true;
    else if (withValue.has(a)) {
      const v = argv[i + 1];
      if (!v || v.startsWith('-')) fail(`${a} needs a value`);
      out.flags[a.slice(2)] = v;
      i += 1;
    } else if (a.startsWith('-')) fail(`unknown option ${a}`);
    else if (out.command === 'help') out.command = a;
    else out.rest.push(a);
  }
  if (out.command === 'help' && out.flags.help !== true) out.command = argv.length ? out.command : 'help';
  return out;
}

function request(url, redirects = 5) {
  return new Promise((resolve, reject) => {
    const req = https.get(
      url,
      { headers: { 'User-Agent': `trayiconguard-npm/${PKG.version}`, Accept: '*/*' } },
      (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          if (redirects <= 0) return reject(new Error('too many redirects'));
          const next = new URL(res.headers.location, url).toString();
          return request(next, redirects - 1).then(resolve, reject);
        }
        if (res.statusCode !== 200) {
          res.resume();
          return reject(new Error(`HTTP ${res.statusCode} for ${url}`));
        }
        return resolve(res);
      },
    );
    req.on('error', reject);
    req.setTimeout(30000, () => req.destroy(new Error('request timed out')));
  });
}

async function readText(url) {
  const res = await request(url);
  return new Promise((resolve, reject) => {
    let data = '';
    res.setEncoding('utf8');
    res.on('data', (c) => {
      data += c;
    });
    res.on('end', () => resolve(data));
    res.on('error', reject);
  });
}

async function readFeed(url) {
  let parsed;
  try {
    parsed = JSON.parse(await readText(url));
  } catch (err) {
    throw new Error(`cannot read the update feed (${url}): ${err.message}`);
  }
  if (!parsed || !parsed.version || !parsed.url) throw new Error(`feed ${url} has no version/url`);
  return parsed;
}

function sha256(file) {
  const h = crypto.createHash('sha256');
  h.update(fs.readFileSync(file));
  return h.digest('hex');
}

async function download(url, dest, expected) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  const tmp = `${dest}.part`;
  log(dim(`downloading ${url}`));
  const res = await request(url);
  const total = Number(res.headers['content-length'] || 0);
  let seen = 0;
  const out = fs.createWriteStream(tmp);
  await new Promise((resolve, reject) => {
    res.on('data', (chunk) => {
      seen += chunk.length;
      if (total && process.stderr.isTTY) {
        const pct = Math.floor((seen / total) * 100);
        process.stderr.write(`\r  ${pct}% (${seen} / ${total} bytes)`);
      }
    });
    res.pipe(out);
    out.on('finish', () => {
      if (total && process.stderr.isTTY) process.stderr.write('\r');
      resolve();
    });
    out.on('error', reject);
    res.on('error', reject);
  });
  if (total && seen !== total) fail(`download truncated (${seen} of ${total} bytes)`);
  fs.renameSync(tmp, dest);
  const got = sha256(dest);
  if (expected && got.toLowerCase() !== String(expected).toLowerCase()) {
    fs.unlinkSync(dest);
    fail(`SHA-256 mismatch!\n  expected ${expected}\n  got      ${got}\nThe file was deleted; report this at https://github.com/${REPO}/issues`);
  }
  return got;
}

async function ensureExe(flags) {
  const feedUrl = flags.feed || process.env.TRAYICONGUARD_FEED || DEFAULT_FEED;
  let feed = null;
  try {
    feed = await readFeed(feedUrl);
  } catch (err) {
    if (!flags.url) throw err;
    log(dim(`feed unavailable (${err.message}) — continuing with --url only`));
  }

  const version = flags.version || (feed ? feed.version : PKG.version);
  const url = flags.url || feed.url;
  const dest = exePath(version);

  // The SHA-256 is trustworthy only when it comes from the feed for this exact version.
  let expected = null;
  if (!flags.noVerify && feed) {
    if (version === feed.version) expected = feed.sha256;
    else log(`warning: version ${version} differs from the feed (${feed.version}) — SHA-256 will not be verified`);
  }

  if (fs.existsSync(dest) && !flags.force) {
    if (expected && sha256(dest) === expected.toLowerCase()) {
      log(`${bold('cached')} ${dest} ${dim(`(${version})`)}`);
      return dest;
    }
    if (expected) log(dim('cached file no longer matches the feed — re-downloading'));
  }

  if (!expected && !flags.noVerify) {
    log('warning: no SHA-256 available for this version — download is NOT verified');
  }
  await download(url, dest, expected);
  log(`${bold('ready')} ${dest} ${dim(`(${version})`)}`);
  return dest;
}

function runExe(exe, args) {
  const r = spawnSync(exe, args, { stdio: 'inherit', windowsHide: false });
  if (r.error) fail(`cannot start ${exe}: ${r.error.message}`);
  process.exit(r.status === null ? 1 : r.status);
}

async function main() {
  const { command, flags, rest } = parseArgs(process.argv.slice(2));
  if (flags.help || command === 'help') return usage();

  if (command === 'version') {
    process.stdout.write(`trayiconguard (npm wrapper) ${PKG.version}\n`);
    try {
      const feed = await readFeed(flags.feed || DEFAULT_FEED);
      process.stdout.write(`latest published binary: ${feed.version} (${feed.url})\n`);
    } catch {
      process.stdout.write('update feed unreachable\n');
    }
    return;
  }

  if (process.platform !== 'win32') {
    fail(
      `TrayIconGuard is a Windows application (this host is ${process.platform}).\n` +
        'The binary is published at https://github.com/' + REPO + '/releases/latest',
    );
  }

  switch (command) {
    case 'download': {
      const exe = await ensureExe(flags);
      process.stdout.write(`${exe}\n`);
      return;
    }
    case 'exe': {
      const exe = await ensureExe(flags);
      process.stdout.write(`${exe}\n`);
      if (!flags.print) log(dim('cached; pass --print to suppress this note'));
      return;
    }
    case 'run': {
      const exe = await ensureExe(flags);
      return runExe(exe, flags.minimized ? ['--minimized'] : []);
    }
    case 'install': {
      const exe = await ensureExe(flags);
      if (flags.machine) {
        log(dim('machine-wide install needs an elevated shell (UAC)'));
        return runExe(exe, ['--install-machine', flags.machine, '--autostart', '--desktop', '--menu']);
      }
      log(dim('starting the setup wizard: choose "Only for me" (no UAC) or "For all users"'));
      return runExe(exe, []);
    }
    case 'status': {
      const exe = await ensureExe(flags);
      return runExe(exe, flags.json ? ['--status', '--json'] : ['--status']);
    }
    case 'promote-all': {
      const exe = await ensureExe(flags);
      return runExe(exe, ['--promote-all']);
    }
    case 'autostart': {
      const mode = (rest[0] || '').toLowerCase();
      if (mode !== 'on' && mode !== 'off') fail('usage: trayiconguard autostart on|off');
      const exe = await ensureExe(flags);
      return runExe(exe, [mode === 'on' ? '--install-autostart' : '--uninstall-autostart']);
    }
    case 'update': {
      const exe = await ensureExe(flags);
      return runExe(exe, ['--update-now']);
    }
    case 'uninstall': {
      const exe = await ensureExe(flags);
      return runExe(exe, ['--uninstall']);
    }
    default:
      usage();
      fail(`unknown command ${command}`, 2);
  }
}

main().catch((err) => fail(err && err.message ? err.message : String(err)));
