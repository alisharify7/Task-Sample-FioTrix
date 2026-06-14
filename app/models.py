"""
* task management
* author: github.com/alisharify7
* email: alisharifyofficial@gmail.com
* license: see LICENSE for more details.
* Copyright (c) 2026 - ali sharifi
* https://github.com/alisharify7/Task-Sample-FioTrix
"""

import datetime
import typing

import sqlalchemy as sa
import sqlalchemy.ext.asyncio as AsyncSA
import sqlalchemy.orm as so

from app.config import get_config
from app.database import BaseModelClass, get_session

Setting = get_config()


class BaseModel(BaseModelClass):
    """Base abstract model."""

    __abstract__ = True
    id: so.Mapped[int] = so.mapped_column(sa.BigInteger(), primary_key=True)
    created_at: so.Mapped[typing.Optional[datetime.datetime]] = so.mapped_column(
        sa.TIMESTAMP(timezone=True),  # Add timezone support
        default=lambda: datetime.datetime.now(datetime.UTC),
    )
    modified_at: so.Mapped[typing.Optional[datetime.datetime]] = so.mapped_column(
        sa.TIMESTAMP(timezone=True),
        onupdate=lambda: datetime.datetime.now(datetime.UTC),
        default=lambda: datetime.datetime.now(datetime.UTC),
    )

    @staticmethod
    def set_table_name(name: str) -> str:
        """
        concat prefix name with tables names in database
        example:
            prefix: hello
            table_name: users
            set_table_name(users) = hello_users

        :param name: name of the table
        :type name: str
        :return: name of the table
        :rtype: str
        """
        name = name.replace("-", "_").replace(" ", "")
        return f"{Setting.DATABASE_TABLE_PREFIX_NAME}{name}".lower()

    async def save(
        self,
        db_session: AsyncSA.AsyncSession | None = None,
        show_traceback: bool = True,
        capture_traceback: bool = True,
    ) -> bool:
        """
        Combination of two steps: add and commit session

        :param db: Optional SQLAlchemy session to use. If None, a session will be created via `get_db()`
        :param show_traceback: Flag to show traceback of the exception to stdout or not
        :param capture_trackback: Flag to capture and return the exception
        :return: True if the save operation is successful, otherwise False
        """

        session: AsyncSA.AsyncSession = db_session or get_session()
        try:
            session.add(self)
            await session.commit()
            return True
        except Exception as e:
            await session.rollback()
            if show_traceback:
                print("Error occurred while saving the object", e)

            if capture_traceback:
                return e

            return False

    async def delete(
        self,
        capture_exception: bool = False,
        session: AsyncSA.AsyncSession | None = None,
    ):
        """delete object method"""
        db: AsyncSA.AsyncSession = session or get_session()

        try:
            await db.delete(self)
            await db.commit()
            return True
        except Exception as e:
            await db.rollback()
            if capture_exception:
                return e
            return False


class Task(BaseModel):
    __tablename__ = BaseModel.set_table_name("tasks")
    title: so.Mapped[str] = so.mapped_column(sa.String(512), nullable=False)
    description: so.Mapped[str] = so.mapped_column(sa.String(1024), nullable=True)
    is_complete: so.Mapped[bool] = so.mapped_column(sa.Boolean(), nullable=False, default=False)
