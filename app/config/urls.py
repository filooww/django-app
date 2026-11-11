from django.urls import path

from core import views

urlpatterns = [
    path("", views.index),
    path("healthz", views.healthz),
    path("readyz", views.readyz),
]
