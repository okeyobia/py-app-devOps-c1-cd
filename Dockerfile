# --- Stage 1: Build ---
FROM ghcr.io/astral-sh/uv:python3.11-trixie-slim AS builder

# Set the working directory
WORKDIR /app

# Enable bytecode compilation for faster startups
ENV UV_COMPILE_BYTECODE=1

# Copy only the dependency files first (better caching)
COPY pyproject.toml uv.lock ./

# Install dependencies into /app/.venv
# --no-install-project stops uv from looking for your 'app' code yet
RUN uv sync --frozen --no-dev --no-install-project

# Now copy the actual application code
COPY . .

# Final sync to include the project itself (creates the 'fastapi' entrypoint)
RUN uv sync --frozen --no-dev

# --- Stage 2: Final Runtime ---
FROM python:3.11-slim

WORKDIR /app

# CRITICAL: Copy the EXACT same folder structure from the builder
COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/app /app/app

# Update the PATH so the system finds 'python' and 'fastapi' in the venv
ENV PATH="/app/.venv/bin:$PATH"

# Run using the venv's python module to be safe
# CMD ["python", "-m", "fastapi", "run", "app/main.py", "--port", "80"]
# Point directly to the venv's python
CMD ["/app/.venv/bin/python", "-m", "fastapi", "run", "app/main.py", "--port", "80"]