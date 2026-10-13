from django.apps import AppConfig


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        # Several viewsets declare a module-level `queryset = Model.objects.all()`. If the
        # URLconf (and so api.views) were first imported lazily inside a request, that
        # queryset would be frozen to whichever tenant the middleware had active, e.g.
        # the sole shop assumed for the platform health check, and every other shop
        # would then see empty lists. Import it now, while no tenant is active.
        from . import views  # noqa: F401
