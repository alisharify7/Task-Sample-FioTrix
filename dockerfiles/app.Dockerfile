#TODO: add multi stage docker building
FROM docker.arvancloud.ir/python:3.14-slim-trixie

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

COPY . /app/
COPY ./pyproject.toml /app/pyproject.toml

RUN uv sync --verbose

# TODO: create custom user and run app with related permissions
EXPOSE 8000
RUN chmod +x /app/scripts/*.sh
CMD ["bash", "/app/scripts/run_web.sh"]
