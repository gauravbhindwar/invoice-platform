#!/usr/bin/env node
// Quick list of DBs and sizes using mongosh inside the mongo container
import { execSync } from 'child_process';
console.log('Listing databases (mongosh) ...');
try {
  execSync("docker exec invoice-platform-mongo-1 sh -c 'mongosh --quiet --eval \"db.adminCommand({ listDatabases: 1 })\"'", { stdio: 'inherit' });
} catch (err) {
  console.error('Failed to run mongosh. Is the mongo container running?');
  process.exit(1);
}
