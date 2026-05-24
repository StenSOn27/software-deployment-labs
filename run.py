#!/usr/bin/env python3
"""
Database migration and app startup script.
Runs migrations and optionally starts the FastAPI app.

Usage:
    python run.py              # Run migrations and start app
    python run.py migrate-only # Run migrations only (for systemd)
    python run.py start-only   # Start app without migrations
"""
import asyncio
import subprocess
import sys
import os
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

async def run_migrations():
    """Run database migrations using Alembic."""
    print("Running database migrations...")
    result = subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("Migration failed:")
        print(result.stderr)
        return False

    print("Migrations completed successfully")
    print(result.stdout)
    return True

async def start_app():
    """Start FastAPI app with uvicorn."""
    from src.config import service_settings

    print(f"Starting FastAPI app on {service_settings.HOST}:{service_settings.PORT}")
    os.execvp(sys.executable, [
        sys.executable, "-m", "uvicorn",
        "src.main:app",
        "--host", service_settings.HOST,
        "--port", str(service_settings.PORT),
        "--workers", "1"
    ])

async def main():
    """Main entry point."""
    mode = sys.argv[1] if len(sys.argv) > 1 else "default"

    if mode == "migrate-only":
        # Only run migrations (used by systemd ExecStartPre)
        if not await run_migrations():
            sys.exit(1)
    elif mode == "start-only":
        # Only start app (skip migrations)
        await start_app()
    else:
        # Default: run migrations then start app
        if not await run_migrations():
            sys.exit(1)
        await start_app()

if __name__ == "__main__":
    asyncio.run(main())
