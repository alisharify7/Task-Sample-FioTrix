from typing import List

import sqlalchemy as sa
import sqlalchemy.ext.asyncio as asa
from fastapi import Depends, HTTPException
from starlette import status

from app.database import get_session
from app.models import Task
from app.routers.tasks import task_router
from app.schemas import CreateTaskSchem, DetailTaskSchem, ListTaskSchem, UpdateTaskSchem


@task_router.get("/", response_model=List[ListTaskSchem], status_code=status.HTTP_200_OK)
async def list(
    db_session: asa.AsyncSession = Depends(get_session),
):
    """list all tasks in database"""
    list_query = sa.select(Task)
    tasks = await db_session.scalars(statement=list_query)
    return tasks


@task_router.post("/", status_code=status.HTTP_201_CREATED)
async def add(
    task: CreateTaskSchem,
    db_session: asa.AsyncSession = Depends(get_session),
):
    task_object = Task(**task.model_dump())
    result = await task_object.save(db_session=db_session)
    if result:
        return {}  # 201 created, no response
    raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="server error.")


@task_router.get("/{task_id}/", response_model=DetailTaskSchem, status_code=status.HTTP_200_OK)
async def retrieve(task_id: int, db_session: asa.AsyncSession = Depends(get_session)):
    detail_query = sa.select(Task).where(Task.id == task_id)
    result = await db_session.execute(detail_query)
    result = result.scalar_one_or_none()
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="task not found.")
    return result


@task_router.put("/{task_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def update(
    task_id: int, task: UpdateTaskSchem, db_session: asa.AsyncSession = Depends(get_session)
):
    update_query = sa.update(Task).where(Task.id == task_id).values(**task.model_dump())
    try:
        result = await db_session.execute(update_query)
        await db_session.commit()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="server error."
        )
    if result.rowcount > 0:
        return {}
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="task not found.")


@task_router.delete("/{task_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def destroy(task_id: int, db_session: asa.AsyncSession = Depends(get_session)):
    delete_query = sa.delete(Task).where(Task.id == task_id)
    try:
        result = await db_session.execute(delete_query)
        await db_session.commit()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="server error."
        )
    if result.rowcount > 0:
        return {}
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="task not found.")
