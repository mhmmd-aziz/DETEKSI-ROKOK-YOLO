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


class CameraChannel:
    """Represents a single video/camera stream state (e.g., CCTV A, CCTV B, Webcam, Upload)."""

    def __init__(self, key: str, camera_name: str, location: str, source):
        self.key = key
        self.camera_name = camera_name
        self.location = location
        self.source = source  # file path (str) or 0 for webcam

        self.active_stream_id = 0
        self.producer_running = False
        self.producer_lock = threading.Lock()
        self.frame_seq = 0

        self.current_frame_idx = 0
        self.total_frames = 0
        self.width = 1280
        self.height = 720
        self.person_count = 0
        self.smoker_count = 0
        self.cigarette_count = 0
        self.consecutive_hits = 0
        self.max_confidence = 0.0
        self.fps = 0.0
        self.inference_ms = 0.0
        self.status = "AMAN"
        self.last_incident_time = 0.0
        self.last_raw_frame = None
        self.last_jpeg = None
        self.last_config_signature = None

    def to_status_dict(self, min_consecutive_frames: int):
        return {
            "key": self.key,
            "camera_name": self.camera_name,
            "location": self.location,
            "current_frame": self.current_frame_idx,
            "total_frames": self.total_frames,
            "resolution": f"{self.width}x{self.height}",
            "person_count": self.person_count,
            "smoker_count": self.smoker_count,
            "cigarette_count": self.cigarette_count,
            "consecutive_hits": min(self.consecutive_hits, min_consecutive_frames),
            "max_confidence": round(self.max_confidence, 3),
            "fps": self.fps,
            "inference_ms": self.inference_ms,
            "status": self.status,
        }


