from fastapi.routing import APIRouter

task_router = APIRouter()

import app.crud  # noqa
