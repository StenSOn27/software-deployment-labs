from sqlalchemy import select
from src.database.engine import db_helper
from src.database.models import Task
from fastapi import Depends


class TaskRepository:
    def __init__(self, db_session):
        self.db_session = db_session

    async def get_all_tasks(self):
        result = await self.db_session.execute(select(Task))
        return result.scalars().all()

    async def get_task_by_id(self, task_id):
        result = await self.db_session.execute(select(Task).where(Task.id == task_id))
        return result.scalar_one_or_none()

    async def create_task(self, title: str):
        new_task = Task(title=title)
        self.db_session.add(new_task)
        await self.db_session.commit()
        await self.db_session.refresh(new_task)
        return new_task

    async def mark_task_done(self, task_id):
        task = await self.get_task_by_id(task_id)
        task.status = True
        await self.db_session.commit()
        return task
