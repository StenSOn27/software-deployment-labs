from fastapi import Depends
from src.repositories.task_repository import TaskRepository
from src.services.task_service import TaskService
from sqlalchemy.ext.asyncio import AsyncSession
from src.database.engine import db_helper


def get_task_repository(db: AsyncSession = Depends(db_helper.get_db_session)):
    return TaskRepository(db)


def get_task_service(task_repository=Depends(get_task_repository)):
    return TaskService(task_repository)
