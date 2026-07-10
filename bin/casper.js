#!/usr/bin/env node
/*
 * casper — npx wrapper around install.sh / uninstall.sh.
 *
 * `npx casper@latest` mirrors ./install.sh exactly. install.sh stays the floor;
 * this only forwards flags to it (and offers an interactive picker when run with
 * no arguments). It NEVER reimplements install logic — every real action shells
 * out to the sibling install.sh / uninstall.sh that ship in the package.
 *
 * Pass-through flags (identical semantics to install.sh):
 *   --only <names>   --category <name>   --all   --hooks   --init
 *   --dry-run        --global            uninstall
 *
 * Examples:
 *   npx casper@latest                 # interactive picker (or default toolkit)
 *   npx casper@latest --all           # judgment toolkit + entire collection
 *   npx casper@latest --only refute   # one skill
 *   npx casper@latest uninstall       # revert exactly what was installed
 */
'use strict';

const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const readline = require('readline');

const PKG_ROOT = path.resolve(__dirname, '..');
const INSTALL = path.join(PKG_ROOT, 'install.sh');
const UNINSTALL = path.join(PKG_ROOT, 'uninstall.sh');

function die(msg) {
  process.stderr.write(msg + '\n');
  process.exit(1);
}

function ensureScript(p) {
  if (!fs.existsSync(p)) {
    die('casper: cannot find ' + path.basename(p) + ' at ' + p +
        '\n(the npm package must ship install.sh/uninstall.sh alongside bin/).');
  }
}

// Run a shell script, inheriting stdio, and exit with its code.
function runScript(script, args) {
  ensureScript(script);
  const child = spawn('bash', [script, ...args], { stdio: 'inherit' });
  child.on('exit', (code, signal) => {
    if (signal) process.exit(1);
    process.exit(code === null ? 1 : code);
  });
  child.on('error', (err) => die('casper: failed to run ' + script + ': ' + err.message));
}

function ask(rl, q) {
  return new Promise((resolve) => rl.question(q, (a) => resolve(a.trim())));
}

// No args: offer a tiny interactive picker, then forward to install.sh.
async function interactive() {
  if (!process.stdin.isTTY) {
    // Non-interactive context (piped): behave like bare install.sh.
    return runScript(INSTALL, []);
  }
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  process.stdout.write('\n👻 Casper installer (wraps install.sh)\n\n');
  process.stdout.write('  1) Judgment toolkit — 13 skills            [default]\n');
  process.stdout.write('  2) Everything — toolkit + full collection  (--all)\n');
  process.stdout.write('  3) One skill/agent by name                 (--only <name>)\n');
  process.stdout.write('  4) A whole category                        (--category <name>)\n');
  process.stdout.write('  5) Uninstall                               (uninstall)\n\n');

  const choice = (await ask(rl, 'Pick 1-5 [1]: ')) || '1';
  const args = [];
  if (choice === '2') {
    args.push('--all');
  } else if (choice === '3') {
    const name = await ask(rl, 'Skill/agent name(s), comma-separated: ');
    if (!name) { rl.close(); die('casper: no name given.'); }
    args.push('--only', name);
  } else if (choice === '4') {
    const cat = await ask(rl, 'Category (e.g. verification-and-audit): ');
    if (!cat) { rl.close(); die('casper: no category given.'); }
    args.push('--category', cat);
  } else if (choice === '5') {
    const g = (await ask(rl, 'Global (~/.claude)? [y/N]: ')).toLowerCase();
    rl.close();
    return runScript(UNINSTALL, g.startsWith('y') ? ['--global'] : []);
  } else if (choice !== '1') {
    rl.close();
    die('casper: unrecognized choice "' + choice + '".');
  }

  const global = (await ask(rl, 'Install to global ~/.claude instead of ./.claude? [y/N]: ')).toLowerCase();
  if (global.startsWith('y')) args.push('--global');
  const hooks = (await ask(rl, 'Also copy hooks (default-OFF, opt-in)? [y/N]: ')).toLowerCase();
  if (hooks.startsWith('y')) args.push('--hooks');
  rl.close();
  return runScript(INSTALL, args);
}

function main() {
  const argv = process.argv.slice(2);

  if (argv.includes('-h') || argv.includes('--help')) {
    // Defer to install.sh's own help so there is a single source of truth.
    return runScript(INSTALL, ['--help']);
  }
  if (argv.length === 0) {
    return interactive();
  }
  // uninstall subcommand -> uninstall.sh (preserve --global).
  if (argv[0] === 'uninstall') {
    const rest = argv.slice(1).filter((a) => a === '--global');
    return runScript(UNINSTALL, rest);
  }
  // Everything else forwards verbatim to install.sh (which validates flags).
  return runScript(INSTALL, argv);
}

main();
