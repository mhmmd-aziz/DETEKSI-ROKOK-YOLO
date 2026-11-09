import os
import threading
from pathlib import Path
from django.conf import settings

_firebase_initialized = False


def _init_firebase_if_available():
    global _firebase_initialized
    if _firebase_initialized:
        return True

    cred_path = Path(settings.BASE_DIR) / "serviceAccountKey.json"
    if not cred_path.exists():
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            cred = credentials.Certificate(str(cred_path))
            firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        return True
    except Exception as e:
        print("Firebase Admin init notice:", e)
        return False


def dispatch_fcm_background(incident_dict):
    """Send FCM multicast push in a background thread if serviceAccountKey.json is configured."""

    def _worker():
        try:
            from .models import DeviceToken

            tokens = list(
                DeviceToken.objects.filter(is_active=True).values_list("token", flat=True)
            )
            if not tokens:
                return

            # Filter only real FCM tokens if Firebase Admin is configured
            fcm_tokens = [t for t in tokens if not t.startswith("local-pwa-")]
            if not fcm_tokens or not _init_firebase_if_available():
                return

            from firebase_admin import messaging

            title = f"PERINGATAN KTR: {incident_dict['cigarette_count']} Rokok Terdeteksi"
            body = (
                f"{incident_dict['camera_name']} • Conf {int(round(incident_dict['max_confidence'] * 100))}% "
                f"({incident_dict['timestamp']})"
            )

            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={
                    "incident_id": str(incident_dict.get("id", "")),
                    "camera_name": str(incident_dict.get("camera_name", "")),
                    "snapshot_url": str(incident_dict.get("snapshot_url", "")),
                    "timestamp": str(incident_dict.get("timestamp", "")),
                },
                tokens=fcm_tokens,
            )
            messaging.send_each_for_multicast(message)
        except Exception as e:
            print("FCM background send notice:", e)

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
