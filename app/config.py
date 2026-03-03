from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    """Application settings."""

    app_name: str = "My FastAPI Application"
    debug: bool = False
    # database_url: str = "sqlite:///./test.db"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
    
settings = Settings()
