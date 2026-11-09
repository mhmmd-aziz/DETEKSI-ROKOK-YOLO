import base64
import json
import threading
from pathlib import Path
from django.conf import settings

_vapid_cache = None
_firebase_initialized = False


def get_or_create_vapid_keys():
    """Auto-generate and persist ECDSA P-256 VAPID keys for FCM Web Push (zero manual config)."""
    global _vapid_cache
    if _vapid_cache is not None:
        return _vapid_cache

    key_file = Path(settings.BASE_DIR) / "vapid_keys.json"
    if key_file.exists():
        try:
            data = json.loads(key_file.read_text(encoding="utf-8"))
            if data.get("public_key") and data.get("private_key"):
                _vapid_cache = data
                return _vapid_cache
        except Exception:
            pass

    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives import serialization

    pk = ec.generate_private_key(ec.SECP256R1())
    raw_priv = pk.private_numbers().private_value.to_bytes(32, "big")
    raw_pub = pk.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    b64_priv = base64.urlsafe_b64encode(raw_priv).rstrip(b"=").decode("ascii")
    b64_pub = base64.urlsafe_b64encode(raw_pub).rstrip(b"=").decode("ascii")

    _vapid_cache = {
        "public_key": b64_pub,
        "private_key": b64_priv,
    }
    try:
        key_file.write_text(json.dumps(_vapid_cache, indent=2), encoding="utf-8")
    except Exception:
        pass
    return _vapid_cache


def get_vapid_public_key():
    return get_or_create_vapid_keys()["public_key"]


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
    Send high-priority FCM Web Push notifications (wakes up closed PWA on Android/Desktop)
    via Google FCM (fcm.googleapis.com) using VAPID Web Push, plus Firebase Admin if configured.
    """

    def _worker():
        try:
            from .models import DeviceToken
            from pywebpush import webpush, WebPushException

            vapid_keys = get_or_create_vapid_keys()
            private_key = vapid_keys["private_key"]

            active_devices = list(DeviceToken.objects.filter(is_active=True))
            if not active_devices:
                return

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

            push_payload = json.dumps(
                {
                    "title": title,
                    "body": body,
                    "icon": "/icon-192.png",
                    "badge": "/icon-192.png",
                    "image": snap_url if snap_url else None,
                    "tag": f"smokeguard-push-{inc_id}-{incident_dict.get('frame_number', 0)}",
                    "incident": incident_dict,
                }
            )

            fcm_native_tokens = []

            for dev in active_devices:
                raw_token = (dev.token or "").strip()
                if not raw_token:
                    continue

                # Case 1: Standard FCM / W3C Web Push JSON Subscription (from pushManager.subscribe)
                if raw_token.startswith("{"):
                    try:
                        sub_info = json.loads(raw_token)
                        if "endpoint" in sub_info and "keys" in sub_info:
                            webpush(
                                subscription_info=sub_info,
                                data=push_payload,
                                vapid_private_key=private_key,
                                vapid_claims={"sub": "mailto:security@smokeguard.ai"},
                                headers={
                                    "Urgency": "high",
                                    "TTL": "120",
                                },
                                timeout=8,
                            )
                    except WebPushException as wpe:
                        if wpe.response is not None and wpe.response.status_code in (404, 410):
                            dev.is_active = False
                            dev.save(update_fields=["is_active"])
                        else:
                            print("FCM WebPush notice:", wpe)
                    except Exception as e:
                        print("FCM WebPush send error:", e)
                elif not raw_token.startswith("pwa-usb-"):
                    fcm_native_tokens.append(raw_token)

            # Case 2: Optional Firebase Admin SDK tokens
            if fcm_native_tokens and _init_firebase_if_available():
                from firebase_admin import messaging

                message = messaging.MulticastMessage(
                    notification=messaging.Notification(title=title, body=body),
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            priority="max",
                            default_sound=True,
                            default_vibrate_timings=True,
                        ),
                    ),
                    data={
                        "incident_id": str(inc_id),
                        "camera_name": str(cam_name),
                        "snapshot_url": str(snap_url),
                    },
                    tokens=fcm_native_tokens,
                )
                messaging.send_each_for_multicast(message)
        except Exception as e:
            print("FCM background worker error:", e)

    t = threading.Thread(target=_worker, daemon=True)
    t.start()
