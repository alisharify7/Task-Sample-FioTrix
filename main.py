import uvicorn

from app import create_app
from app.config import get_config

app = create_app(config_class=get_config())

if __name__ == "__main__":
    uvicorn.run("main:app", reload=True, workers=2, port=8000)
