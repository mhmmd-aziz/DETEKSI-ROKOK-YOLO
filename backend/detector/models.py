from django.db import models


class SmokingIncident(models.Model):
    camera_name = models.CharField(max_length=120, default="CAM 01 - R. Indoor Asrama")
    location = models.CharField(max_length=120, default="Gedung Utama Lt. 1 (Zona Bebas Rokok)")
    timestamp = models.DateTimeField(auto_now_add=True)
    frame_number = models.IntegerField(default=0)
    person_count = models.IntegerField(default=0)
    smoker_count = models.IntegerField(default=1)
    cigarette_count = models.IntegerField(default=1)
    max_confidence = models.FloatField(default=0.0)
    detection_mode = models.CharField(max_length=60, default="Two-Stage YOLOv8")
    snapshot_url = models.CharField(max_length=255, blank=True, default="")

    class Meta:
        ordering = ["-timestamp"]

    def to_dict(self):
        return {
            "id": self.id,
            "camera_name": self.camera_name,
            "location": self.location,
            "timestamp": self.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
            "frame_number": self.frame_number,
            "person_count": self.person_count,
            "smoker_count": self.smoker_count,
            "cigarette_count": self.cigarette_count,
            "max_confidence": round(self.max_confidence, 3),
            "detection_mode": self.detection_mode,
            "snapshot_url": self.snapshot_url,
        }

