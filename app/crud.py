from typing import List

import sqlalchemy as sa
import sqlalchemy.ext.asyncio as asa
from fastapi import Depends, HTTPException, status
from sqlalchemy.exc import SQLAlchemyError

from app.database import get_session
from app.models import Task
from app.routers import task_router
from app.schemas import CreateTaskSchem, DetailTaskSchem, ListTaskSchem, UpdateTaskSchem


@task_router.get("/", response_model=List[ListTaskSchem], status_code=status.HTTP_200_OK)
async def list_tasks(
    db_session: asa.AsyncSession = Depends(get_session),
):
    """List all tasks"""
    stmt = sa.select(Task)
    result = await db_session.execute(stmt)
    tasks = result.scalars().all()
    return tasks


@task_router.post("/", status_code=status.HTTP_201_CREATED)
async def create_task(
    task: CreateTaskSchem,
    db_session: asa.AsyncSession = Depends(get_session),
):
    """Create a new task"""
    new_task = Task(**task.model_dump())
    db_session.add(new_task)
    try:
        await db_session.commit()
    except SQLAlchemyError as e:
        await db_session.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error: task could not be created",
        ) from e
    # Return 201 with no body
    return {}


@task_router.get("/{task_id}/", response_model=DetailTaskSchem, status_code=status.HTTP_200_OK)
async def retrieve_task(
    task_id: int,
    db_session: asa.AsyncSession = Depends(get_session),
):
    """Get a single task by ID"""
    stmt = sa.select(Task).where(Task.id == task_id)
    result = await db_session.execute(stmt)
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found.",
        )
    return task


@task_router.put("/{task_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def update_task(
    task_id: int,
    task_data: UpdateTaskSchem,
    db_session: asa.AsyncSession = Depends(get_session),
):
    """Fully update a task (all fields)"""
    update_values = task_data.model_dump(exclude_unset=True)
    if not update_values:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update.",
        )

    stmt = sa.update(Task).where(Task.id == task_id).values(**update_values)
    try:
        result = await db_session.execute(stmt)
        await db_session.commit()
    except SQLAlchemyError as e:
        await db_session.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error: task could not be updated",
        ) from e

    if result.rowcount == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found.",
        )
    return {}  # 204 No Content


@task_router.delete("/{task_id}/", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: int,
    db_session: asa.AsyncSession = Depends(get_session),
):
    """Delete a task"""
    stmt = sa.delete(Task).where(Task.id == task_id)
    try:
        result = await db_session.execute(stmt)
        await db_session.commit()
    except SQLAlchemyError as e:
        await db_session.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error: task could not be deleted",
        ) from e

    if result.rowcount == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found.",
        )
    return {}  # 204 No Content
