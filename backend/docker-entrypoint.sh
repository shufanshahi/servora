#!/bin/sh
set -e

echo "Applying database migrations..."
node node_modules/node-pg-migrate/bin/node-pg-migrate.js up -m src/db/migrations -j sql

echo "Starting Servora API..."
# exec makes node PID 1 so it receives SIGTERM and shuts down gracefully.
exec node dist/server.js
