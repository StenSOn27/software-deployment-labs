from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from src.database.engine import db_helper

router = APIRouter(prefix="/health")


@router.get("/alive")
async def get_alive():
    return HTTPException(status_code=200, detail="alive")


@router.get("/ready")
async def root(db_session: AsyncSession = Depends(db_helper.get_db_session)):

    try:
        await db_session.execute(text("SELECT 1;"))
        return HTTPException(status_code=200, detail="ready")
    except Exception as e:
        return HTTPException(status_code=500, detail=f"Database connection error: {e}")
