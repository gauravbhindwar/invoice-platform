#!/usr/bin/env node
// Creates ./mongo-backup/mongo.dump.gz by running mongodump in the mongo container
import { execSync } from 'child_process';
import { mkdirSync } from 'fs';

mkdirSync('./mongo-backup', { recursive: true });
console.log('Running mongodump inside invoice-platform-mongo-1...');
execSync("docker exec invoice-platform-mongo-1 sh -c 'mongodump --archive=/data/db/mongo.dump --gzip'", { stdio: 'inherit' });
console.log('Copying archive to ./mongo-backup/mongo.dump.gz');
execSync('docker cp invoice-platform-mongo-1:/data/db/mongo.dump ./mongo-backup/mongo.dump.gz', { stdio: 'inherit' });
console.log('Backup complete: ./mongo-backup/mongo.dump.gz');
