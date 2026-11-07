# SmokeGuard AI — Sistem Monitoring Kawasan Tanpa Rokok (YOLOv8 Two-Stage Detection)

Proyek Tugas Akhir (TA) Sistem Deteksi Merokok Real-Time pada Kamera CCTV menggunakan metode **Two-Stage Detection (Person ROI + Cigarette Detection)** berbasis **YOLOv8**, dilengkapi dengan Web Dashboard Monitoring (**Django Backend** & **React + Vite Frontend**).

## Fitur Utama
- **Two-Stage YOLOv8 Pipeline (Anti-False Positive):**
  - **Tahap 1 (Person ROI):** Mendeteksi koordinat orang (`yolov8n.pt`) sehingga objek latar belakang/tiang ruangan otomatis diabaikan.
  - **Tahap 2 (HD Cropping & Cigarette Detection):** Memotong area tubuh atas hingga tangan pada resolusi asli sebelum dideteksi oleh model `best.pt` (`mAP@50 Val: 94.7%`, `mAP@50 Test: 94.2%`).
- **Web Dashboard Monitoring (Putih - Hijau Clean):**
  - Live Stream CCTV Demo, Upload Video MP4, & Live Webcam (hanya menyala ketika tab Webcam dipilih).
  - Kontrol **Confidence Threshold Real-Time** (`15%` – `85%`), toggle **Two-Stage vs Single-Stage**, dan toggle **Bounding Box Orang (AMAN / MEROKOK)**.
  - Tangkapan layar bukti pelanggaran otomatis (*Auto-Snapshot*) beserta galeri riwayat pelanggaran.
  - Grafik evaluasi hasil training 50 epoch (`mAP@50` & `Box Loss`).

## Cara Menjalankan (1 Terminal untuk Backend & Frontend)

```powershell
python run_all.py
```
Atau klik 2x pada file `start_dashboard.bat`.
- **React Frontend:** `http://localhost:5173`
- **Django Backend API:** `http://127.0.0.1:8000`