class DetectionEngine:
    _instance = None
    _lock = threading.Lock()

    VALID_MODES = ("dual_cctv", "cctv_a", "cctv_b", "cctv_demo", "webcam", "custom_video")

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
        self.infer_lock = threading.Lock()

        video_a = Path(settings.MEDIA_ROOT) / "demo" / "test3.mp4"
        if not video_a.exists():
            video_a = Path("D:/semester 5/PRAK PCD/Young_men_smoking_indoors_27ce285e.mp4")
        if not video_a.exists():
            video_a = project_root / "runs" / "detect" / "predict_two_stage" / "Young_men_smoking_indoors_two_stage.mp4"

        video_b = Path(settings.MEDIA_ROOT) / "demo" / "cctv_b.mp4"
        if not video_b.exists():
            video_b = video_a

        self.video_a_path = str(video_a)
        self.video_b_path = str(video_b)
        self.custom_video_path = None
        self.custom_video_name = "Video Upload"

        self.channels = {
            "cctv_a": CameraChannel(
                key="cctv_a",
                camera_name="CCTV A - Koridor Indoor",
                location="Gedung Utama Lt. 1 (Indoor KTR)",
                source=self.video_a_path,
            ),
            "cctv_b": CameraChannel(
                key="cctv_b",
                camera_name="CCTV B - Selasar & Parkiran",
                location="Selasar & Area Parkir Kampus (Outdoor KTR)",
                source=self.video_b_path,
            ),
            "custom_video": CameraChannel(
                key="custom_video",
                camera_name="CCTV Upload - Video Uji",
                location="Pengujian File Video (KTR)",
                source=self.video_a_path,
            ),
            "webcam": CameraChannel(
                key="webcam",
                camera_name="Kamera Webcam Live",
                location="Kamera Lokal Perangkat (KTR)",
                source=0,
            ),
        }

        # Global detection parameters
        self.source_mode = "dual_cctv"
        self.two_stage = True
        self.show_person_box = True
        self.conf_threshold = 0.45
        self.person_conf = 0.35
        self.paused = False

        # Temporal Persistence Filter (Anti-False Positive 1-Frame Glitch)
        self.min_consecutive_frames = 12
        self.incident_cooldown = 8.0

        self.stream_active = True
        self.test_alert_seq = 0
        self.last_test_alert_payload = None

        os.makedirs(Path(settings.MEDIA_ROOT) / "snapshots", exist_ok=True)
        os.makedirs(Path(settings.MEDIA_ROOT) / "uploads", exist_ok=True)
        self._sync_producers_for_mode()

    def normalize_cam_key(self, raw_key: str | None) -> str:
        if not raw_key or raw_key == "cctv_demo":
            return "cctv_a"
        if raw_key in self.channels:
            return raw_key
        return "cctv_a"

    def active_channel_keys(self) -> list[str]:
        if self.source_mode == "dual_cctv":
            return ["cctv_a", "cctv_b"]
        if self.source_mode in ("cctv_a", "cctv_demo"):
            return ["cctv_a"]
        if self.source_mode == "cctv_b":
            return ["cctv_b"]
        if self.source_mode == "custom_video":
            return ["custom_video"]
        if self.source_mode == "webcam":
            return ["webcam"]
        return ["cctv_a", "cctv_b"]

    def primary_channel(self) -> CameraChannel:
        keys = self.active_channel_keys()
        if len(keys) == 2:
            ch_a = self.channels["cctv_a"]
            ch_b = self.channels["cctv_b"]
            if ch_b.status == "PELANGGARAN MEROKOK" and ch_a.status != "PELANGGARAN MEROKOK":
                return ch_b
            return ch_a
        return self.channels[keys[0]]

    def _stop_channel(self, ch: CameraChannel):
        with ch.producer_lock:
            ch.active_stream_id += 1
            ch.producer_running = False
            ch.consecutive_hits = 0

    def _ensure_channel_running(self, ch: CameraChannel):
        with ch.producer_lock:
            if not ch.producer_running:
                self.stream_active = True
                ch.active_stream_id += 1
                my_id = ch.active_stream_id
                ch.consecutive_hits = 0
                ch.producer_running = True
                t = threading.Thread(
                    target=self._producer_loop,
                    args=(ch, my_id),
                    daemon=True,
                )
                t.start()

    def _sync_producers_for_mode(self):
        wanted = set(self.active_channel_keys())
        for key, ch in self.channels.items():
            if key not in wanted:
                self._stop_channel(ch)
        for key in wanted:
            if key != "webcam":
                self._ensure_channel_running(self.channels[key])

    def set_source_mode(self, mode: str):
        if mode not in self.VALID_MODES:
            return
        normalized = "cctv_a" if mode == "cctv_demo" else mode
        if self.source_mode != normalized:
            self.source_mode = normalized
            self.paused = False
            if normalized == "custom_video" and self.custom_video_path:
                self.channels["custom_video"].source = self.custom_video_path
                self.channels["custom_video"].camera_name = f"CCTV Upload - {self.custom_video_name}"
            self._sync_producers_for_mode()
            if normalized == "webcam":
                self._ensure_channel_running(self.channels["webcam"])

    def stop_active_stream(self):
        self.stream_active = False
        for ch in self.channels.values():
            self._stop_channel(ch)

    def process_frame_for_channel(self, ch: CameraChannel, frame, frame_idx=0, allow_snapshot=True):
        t0 = time.perf_counter()
        H, W = frame.shape[:2]
        ch.width, ch.height = W, H
        vis = frame.copy()
        active_conf = float(self.conf_threshold)

        final_cigs = []
        final_scores = []
        p_boxes = []
        smoker_indices = set()

        if self.two_stage:
            with self.infer_lock:
                p_res = self.person_model(
                    frame, classes=[0], conf=self.person_conf, device=self.device, verbose=False
                )[0]
            p_boxes = p_res.boxes.xyxy.cpu().numpy().astype(int)

            all_cigs = []
            all_scores = []

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

                with self.infer_lock:
                    s_res = self.smoke_model(
                        crop, imgsz=640, conf=base_conf, device=self.device, verbose=False
                    )[0]
                for box in s_res.boxes:
                    conf = float(box.conf[0].cpu().numpy())
                    if conf < active_conf:
                        continue
                    bx1, by1, bx2, by2 = box.xyxy[0].cpu().numpy()
                    bw, bh = bx2 - bx1, by2 - by1

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
            with self.infer_lock:
                s_res = self.smoke_model(
                    frame, imgsz=640, conf=active_conf, device=self.device, verbose=False
                )[0]
            if len(s_res.boxes) > 0:
                final_cigs = s_res.boxes.xyxy.cpu().numpy().astype(int)
                final_scores = s_res.boxes.conf.cpu().numpy()

        if allow_snapshot:
            if len(final_cigs) > 0:
                ch.consecutive_hits = min(self.min_consecutive_frames + 5, ch.consecutive_hits + 1)
            else:
                ch.consecutive_hits = max(0, ch.consecutive_hits - 3)

        is_confirmed = (len(final_cigs) > 0) and (ch.consecutive_hits >= self.min_consecutive_frames)

        if self.two_stage and self.show_person_box:
            for idx, (px1, py1, px2, py2) in enumerate(p_boxes):
                has_cig = idx in smoker_indices
                if has_cig and is_confirmed:
                    color = (59, 59, 239)
                    cv2.rectangle(vis, (px1, py1), (px2, py2), color, 2)
                    p_label = "MEROKOK"
                    (tw, th), _ = cv2.getTextSize(p_label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 2)
                    cv2.rectangle(vis, (px1, py1 - th - 8), (px1 + tw + 8, py1), color, -1)
                    cv2.putText(
                        vis, p_label, (px1 + 4, py1 - 4),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2
                    )
                elif has_cig and not is_confirmed:
                    color = (11, 158, 245)
                    cv2.rectangle(vis, (px1, py1), (px2, py2), color, 2)
                    p_label = f"VERIFIKASI ({ch.consecutive_hits}/{self.min_consecutive_frames})"
                    (tw, th), _ = cv2.getTextSize(p_label, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 2)
                    cv2.rectangle(vis, (px1, py1 - th - 8), (px1 + tw + 8, py1), color, -1)
                    cv2.putText(
                        vis, p_label, (px1 + 4, py1 - 4),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 2
                    )
                else:
                    color = (129, 185, 16)
                    cv2.rectangle(vis, (px1, py1), (px2, py2), color, 1)
                    p_label = "AMAN"
                    (tw, th), _ = cv2.getTextSize(p_label, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
                    cv2.rectangle(vis, (px1, py1 - th - 6), (px1 + tw + 6, py1), color, -1)
                    cv2.putText(
                        vis, p_label, (px1 + 3, py1 - 3),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1
                    )

        for (gx1, gy1, gx2, gy2), conf in zip(final_cigs, final_scores):
            c_color = (38, 38, 220) if is_confirmed else (11, 158, 245)
            cv2.rectangle(vis, (gx1, gy1), (gx2, gy2), c_color, 2)
            label = f"Rokok {conf:.2f}"
            (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 2)
            cv2.rectangle(vis, (gx1, max(0, gy1 - th - 6)), (gx1 + tw + 6, gy1), c_color, -1)
            cv2.putText(
                vis, label, (gx1 + 3, max(12, gy1 - 4)),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2
            )

        ver_str = (
            "TERKONFIRMASI"
            if is_confirmed
            else f"Verifikasi {min(ch.consecutive_hits, self.min_consecutive_frames)}/{self.min_consecutive_frames} Frame"
        )
        hud_text = f"{ch.camera_name.split(' - ')[0]} | Conf: {int(round(active_conf * 100))}% | {ver_str}"
        (htw, hth), _ = cv2.getTextSize(hud_text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(vis, (14, H - hth - 22), (26 + htw, H - 10), (18, 42, 30), -1)
        cv2.putText(
            vis, hud_text, (20, H - 15),
            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1
        )

        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        ch.inference_ms = round(elapsed_ms, 1)
        ch.fps = round(1000.0 / max(elapsed_ms, 1.0), 1)
        ch.current_frame_idx = frame_idx
        ch.person_count = len(p_boxes) if self.two_stage else 0
        ch.cigarette_count = len(final_cigs) if is_confirmed else 0
        ch.smoker_count = (
            len(smoker_indices) if (self.two_stage and is_confirmed) else (1 if is_confirmed else 0)
        )
        ch.max_confidence = float(max(final_scores)) if len(final_scores) > 0 else 0.0

        if is_confirmed:
            ch.status = "PELANGGARAN MEROKOK"
        elif len(final_cigs) > 0:
            ch.status = "VERIFIKASI"
        else:
            ch.status = "AMAN"

        now = time.time()
        if allow_snapshot and is_confirmed and (now - ch.last_incident_time) >= self.incident_cooldown:
            ch.last_incident_time = now
            self._save_incident_snapshot(
                ch, vis, frame_idx, len(final_cigs), max(1, len(smoker_indices))
            )

        return vis

    def _save_incident_snapshot(self, ch: CameraChannel, vis_frame, frame_idx, cig_count=None, smk_count=None):
        try:
            from .models import SmokingIncident

            ts_str = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:18]
            filename = f"incident_{ch.key}_{ts_str}_f{frame_idx}.jpg"
            rel_url = f"/media/snapshots/{filename}"
            full_path = Path(settings.MEDIA_ROOT) / "snapshots" / filename
            cv2.imwrite(str(full_path), vis_frame)

            inc = SmokingIncident.objects.create(
                camera_name=ch.camera_name,
                location=ch.location,
                frame_number=frame_idx,
                person_count=ch.person_count,
                smoker_count=smk_count if smk_count is not None else max(1, ch.smoker_count),
                cigarette_count=cig_count if cig_count is not None else max(1, ch.cigarette_count),
                max_confidence=ch.max_confidence,
                detection_mode="Two-Stage YOLOv8" if self.two_stage else "Single-Stage YOLOv8",
                snapshot_url=rel_url,
            )
            from .fcm_service import dispatch_fcm_background
            dispatch_fcm_background(inc.to_dict())
        except Exception as e:
            print("Snapshot save error:", e)

    def _producer_loop(self, ch: CameraChannel, my_stream_id: int):
        source = ch.source
        if source == 0:
            cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
        else:
            cap = cv2.VideoCapture(source)

        ch.total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) if source != 0 else 0
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        if w > 0 and h > 0:
            ch.width, ch.height = w, h
        native_fps = cap.get(cv2.CAP_PROP_FPS)
        target_interval = (1.0 / native_fps) if (source != 0 and native_fps and 5 <= native_fps <= 60) else 0.04
        frame_idx = 0

        try:
            while self.stream_active and ch.active_stream_id == my_stream_id:
                loop_start = time.perf_counter()
                cfg_sig = (
                    round(self.conf_threshold, 3),
                    self.two_stage,
                    self.show_person_box,
                    self.min_consecutive_frames,
                )

                if self.paused and ch.last_raw_frame is not None:
                    if cfg_sig != ch.last_config_signature or ch.last_jpeg is None:
                        vis = self.process_frame_for_channel(
                            ch, ch.last_raw_frame, frame_idx=frame_idx, allow_snapshot=False
                        )
                        ok, buffer = cv2.imencode(".jpg", vis, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                        if ok:
                            ch.last_jpeg = buffer.tobytes()
                            ch.last_config_signature = cfg_sig
                            ch.frame_seq += 1
                    time.sleep(0.06)
                    continue

                ret, frame = cap.read()
                if not ret or frame is None:
                    if source == 0:
                        time.sleep(0.1)
                        continue
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    frame_idx = 0
                    ch.consecutive_hits = 0
                    ret, frame = cap.read()
                    if not ret or frame is None:
                        time.sleep(0.2)
                        continue

                frame_idx += 1
                ch.last_raw_frame = frame.copy()
                vis = self.process_frame_for_channel(ch, frame, frame_idx=frame_idx, allow_snapshot=True)
                ok, buffer = cv2.imencode(".jpg", vis, [int(cv2.IMWRITE_JPEG_QUALITY), 82])
                if not ok:
                    continue

                ch.last_jpeg = buffer.tobytes()
                ch.last_config_signature = cfg_sig
                ch.frame_seq += 1

                spent = time.perf_counter() - loop_start
                remain = target_interval - spent
                if remain > 0.004:
                    time.sleep(remain)
                else:
                    time.sleep(0.005)
        finally:
            cap.release()
            with ch.producer_lock:
                if ch.active_stream_id == my_stream_id:
                    ch.producer_running = False

    def get_channel(self, cam_key: str | None = None) -> CameraChannel:
        if not cam_key:
            ch = self.primary_channel()
        else:
            norm = self.normalize_cam_key(cam_key)
            ch = self.channels[norm]
        return ch

    def ensure_channel_for_request(self, cam_key: str | None = None) -> CameraChannel:
        ch = self.get_channel(cam_key)
        self._ensure_channel_running(ch)
        return ch

    def generate_mjpeg(self, requested_source=None, cam_key=None):
        target_key = cam_key or requested_source
        if requested_source in ("webcam", "custom_video") and not cam_key:
            self.set_source_mode(requested_source)

        ch = self.ensure_channel_for_request(target_key)
        my_stream_id = ch.active_stream_id
        last_sent_seq = -1

        while self.stream_active and ch.active_stream_id == my_stream_id:
            if not ch.producer_running:
                self._ensure_channel_running(ch)
                my_stream_id = ch.active_stream_id

            if ch.last_jpeg is not None and (ch.frame_seq != last_sent_seq or self.paused):
                last_sent_seq = ch.frame_seq
                yield (
                    b"--frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n" + ch.last_jpeg + b"\r\n"
                )
                if self.paused:
                    time.sleep(0.1)
            else:
                time.sleep(0.02)

    def get_status_dict(self, cam_key: str | None = None):
        if cam_key:
            ch = self.get_channel(cam_key)
            base = ch.to_status_dict(self.min_consecutive_frames)
            base.update(
                {
                    "source_mode": self.source_mode,
                    "two_stage": self.two_stage,
                    "show_person_box": self.show_person_box,
                    "conf_threshold": round(self.conf_threshold, 2),
                    "min_consecutive_frames": self.min_consecutive_frames,
                    "paused": self.paused,
                    "device_name": self.device_name,
                }
            )
            return base

        active_keys = self.active_channel_keys()
        active_channels = [self.channels[k] for k in active_keys]

        if len(active_channels) == 2:
            ca, cb = active_channels[0], active_channels[1]
            if "PELANGGARAN MEROKOK" in (ca.status, cb.status):
                agg_status = "PELANGGARAN MEROKOK"
            elif "VERIFIKASI" in (ca.status, cb.status):
                agg_status = "VERIFIKASI"
            else:
                agg_status = "AMAN"

            avg_fps = round((ca.fps + cb.fps) / 2.0, 1) if (ca.fps and cb.fps) else max(ca.fps, cb.fps)
            avg_ms = round((ca.inference_ms + cb.inference_ms) / 2.0, 1) if (ca.inference_ms and cb.inference_ms) else max(ca.inference_ms, cb.inference_ms)
            summary_cam_name = "Dual Monitor (CCTV A & CCTV B)"
            summary_location = "Koridor Indoor & Selasar Parkiran Kampus"
            person_total = ca.person_count + cb.person_count
            smoker_total = ca.smoker_count + cb.smoker_count
            cig_total = ca.cigarette_count + cb.cigarette_count
            max_conf = round(max(ca.max_confidence, cb.max_confidence), 3)
            max_hits = min(max(ca.consecutive_hits, cb.consecutive_hits), self.min_consecutive_frames)
            cur_frame = ca.current_frame_idx
            tot_frames = ca.total_frames
        else:
            c = active_channels[0]
            agg_status = c.status
            avg_fps = c.fps
            avg_ms = c.inference_ms
            summary_cam_name = c.camera_name
            summary_location = c.location
            person_total = c.person_count
            smoker_total = c.smoker_count
            cig_total = c.cigarette_count
            max_conf = round(c.max_confidence, 3)
            max_hits = min(c.consecutive_hits, self.min_consecutive_frames)
            cur_frame = c.current_frame_idx
            tot_frames = c.total_frames

        return {
            "camera_name": summary_cam_name,
            "location": summary_location,
            "source_mode": self.source_mode,
            "active_cameras": len(active_channels),
            "two_stage": self.two_stage,
            "show_person_box": self.show_person_box,
            "conf_threshold": round(self.conf_threshold, 2),
            "min_consecutive_frames": self.min_consecutive_frames,
            "consecutive_hits": max_hits,
            "paused": self.paused,
            "current_frame": cur_frame,
            "total_frames": tot_frames,
            "person_count": person_total,
            "smoker_count": smoker_total,
            "cigarette_count": cig_total,
            "max_confidence": max_conf,
            "fps": avg_fps,
            "inference_ms": avg_ms,
            "status": agg_status,
            "device_name": self.device_name,
            "cameras": {
                "cctv_a": self.channels["cctv_a"].to_status_dict(self.min_consecutive_frames),
                "cctv_b": self.channels["cctv_b"].to_status_dict(self.min_consecutive_frames),
                "custom_video": self.channels["custom_video"].to_status_dict(self.min_consecutive_frames),
                "webcam": self.channels["webcam"].to_status_dict(self.min_consecutive_frames),
            },
        }
