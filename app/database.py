"""
* task management
* author: github.com/alisharify7
* email: alisharifyofficial@gmail.com
* license: see LICENSE for more details.
* Copyright (c) 2026 - ali sharifi
* https://github.com/alisharify7/Task-Sample-FioTrix
"""

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import declarative_base

from app.config import get_config

Setting = get_config()

engine = create_async_engine(
    url=Setting.SQLALCHEMY_DATABASE_URI,
    pool_size=30,
    max_overflow=10,
    echo=Setting.DEBUG_QUERY,
)

Session = async_sessionmaker(bind=engine, autoflush=False, autocommit=False)

BaseModelClass = declarative_base()


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Get a fresh session for connection to database"""
    async with Session() as session:
        yield session
