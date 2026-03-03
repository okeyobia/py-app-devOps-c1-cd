# Use a specific uv image for the build stage
FROM ghcr.io/astral-sh/uv:python3.11-slim AS builder

WORKDIR /app

# Enable bytecode compilation for faster startups
ENV UV_COMPILE_BYTECODE=1
# Copy only the files needed for dependency installation
COPY pyproject.toml uv.lock ./

# Install dependencies without the project itself
RUN uv sync --frozen --no-dev --no-install-project

FROM python:3.11-slim

WORKDIR /app

# # Install uv
# RUN pip install uv

# Copy the virtual environment from the builder
COPY --from=builder /app/.venv /app/.venv
COPY . .

# Ensure the app uses the virtual environment's python
ENV PATH="/app/.venv/bin:$PATH"

CMD ["fastapi", "run", "main.py", "--port", "80"]