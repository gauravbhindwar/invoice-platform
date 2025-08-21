#!/usr/bin/env node
// Restores ./mongo-backup/mongo.dump.gz into the running mongo container
import { execSync } from 'child_process';
import { existsSync } from 'fs';

const file = './mongo-backup/mongo.dump.gz';
if (!existsSync(file)) {
  console.error('Backup file not found:', file);
  process.exit(1);
}
console.log('Copying archive into mongo container...');
execSync('docker cp ./mongo-backup/mongo.dump.gz invoice-platform-mongo-1:/data/db/mongo.restore.gz', { stdio: 'inherit' });
console.log('Running mongorestore...');
execSync("docker exec invoice-platform-mongo-1 sh -c 'mongorestore --archive=/data/db/mongo.restore.gz --gzip --drop'", { stdio: 'inherit' });
console.log('Restore complete');
