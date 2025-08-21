#!/usr/bin/env node
const { spawnSync } = require('child_process');
const args = process.argv.slice(2);

if (args.length < 2) {
  console.error('Usage: npm run add -- <workspacePath> <pkg1> [pkg2 ...]');
  console.error('Example: npm run add -- services/auth-service bcryptjs jsonwebtoken');
  process.exit(1);
}

const workspace = args[0];
const pkgs = args.slice(1);

console.log(`Installing ${pkgs.join(' ')} into workspace ${workspace}...`);

const cmdArgs = ['install', `--workspace=${workspace}`, '--save', ...pkgs];
const ret = spawnSync('npm', cmdArgs, { stdio: 'inherit' });

if (ret.error) {
  console.error('Failed to run npm:', ret.error);
  process.exit(1);
}

process.exit(ret.status);
