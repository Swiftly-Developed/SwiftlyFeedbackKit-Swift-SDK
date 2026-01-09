# ================================
# Build Stage
# ================================
FROM swift:6.0-jammy as build

# Install system dependencies for PostgreSQL
RUN apt-get update && apt-get install -y \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy Package.swift and Package.resolved first for better layer caching
COPY Package.swift Package.resolved ./

# Resolve dependencies
RUN swift package resolve

# Copy source code
COPY Sources ./Sources

# Build the application in release mode
RUN swift build -c release --static-swift-stdlib

# ================================
# Runtime Stage
# ================================
FROM swift:6.0-jammy-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Set working directory
WORKDIR /app

# Copy built executable from build stage
COPY --from=build --chown=vapor:vapor /build/.build/release/SwiftlyFeedbackServer /app/SwiftlyFeedbackServer

# Switch to non-root user
USER vapor

# Expose port (Heroku will set $PORT dynamically)
EXPOSE 8080

# Start the server
# Vapor automatically respects $PORT environment variable
ENTRYPOINT ["./SwiftlyFeedbackServer"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
