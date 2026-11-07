import os
import time
import threading
from datetime import datetime
from pathlib import Path

import cv2
import torch
import torchvision
from django.conf import settings
from ultralytics import YOLO


class DetectionEngine:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance._initialized = False
            return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True

        project_root = Path(settings.PROJECT_ROOT)
        self.person_model_path = str(project_root / "yolov8n.pt")
        self.smoke_model_path = str(project_root / "runs" / "detect" / "train4" / "weights" / "best.pt")

        self.device = 0 if torch.cuda.is_available() else "cpu"
        self.device_name = (
            torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
        )

        self.person_model = YOLO(self.person_model_path)
        self.smoke_model = YOLO(self.smoke_model_path)

        # Default video source
        default_video = Path("D:/semester 5/PRAK PCD/Young_men_smoking_indoors_27ce285e.mp4")
        if not default_video.exists():
            alt_video = project_root / "runs" / "detect" / "predict_two_stage" / "Young_men_smoking_indoors_two_stage.mp4"
            default_video = alt_video

        self.default_video_path = str(default_video)
        self.custom_video_path = None
        self.custom_video_name = "Video Upload"

        # Runtime configuration
        self.source_mode = "cctv_demo"  # 'cctv_demo' | 'webcam' | 'custom_video'
        self.camera_name = "CAM 01 - CCTV Indoor (Demo)"
        self.location = "Gedung Utama Lt. 1 (Kawasan Tanpa Rokok)"
        self.two_stage = True
        self.show_person_box = True
        self.conf_threshold = 0.45
        self.person_conf = 0.35
        self.paused = False

        # Stream lifecycle management (ensures old streams & webcam close immediately)
        self.active_stream_id = 0
        self.stream_active = True

        # Live telemetry state
        self.current_frame_idx = 0
        self.total_frames = 240
        self.person_count = 0
        self.smoker_count = 0
        self.cigarette_count = 0
        self.max_confidence = 0.0
        self.fps = 0.0
        self.inference_ms = 0.0
        self.status = "AMAN"  # 'AMAN' | 'PELANGGARAN MEROKOK'
        self.last_incident_time = 0.0
        self.incident_cooldown = 4.5
        self.last_raw_frame = None
        self.last_jpeg = None
        self.last_config_signature = None

        os.makedirs(Path(settings.MEDIA_ROOT) / "snapshots", exist_ok=True)
        os.makedirs(Path(settings.MEDIA_ROOT) / "uploads", exist_ok=True)

    def invalidate_streams(self):
        """Increment stream_id so any running generator loop exits and releases camera immediately."""
        self.active_stream_id += 1

    def set_source_mode(self, mode: str):
        if mode not in ("cctv_demo", "webcam", "custom_video"):
            return
        if self.source_mode != mode:
            self.source_mode = mode
            self.paused = False
            self.invalidate_streams()
        if mode == "webcam":
            self.camera_name = "CAM 02 - Live Kamera Webcam"
        elif mode == "custom_video":
            self.camera_name = f"CAM 03 - {self.custom_video_name}"
        else:
            self.camera_name = "CAM 01 - CCTV Indoor (Demo)"

    def get_video_source(self):
        if self.source_mode == "webcam":
            return 0
        if self.source_mode == "custom_video" and self.custom_video_path and os.path.exists(self.custom_video_path):
            return self.custom_video_path
        return self.default_video_path

    def process_frame(self, frame, frame_idx=0, allow_snapshot=True):
        t0 = time.perf_counter()
        H, W = frame.shape[:2]
        vis = frame.copy()
        active_conf = float(self.conf_threshold)

        final_cigs = []
        final_scores = []
        p_boxes = []
        smoker_indices = set()

        if self.two_stage:
            # Stage 1: Person detection
            p_res = self.person_model(
                frame, classes=[0], conf=self.person_conf, device=self.device, verbose=False
            )[0]
            p_boxes = p_res.boxes.xyxy.cpu().numpy().astype(int)

            all_cigs = []
            all_scores = []

            # Stage 2: Upper-body + hands crop per person
            # Use base conf=0.15 and filter strictly by active_conf so threshold slider works across full range
            base_conf = min(0.15, active_conf)
            for (x1, y1, x2, y2) in p_boxes:
                pw, ph = x2 - x1, y2 - y1
                cx1 = max(0, x1 - int(pw * 0.12))
                cy1 = max(0, y1 - int(ph * 0.05))
                cx2 = min(W, x2 + int(pw * 0.12))
                cy2 = min(H, y1 + int(ph * 0.72))
                crop = frame[cy1:cy2, cx1:cx2]
                if crop.size == 0:
                    continue

                s_res = self.smoke_model(
                    crop, imgsz=640, conf=base_conf, device=self.device, verbose=False
                )[0]
                for box in s_res.boxes:
                    conf = float(box.conf[0].cpu().numpy())
                    if conf < active_conf:
                        continue
                    bx1, by1, bx2, by2 = box.xyxy[0].cpu().numpy()
                    bw, bh = bx2 - bx1, by2 - by1

                    # Filter out oversized false positives (e.g. pillars/walls)
                    if bw > pw * 0.45 or bh > ph * 0.35:
                        continue

                    gx1, gy1, gx2, gy2 = cx1 + bx1, cy1 + by1, cx1 + bx2, cy1 + by2
                    all_cigs.append([gx1, gy1, gx2, gy2])
                    all_scores.append(conf)

            if len(all_cigs) > 0:
                boxes_t = torch.tensor(all_cigs, dtype=torch.float32)
                scores_t = torch.tensor(all_scores, dtype=torch.float32)
                keep = torchvision.ops.nms(boxes_t, scores_t, iou_threshold=0.4)
                final_cigs = boxes_t[keep].numpy().astype(int)
                final_scores = scores_t[keep].numpy()

            # Match each detected cigarette to the closest person containing its center
            for (gx1, gy1, gx2, gy2) in final_cigs:
                ccx, ccy = (gx1 + gx2) / 2.0, (gy1 + gy2) / 2.0
                best_p = None
                best_dist = 1e9
                for idx, (px1, py1, px2, py2) in enumerate(p_boxes):
                    pw, ph = px2 - px1, py2 - py1
                    if (px1 - pw * 0.15) <= ccx <= (px2 + pw * 0.15) and (py1 - ph * 0.05) <= ccy <= (py2 + ph * 0.1):
                        pcx, pcy = (px1 + px2) / 2.0, (py1 + py2) / 2.0
                        dist = abs(ccx - pcx) + abs(ccy - pcy)
                        if dist < best_dist:
                            best_dist = dist
                            best_p = idx
                if best_p is not None:
                    smoker_indices.add(best_p)

        else:
            # Single-stage mode (Standard YOLO directly on full frame)
            s_res = self.smoke_model(
                frame, imgsz=640, conf=active_conf, device=self.device, verbose=False
            )[0]
            if len(s_res.boxes) > 0:
                final_cigs = s_res.boxes.xyxy.cpu().numpy().astype(int)
                final_scores = s_res.boxes.conf.cpu().numpy()

        # Draw person bounding boxes if enabled
        if self.two_stage and self.show_person_box:
            for idx, (px1, py1, px2, py2) in enumerate(p_boxes):
                is_smoking = idx in smoker_indices
                if is_smoking:
                    color = (59, 59, 239)  # BGR Red
                    cv2.rectangle(vis, (px1, py1), (px2, py2), color, 2)
                    p_label = "MEROKOK"
                    (tw, th), _ = cv2.getTextSize(p_label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)
                    cv2.rectangle(vis, (px1, py1 - th - 8), (px1 + tw + 8, py1), color, -1)
                    cv2.putText(
                        vis, p_label, (px1 + 4, py1 - 4),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2
                    )
                else:
                    color = (129, 185, 16)  # BGR Emerald Green
                    cv2.rectangle(vis, (px1, py1), (px2, py2), color, 1)
                    p_label = "AMAN"
                    (tw, th), _ = cv2.getTextSize(p_label, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
                    cv2.rectangle(vis, (px1, py1 - th - 6), (px1 + tw + 6, py1), color, -1)
                    cv2.putText(
                        vis, p_label, (px1 + 3, py1 - 3),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1
                    )

        # Draw cigarette bounding boxes
        for (gx1, gy1, gx2, gy2), conf in zip(final_cigs, final_scores):
            c_color = (38, 38, 220) if self.two_stage else (255, 100, 0)
            cv2.rectangle(vis, (gx1, gy1), (gx2, gy2), c_color, 2)
            label = f"Rokok {conf:.2f}"
            (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 2)
            cv2.rectangle(vis, (gx1, max(0, gy1 - th - 6)), (gx1 + tw + 6, gy1), c_color, -1)
            cv2.putText(
                vis, label, (gx1 + 3, max(12, gy1 - 4)),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2
            )

        # Draw subtle bottom-left status HUD showing active Confidence Threshold
        hud_text = f"Conf Threshold: {int(round(active_conf * 100))}% | Deteksi: {len(final_cigs)} Rokok"
        (htw, hth), _ = cv2.getTextSize(hud_text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(vis, (14, H - hth - 22), (26 + htw, H - 10), (18, 42, 30), -1)
        cv2.putText(
            vis, hud_text, (20, H - 15),
            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1
        )

        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        self.inference_ms = round(elapsed_ms, 1)
        self.fps = round(1000.0 / max(elapsed_ms, 1.0), 1)
        self.current_frame_idx = frame_idx
        self.person_count = len(p_boxes) if self.two_stage else 0
        self.cigarette_count = len(final_cigs)
        self.smoker_count = len(smoker_indices) if self.two_stage else (1 if len(final_cigs) > 0 else 0)
        self.max_confidence = float(max(final_scores)) if len(final_scores) > 0 else 0.0
        self.status = "PELANGGARAN MEROKOK" if len(final_cigs) > 0 else "AMAN"

        now = time.time()
        if allow_snapshot and len(final_cigs) > 0 and (now - self.last_incident_time) >= self.incident_cooldown:
            self.last_incident_time = now
            self._save_incident_snapshot(vis, frame_idx)

        return vis

    def _save_incident_snapshot(self, vis_frame, frame_idx):
        try:
            from .models import SmokingIncident

            ts_str = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:18]
            filename = f"incident_{ts_str}_f{frame_idx}.jpg"
            rel_url = f"/media/snapshots/{filename}"
            full_path = Path(settings.MEDIA_ROOT) / "snapshots" / filename
            cv2.imwrite(str(full_path), vis_frame)

            SmokingIncident.objects.create(
                camera_name=self.camera_name,
                location=self.location,
                frame_number=frame_idx,
                person_count=self.person_count,
                smoker_count=max(1, self.smoker_count),
                cigarette_count=self.cigarette_count,
                max_confidence=self.max_confidence,
                detection_mode="Two-Stage YOLOv8" if self.two_stage else "Single-Stage YOLOv8",
                snapshot_url=rel_url,
            )
        except Exception as e:
            print("Snapshot save error:", e)

    def seed_initial_incidents_if_empty(self):
        from .models import SmokingIncident

        if SmokingIncident.objects.count() > 0:
            return
        if not os.path.exists(self.default_video_path):
            return

        cap = cv2.VideoCapture(self.default_video_path)
        for f_no in [20, 80, 140, 200]:
            cap.set(cv2.CAP_PROP_POS_FRAMES, f_no)
            ret, frame = cap.read()
            if ret and frame is not None:
                vis = self.process_frame(frame, frame_idx=f_no, allow_snapshot=False)
                if self.cigarette_count > 0:
                    self._save_incident_snapshot(vis, f_no)
        cap.release()

    def generate_mjpeg(self, requested_source=None):
        if requested_source in ("cctv_demo", "webcam", "custom_video"):
            self.set_source_mode(requested_source)

        self.stream_active = True
        self.active_stream_id += 1
        my_stream_id = self.active_stream_id

        source = self.get_video_source()
        if source == 0:
            cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
        else:
            cap = cv2.VideoCapture(source)

        self.total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) if source != 0 else 0
        frame_idx = 0

        try:
            while self.stream_active and self.active_stream_id == my_stream_id:
                cfg_sig = (round(self.conf_threshold, 3), self.two_stage, self.show_person_box)

                if self.paused and self.last_raw_frame is not None:
                    # If user changes threshold or toggles while paused, re-process the paused frame live!
                    if cfg_sig != self.last_config_signature or self.last_jpeg is None:
                        vis = self.process_frame(
                            self.last_raw_frame, frame_idx=frame_idx, allow_snapshot=False
                        )
                        ok, buffer = cv2.imencode(".jpg", vis, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                        if ok:
                            self.last_jpeg = buffer.tobytes()
                            self.last_config_signature = cfg_sig
                    if self.last_jpeg is not None:
                        yield (
                            b"--frame\r\n"
                            b"Content-Type: image/jpeg\r\n\r\n" + self.last_jpeg + b"\r\n"
                        )
                    time.sleep(0.08)
                    continue

                ret, frame = cap.read()
                if not ret or frame is None:
                    if source == 0:
                        time.sleep(0.1)
                        continue
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    frame_idx = 0
                    ret, frame = cap.read()
                    if not ret or frame is None:
                        time.sleep(0.2)
                        continue

                frame_idx += 1
                self.last_raw_frame = frame.copy()
                vis = self.process_frame(frame, frame_idx=frame_idx, allow_snapshot=True)
                ok, buffer = cv2.imencode(".jpg", vis, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                if not ok:
                    continue

                jpeg_bytes = buffer.tobytes()
                self.last_jpeg = jpeg_bytes
                self.last_config_signature = cfg_sig
                yield (
                    b"--frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n" + jpeg_bytes + b"\r\n"
                )
        finally:
            cap.release()

    def stop_active_stream(self):
        """Immediately stop any running stream and release camera hardware."""
        self.stream_active = False
        self.invalidate_streams()

    def get_status_dict(self):
        return {
            "camera_name": self.camera_name,
            "location": self.location,
            "source_mode": self.source_mode,
            "two_stage": self.two_stage,
            "show_person_box": self.show_person_box,
            "conf_threshold": round(self.conf_threshold, 2),
            "paused": self.paused,
            "current_frame": self.current_frame_idx,
            "total_frames": self.total_frames,
            "person_count": self.person_count,
            "smoker_count": self.smoker_count,
            "cigarette_count": self.cigarette_count,
            "max_confidence": round(self.max_confidence, 3),
            "fps": self.fps,
            "inference_ms": self.inference_ms,
            "status": self.status,
            "device_name": self.device_name,
        }
