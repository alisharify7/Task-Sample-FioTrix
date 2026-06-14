from app.routers.tasks import task_router

urlpatterns = [{"router": task_router, "prefix": "/tasks", "tags": ["tasks"]}]
