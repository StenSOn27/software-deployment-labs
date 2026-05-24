from typing import Annotated

from fastapi import APIRouter, Depends, Form, Header, Request
from fastapi.responses import RedirectResponse
from src.routes.dependencies import get_task_service
from fastapi.templating import Jinja2Templates

router = APIRouter(prefix="/tasks")
templates = Jinja2Templates(directory="src/templates")


@router.get("/")
async def get_tasks(
    request: Request,
    accept: Annotated[str | None, Header()] = None,
    service=Depends(get_task_service),
):
    tasks = await service.get_all_tasks()

    if accept:
        if "text/html" in accept:
            return templates.TemplateResponse(
                request=request,
                name="task_list.html",
                context={"tasks": tasks},
            )
        elif "application/json" in accept:
            return tasks


@router.api_route("/new", methods=["GET", "POST"])
async def create_task(
    request: Request,
    title: Annotated[str, Form()] = None,
    accept: Annotated[str | None, Header()] = None,
    service=Depends(get_task_service),
):
    if request.method == "POST":
        new_task = await service.create_task(title=title)

        if accept and "text/html" in accept:
            return RedirectResponse(url=f"/tasks/", status_code=303)
        return new_task

    if accept and "text/html" in accept:
        return templates.TemplateResponse(request=request, name="task_create.html")


@router.api_route("/done", methods=["GET", "POST"])
async def mark_task_done(
    request: Request,
    task_id: Annotated[str, Form()] = None,
    accept: Annotated[str | None, Header()] = None,
    service=Depends(get_task_service),
):

    if request.method == "POST":
        done_task = await service.mark_task_done(task_id=task_id)

        if accept and "text/html" in accept:
            return RedirectResponse(url=f"/tasks/", status_code=303)
        return done_task

    if accept and "text/html" in accept:
        return templates.TemplateResponse(
            request=request, name="task_mark_as_done.html"
        )
