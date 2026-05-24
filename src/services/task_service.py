class TaskService:
    def __init__(self, task_repository):
        self.task_repository = task_repository

    async def get_all_tasks(self):
        return await self.task_repository.get_all_tasks()

    async def create_task(self, title: str):
        return await self.task_repository.create_task(title=title)

    async def mark_task_done(self, task_id: int):
        return await self.task_repository.mark_task_done(task_id)
