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
    """
    Send high-priority Native FCM Push Notification to Flutter Android/iOS devices
    when serviceAccountKey.json is present.
    Uses Android Notification Channel 'smokeguard_high_importance' (MAX importance)
    so notifications pop up as a Heads-Up Banner at the top of the phone screen
    even when the Flutter app is closed.
    """

    def _worker():
        try:
            from .models import DeviceToken

            tokens = [
                t.strip()
                for t in DeviceToken.objects.filter(is_active=True).values_list("token", flat=True)
                if t and not t.startswith("{") and not t.startswith("pwa-")
            ]
            if not tokens or not _init_firebase_if_available():
                return

            from firebase_admin import messaging

            cig_count = incident_dict.get("cigarette_count", 1)
            person_count = incident_dict.get("person_count", 1)
            conf_pct = int(round(float(incident_dict.get("max_confidence", 0.85)) * 100))
            cam_name = incident_dict.get("camera_name", "CAM 01")
            loc_name = incident_dict.get("location", "Kawasan Tanpa Rokok")
            snap_url = incident_dict.get("snapshot_url", "")
            inc_id = incident_dict.get("id", 0)

            title = f"PERINGATAN KTR • {cam_name}"
            body = (
                f"Terdeteksi {cig_count} titik rokok ({person_count} orang) di {loc_name} • "
                f"Confidence {conf_pct}%"
            )

            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="smokeguard_kritikal_v2",
                        icon="ic_stat_smokeguard",
                        color="#059669",
                        priority="max",
                        default_sound=True,
                        default_vibrate_timings=True,
                        visibility="public",
                    ),
                ),
                data={
                    "incident_id": str(inc_id),
                    "camera_name": str(cam_name),
                    "location": str(loc_name),
                    "cigarette_count": str(cig_count),
                    "person_count": str(person_count),
                    "max_confidence": str(incident_dict.get("max_confidence", 0.85)),
                    "snapshot_url": str(snap_url),
                    "timestamp": str(incident_dict.get("timestamp", "")),
                },
                tokens=tokens,
            )
            messaging.send_each_for_multicast(message)
        except Exception as e:
            print("FCM Flutter push notice:", e)

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
