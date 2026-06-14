#!/bin/bash
set -e

echo "⏳ Downloading wait-for-it.sh..."
curl -s -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
chmod +x wait-for-it.sh

echo "⏳ Waiting for Postgres to be ready..."
./wait-for-it.sh $DATABASE_HOST:$DATABASE_PORT --timeout=30 --strict -- echo "✅ Postgres is ready."

echo "🚀 Running FastAPI migrations..."
alembic upgrade head
echo "✅ Migrations applied successfully."
