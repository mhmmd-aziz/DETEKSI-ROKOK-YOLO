# SmokeGuard AI — Sistem Monitoring Kawasan Tanpa Rokok (YOLOv8 Two-Stage + Web React + Flutter Android FCM)

Proyek Tugas Akhir (TA) Sistem Deteksi Merokok Real-Time menggunakan metode **Two-Stage Detection (Person ROI + Cigarette Detection)** berbasis **YOLOv8** + **Temporal Verification Filter**, terintegrasi dengan **Web Dashboard (Django + React)** dan **Aplikasi Mobile Native Android (Flutter + FCM + Heads-Up Notification)**.

---

## 1. Cara Menjalankan Semua Sistem (1 Terminal + Auto-Update IP Wi-Fi / Hotspot HP)

Buka **PowerShell** di folder proyek ini, lalu jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File .\start_all.ps1
```

Atau langsung menggunakan Python:
```powershell
d:\ml\miniconda3\envs\mlenv\python.exe run_all.py
```
Atau klik 2x pada file **`start_dashboard.bat`**.

**Apa yang dilakukan otomatis oleh script tersebut?**
1. **Auto-Detect IP Laptop (Wi-Fi / Hotspot HP):** Mendeteksi IP IPv4 aktif laptop Anda (baik saat terhubung ke Wi-Fi rumah/kampus maupun saat laptop terhubung ke **Hotspot HP**) dan otomatis memperbarui IP di `mobile_app/lib/main.dart`.
2. **Auto USB Tunnel (`adb reverse`):** Jika HP dicolok kabel USB, port `8000` otomatis diteruskan (`tcp:8000 -> tcp:8000`).
3. **Menjalankan Backend Django (`0.0.0.0:8000`) & Web React (`localhost:5173`)** dalam 1 terminal.

---

## 2. Cara Menghubungkan HP (Flutter) ke Laptop: Hotspot HP, Wi-Fi, atau Kabel USB

Aplikasi Flutter (`SmokeGuard AI`) mendukung **3 mode koneksi** yang bisa berpindah kapan saja **tanpa perlu build ulang APK**:

### Mode A: Menggunakan Hotspot HP ke Laptop (Tanpa Router Wi-Fi)
1. Nyalakan **Hotspot Pribadi (Personal Hotspot / Tethering)** di HP Anda.
2. Hubungkan Wi-Fi Laptop Anda ke Hotspot HP tersebut.
3. Jalankan `powershell -ExecutionPolicy Bypass -File .\start_all.ps1` di Laptop.
   - Di terminal akan muncul tulisan, contoh: `Django Backend (Wi-Fi) : http://192.168.43.105:8000` (atau `192.168.x.x`).
4. Buka aplikasi **SmokeGuard AI** di HP:
   - Aplikasi akan **otomatis memindai (Auto-Scan)** jaringan Hotspot dan langsung terhubung ke IP Laptop Anda.
   - Atau tekan ikon **Pengaturan Jaringan (kanan atas AppBar)** -> tekan tombol **"Scan Otomatis IP Laptop (Wi-Fi / Hotspot)"** (atau ketik IP Laptop yang tertera di terminal, misalnya `192.168.43.105`) -> tekan **Simpan**.

### Mode B: Menggunakan Wi-Fi yang Sama (Laptop & HP satu Wi-Fi)
1. Pastikan Laptop dan HP terhubung ke nama Wi-Fi yang sama.
2. Jalankan `powershell -ExecutionPolicy Bypass -File .\start_all.ps1` di Laptop.
3. Buka aplikasi **SmokeGuard AI** di HP:
   - Tekan ikon **Pengaturan Jaringan (kanan atas AppBar)** -> tekan **"Scan Otomatis IP Laptop (Wi-Fi / Hotspot)"** atau ketik IP Laptop yang tampil di terminal -> tekan **Simpan**.

### Mode C: Menggunakan Kabel Data USB (Paling Stabil & Tanpa Kuota/Firewall)
1. Colokkan HP ke Laptop dengan kabel USB (pastikan **USB Debugging** aktif di Opsi Pengembang HP).
2. Jalankan `powershell -ExecutionPolicy Bypass -File .\start_all.ps1`.
3. Di aplikasi **SmokeGuard AI** di HP, buka **Pengaturan Jaringan (kanan atas)** -> pilih chip **`Kabel USB (127.0.0.1:8000)`** -> tekan **Simpan**.

> **Catatan Firewall Windows (Khusus Mode Wi-Fi / Hotspot HP):**
> Jika HP tidak bisa mengakses IP Laptop saat memakai Wi-Fi/Hotspot, buka PowerShell **Run as Administrator** di Laptop lalu jalankan 1 kali perintah ini untuk membuka port `8000`:
> ```powershell
> netsh advfirewall firewall add rule name="SmokeGuard_Django_8000" dir=in action=allow protocol=TCP localport=8000
> ```

---

## 3. Cara Build & Install Aplikasi Flutter Android (`mobile_app`)

- **Langsung Install APK yang sudah siap ke HP (via USB):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\start_all.ps1 -InstallApk
  ```
  *(Pastikan opsi **"Install via USB / Instal melalui USB"** aktif di Opsi Pengembang HP, dan tekan **"Install"** jika muncul pop-up di layar HP).*

- **Build Ulang APK + Update IP Otomatis + Install ke HP:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\start_all.ps1 -BuildApk
  ```

- **Lokasi File APK Manual (bisa dikirim lewat WhatsApp / Kabel Data ke HP):**
  `mobile_app\build\app\outputs\flutter-apk\app-debug.apk`
