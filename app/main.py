from fastapi import FastAPI
from contextlib import asynccontextmanager
from .config import settings
from .routes import router  
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up the application...")
    yield
    logger.info("Shutting down the application...")

app = FastAPI(title=settings.app_name, debug=settings.debug, lifespan=lifespan)
app.include_router(router)

# if __name__ == "__main__":
#     main()
