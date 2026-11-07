import csv
import json
import os
from pathlib import Path

import cv2
import numpy as np
from django.conf import settings
from django.http import JsonResponse, StreamingHttpResponse
from django.views.decorators.csrf import csrf_exempt

from .engine import DetectionEngine
from .models import SmokingIncident


def stream_video(request):
    engine = DetectionEngine()
    requested_source = request.GET.get("source")
    response = StreamingHttpResponse(
        engine.generate_mjpeg(requested_source=requested_source),
        content_type="multipart/x-mixed-replace; boundary=frame",
    )
    response["Cache-Control"] = "no-cache, no-store, must-revalidate"
    return response


def get_status(request):
    engine = DetectionEngine()
    data = engine.get_status_dict()
    total_incidents = SmokingIncident.objects.count()
    data["total_incidents"] = total_incidents
    return JsonResponse(data)


@csrf_exempt
def update_config(request):
    if request.method != "POST":
        return JsonResponse({"error": "Method not allowed"}, status=405)

    engine = DetectionEngine()
    try:
        body = json.loads(request.body.decode("utf-8"))
    except Exception:
        body = {}

    if body.get("stop_stream"):
        engine.stop_active_stream()
        return JsonResponse({"ok": True, "config": engine.get_status_dict()})

    if "two_stage" in body:
        engine.two_stage = bool(body["two_stage"])
    if "show_person_box" in body:
        engine.show_person_box = bool(body["show_person_box"])
    if "conf_threshold" in body:
        engine.conf_threshold = max(0.15, min(0.90, float(body["conf_threshold"])))
    if "min_consecutive_frames" in body:
        engine.min_consecutive_frames = max(3, min(40, int(body["min_consecutive_frames"])))
    if "source_mode" in body and body["source_mode"] in ["cctv_demo", "webcam", "custom_video"]:
        engine.set_source_mode(body["source_mode"])
    if "paused" in body:
        engine.paused = bool(body["paused"])

    return JsonResponse({"ok": True, "config": engine.get_status_dict()})


@csrf_exempt
def incidents_view(request):
    if request.method == "DELETE":
        for inc in SmokingIncident.objects.all():
            if inc.snapshot_url:
                fname = Path(inc.snapshot_url).name
                fpath = Path(settings.MEDIA_ROOT) / "snapshots" / fname
                if fpath.exists():
                    try:
                        fpath.unlink()
                    except Exception:
                        pass
        SmokingIncident.objects.all().delete()
        return JsonResponse({"ok": True, "incidents": []})

    limit = int(request.GET.get("limit", 24))
    items = [inc.to_dict() for inc in SmokingIncident.objects.all()[:limit]]
    return JsonResponse({"incidents": items, "total": SmokingIncident.objects.count()})


@csrf_exempt
def manual_capture(request):
    if request.method != "POST":
        return JsonResponse({"error": "Method not allowed"}, status=405)

    engine = DetectionEngine()
    if engine.last_jpeg is None:
        return JsonResponse({"error": "Stream belum aktif"}, status=400)

    arr = np.frombuffer(engine.last_jpeg, dtype=np.uint8)
    frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if frame is not None:
        engine._save_incident_snapshot(frame, engine.current_frame_idx)

    latest = SmokingIncident.objects.first()
    return JsonResponse({"ok": True, "incident": latest.to_dict() if latest else None})


@csrf_exempt
def upload_video(request):
    if request.method != "POST" or "video" not in request.FILES:
        return JsonResponse({"error": "Pilih file video (.mp4/.avi)"}, status=400)

    video_file = request.FILES["video"]
    upload_dir = Path(settings.MEDIA_ROOT) / "uploads"
    os.makedirs(upload_dir, exist_ok=True)
    save_path = upload_dir / video_file.name

    with open(save_path, "wb+") as dest:
        for chunk in video_file.chunks():
            dest.write(chunk)

    engine = DetectionEngine()
    engine.custom_video_path = str(save_path)
    engine.custom_video_name = video_file.name[:24]
    engine.set_source_mode("custom_video")

    return JsonResponse({"ok": True, "config": engine.get_status_dict()})


def get_model_metrics(request):
    project_root = Path(settings.PROJECT_ROOT)
    csv_path = project_root / "runs" / "detect" / "train4" / "results.csv"
    epochs = []

    if csv_path.exists():
        with open(csv_path, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                cleaned = {k.strip(): v.strip() for k, v in row.items() if k}
                try:
                    epochs.append(
                        {
                            "epoch": int(float(cleaned.get("epoch", 0))),
                            "box_loss": round(float(cleaned.get("train/box_loss", 0)), 4),
                            "cls_loss": round(float(cleaned.get("train/cls_loss", 0)), 4),
                            "val_box_loss": round(float(cleaned.get("val/box_loss", 0)), 4),
                            "precision": round(float(cleaned.get("metrics/precision(B)", 0)) * 100, 2),
                            "recall": round(float(cleaned.get("metrics/recall(B)", 0)) * 100, 2),
                            "map50": round(float(cleaned.get("metrics/mAP50(B)", 0)) * 100, 2),
                            "map50_95": round(float(cleaned.get("metrics/mAP50-95(B)", 0)) * 100, 2),
                        }
                    )
                except Exception:
                    continue

    summary = {
        "model_architecture": "YOLOv8n Two-Stage (Person ROI + Cigarette Detector)",
        "dataset_train_images": 6068,
        "dataset_val_images": 1726,
        "dataset_test_images": 872,
        "total_epochs": 50,
        "val_map50": 94.7,
        "val_map50_95": 72.1,
        "val_precision": 93.8,
        "val_recall": 89.3,
        "test_map50": 94.2,
        "test_map50_95": 70.9,
        "test_precision": 92.9,
        "test_recall": 88.4,
        "epochs": epochs,
    }
    return JsonResponse(summary)
