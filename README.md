# 📋 Task Management API (FastAPI + PostgreSQL + Docker + systemd)

[![Python](https://img.shields.io/badge/Python-3.14+-blue.svg)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-009688.svg)](https://fastapi.tiangolo.com)
[![Docker](https://img.shields.io/badge/Docker-27.3+-2496ED.svg)](https://docker.com)

Fast, async Task Management REST API built for the FioTrix interview. Full CRUD, auto‑docs, PostgreSQL, and ready for production.

## ✨ Key Features

- Full CRUD operations for tasks
- Interactive Swagger docs at `/docs`
- Async SQLAlchemy + PostgreSQL
- Pydantic v2 validation
- Docker Compose (API + PostgreSQL + pgAdmin)
- `uv` package manager (blazing fast)
- systemd support for production

## 🚀 Quick Start

### Prerequisites
- Python 3.14+ **or** Docker Engine
- `uv` package manager: `curl -LsSf https://astral.sh/uv/install.sh | sh`

### Local installation (with uv)
```bash
git clone https://github.com/alisharify7/Task-Sample-FioTrix
cd Task-Sample-FioTrix
sudo chmod +x ./scripts/install.sh
sudo ./scripts/install.sh
```
#### Or one‑line curl:

```bash
curl -fsSL https://raw.githubusercontent.com/alisharify7/Task-Sample-FioTrix/main/scripts/install.sh -o install.sh && sudo bash install.sh
```

#### Docker (production ready)
```bash
docker compose up --build
```

API: http://localhost:8000

pgAdmin: http://localhost:9001 (email: default@example.com, password: password)


## 📡 API Endpoints (prefix `/api/v1`)

| Method | Endpoint           | Description          |
|--------|--------------------|----------------------|
| GET    | `/tasks/`          | List all tasks       |
| POST   | `/tasks/`          | Create a task        |
| GET    | `/tasks/{id}/`     | Retrieve a task      |
| PUT    | `/tasks/{id}/`     | Full update          |
| DELETE | `/tasks/{id}/`     | Delete a task        |

> Full interactive docs at `/docs` (Swagger UI).

## 🔧 Environment Variables (create `.env`)

| Variable                 | Description                         | Default / Example          |
|--------------------------|-------------------------------------|----------------------------|
| `DATABASE_NAME`          | PostgreSQL database name            | `taskdb`                   |
| `DATABASE_USERNAME`      | Database user                       | `postgres`                 |
| `DATABASE_PASSWORD`      | Database password                   | `root`                     |
| `DATABASE_HOST`          | Host (use `postgres` for Docker)    | `localhost` / `postgres`   |
| `DATABASE_PORT`          | PostgreSQL port                     | `5432`                     |
| `APP_SECRET_KEY`         | JWT signing key                     | (auto‑generated if empty)  |
| `PGADMIN_DEFAULT_EMAIL`  | pgAdmin login (Docker only)         | `admin@example.com`        |
| `PGADMIN_DEFAULT_PASSWORD`| pgAdmin password (Docker only)     | `password`                 |
