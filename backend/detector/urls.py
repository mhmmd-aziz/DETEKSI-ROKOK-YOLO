from django.urls import path
from . import views

urlpatterns = [
    path("stream/", views.stream_video, name="stream_video"),
    path("status/", views.get_status, name="get_status"),
    path("config/", views.update_config, name="update_config"),
    path("incidents/", views.incidents_view, name="incidents_view"),
    path("capture/", views.manual_capture, name="manual_capture"),
    path("upload/", views.upload_video, name="upload_video"),
    path("model-metrics/", views.get_model_metrics, name="get_model_metrics"),
    path("notifications/register/", views.register_notification_device, name="register_notification_device"),
    path("notifications/test/", views.test_notification, name="test_notification"),
]
