from typing import Annotated

from fastapi import FastAPI, Header, Request
from fastapi.routing import APIRoute
from fastapi.templating import Jinja2Templates
from src.routes.task_routes import router as task_router
from src.routes.health import router as health_router

app = FastAPI()

app.include_router(health_router, tags=["health"])
app.include_router(task_router, tags=["tasks"])

templates = Jinja2Templates(directory="src/templates")

# v2: 1
# v3: 2
# v4: 4


@app.get("/")
async def list_endpoints(
    request: Request,
    accept: Annotated[str | None, Header()] = None,
):
    endpoints = []

    for route in app.routes:
        if isinstance(route, APIRoute):
            if route.path == "/":
                continue

            endpoints.append(
                {
                    "path": route.path,
                    "methods": ", ".join(route.methods),
                    "name": route.name,
                }
            )

    if accept and "text/html" in accept:
        return templates.TemplateResponse(
            request=request, context={"endpoints": endpoints}, name="index.html"
        )
