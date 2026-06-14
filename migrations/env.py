import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.config import get_config
from app.database import BaseModelClass

Setting = get_config()

config = context.config

# Override the database URL from app settings
config.set_main_option("sqlalchemy.url", Setting.SQLALCHEMY_DATABASE_URI)

# Set up Python logging from config file
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Metadata used by Alembic to generate migrations
target_metadata = BaseModelClass.metadata


# Offline mode: generates SQL script without connecting to the DB
def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


# Core migration function, called inside a sync wrapper
def do_run_migrations(connection):
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,  # Enables checking column types for changes
    )

    with context.begin_transaction():
        context.run_migrations()


# Async mode: creates an async engine, then runs sync migrations
async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        # run_sync runs a sync function (do_run_migrations) in an async context
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


# Entry point: decides which mode to run
if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
