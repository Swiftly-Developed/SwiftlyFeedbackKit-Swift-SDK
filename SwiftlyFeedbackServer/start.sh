#!/bin/bash
set -e

# Use APP_ENV if set, otherwise default to production
ENV=${APP_ENV:-production}

# Use PORT if set, otherwise default to 8080
PORT=${PORT:-8080}

echo "Starting server with env=$ENV on port=$PORT"

exec ./SwiftlyFeedbackServer serve --env "$ENV" --hostname 0.0.0.0 --port "$PORT"
