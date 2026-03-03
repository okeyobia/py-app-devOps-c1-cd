from datetime import date
import socket

from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def root():    
    return {"message": "FastAPI running with uv 🚀"}

@router.get("/health")
async def health_check():
    return {"status": "healthy"}

@router.get("/api/v1/details")
async def get_details():
    return {"time": date.today().isoformat(), "hostname": socket.gethostname()}