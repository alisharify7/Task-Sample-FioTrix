"""
* task management
* author: github.com/alisharify7
* email: alisharifyofficial@gmail.com
* license: see LICENSE for more details.
* Copyright (c) 2026 - ali sharifi
* https://github.com/alisharify7/Task-Sample-FioTrix
"""

import datetime

from pydantic import BaseModel


class CreateTaskSchem(BaseModel):
    title: str
    description: str | None  # Union[str, None]


class DetailTaskSchem(BaseModel):
    id: int
    title: str
    description: str | None  # Union[str, None]
    is_complete: bool
    created_at: datetime.datetime
