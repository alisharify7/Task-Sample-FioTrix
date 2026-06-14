#!/usr/bin/env bash
set -e

echo "🚀 Migrating changes to Database"

echo "🚀 Starting server..."
if [ "$DEBUG" != "True" ]; then
    echo "🏗️ Production mode - Using Gunicorn"
    uvicorn main:app --worker 4
else
    echo "🔧 Development mode - Using development server"
    #    uvicorn app
    uv run fastapi dev --reaload --port 8000
fi
