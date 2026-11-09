import os
import re
import sys
import signal
import socket
import subprocess
import threading
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = ROOT_DIR / "backend"
FRONTEND_DIR = ROOT_DIR / "frontend"
FLUTTER_MAIN_DART = ROOT_DIR / "mobile_app" / "lib" / "main.dart"
PYTHON_EXE = r"d:\ml\miniconda3\envs\mlenv\python.exe"
if not os.path.exists(PYTHON_EXE):
    PYTHON_EXE = sys.executable


def detect_laptop_ips():
    """Deteksi semua IPv4 aktif di Laptop (Wi-Fi, Hotspot HP ke Laptop, atau Ethernet)."""
    ips = []
    # Metode 1: UDP socket ke publik untuk mendapat IP interface utama (Wi-Fi / Hotspot aktif)
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        s.connect(("8.8.8.8", 80))
        primary_ip = s.getsockname()[0]
        s.close()
        if primary_ip and not primary_ip.startswith("127."):
            ips.append(primary_ip)
    except Exception:
        pass

    # Metode 2: Semua interface lokal
    try:
        hostname = socket.gethostname()
        for info in socket.getaddrinfo(hostname, None, socket.AF_INET):
            ip = info[4][0]
            if ip and not ip.startswith("127.") and not ip.startswith("169.254.") and ip not in ips:
                ips.append(ip)
    except Exception:
        pass

    # Urutkan agar IP Wi-Fi / Hotspot HP (192.168.x.x / 172.20.10.x / 10.x.x.x) berada di urutan pertama
    def ip_priority(ip_str):
        if ip_str.startswith("192.168."):
            return 0
        if ip_str.startswith("172.20.10."):
            return 1
        if ip_str.startswith("10."):
            return 2
        return 3

    ips.sort(key=ip_priority)
    return ips if ips else ["127.0.0.1"]


def sync_ip_to_flutter(primary_ip):
    """Otomatis perbarui kandidat IP Wi-Fi/Hotspot di mobile_app/lib/main.dart."""
    if not primary_ip or primary_ip == "127.0.0.1" or not FLUTTER_MAIN_DART.exists():
        return
    try:
        content = FLUTTER_MAIN_DART.read_text(encoding="utf-8")
        updated = re.sub(
            r"const String kDefaultLanServerUrl = 'http://[^']+';",
            f"const String kDefaultLanServerUrl = 'http://{primary_ip}:8000';",
            content,
        )
        if updated != content:
            FLUTTER_MAIN_DART.write_text(updated, encoding="utf-8")
            print(f"  [AUTO-IP] Default IP di Flutter diperbarui ke: http://{primary_ip}:8000")
    except Exception:
        pass


def stream_output(pipe, prefix):
    try:
        for line in iter(pipe.readline, ""):
            if not line:
                break
            print(f"{prefix} {line}", end="", flush=True)
    except Exception:
        pass


def setup_adb_reverse():
    adb_candidates = [
        "adb",
        os.path.expandvars(r"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"),
        r"D:\mobile_app\Android\Sdk\platform-tools\adb.exe",
        r"C:\Android\sdk\platform-tools\adb.exe",
    ]
    apk_path = ROOT_DIR / "mobile_app" / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
    skip_install = "--skip-adb-install" in sys.argv

    for adb_bin in adb_candidates:
        try:
            res = subprocess.run(
                [adb_bin, "reverse", "tcp:8000", "tcp:8000"],
                capture_output=True,
                text=True,
                timeout=3,
            )
            if res.returncode == 0:
                print("  [USB ADB] Port Forwarding otomatis aktif: tcp:8000 -> tcp:8000 (Flutter USB Ready)")
                if not skip_install and apk_path.exists():
                    print("  [USB INSTALL] Meng-install APK ke HP via USB (Tekan 'Install' di layar HP jika muncul pop-up)...", flush=True)
                    subprocess.run([adb_bin, "shell", "input", "keyevent", "KEYCODE_WAKEUP"], capture_output=True, timeout=3)
                    inst = subprocess.run([adb_bin, "install", "-r", str(apk_path)], capture_output=True, text=True, timeout=45)
                    if inst.returncode == 0:
                        print("  [USB INSTALL] APK Berhasil Ter-install! Membuka aplikasi di HP...", flush=True)
                        subprocess.run(
                            [adb_bin, "shell", "am", "start", "-n", "id.smokeguard.smokeguard_mobile/.MainActivity"],
                            capture_output=True,
                            timeout=5,
                        )
                    else:
                        err_msg = (inst.stderr or inst.stdout or "").strip()
                        print(f"  [USB INSTALL] Status: {err_msg}", flush=True)
                return True
        except Exception:
            continue
    return False


def main():
    laptop_ips = detect_laptop_ips()
    primary_ip = laptop_ips[0]
    sync_ip_to_flutter(primary_ip)

    print("===============================================================")
    print("  SmokeGuard AI - Single Terminal Runner (Backend + Web + Flutter)")
    print("  Django Backend (USB)    : http://127.0.0.1:8000")
    print(f"  Django Backend (Wi-Fi)  : http://{primary_ip}:8000")
    if len(laptop_ips) > 1:
        other_ips = ", ".join(f"http://{ip}:8000" for ip in laptop_ips[1:])
        print(f"  IP Jaringan Lainnya     : {other_ips}")
    print("  React Web UI (Laptop)   : http://localhost:5173")
    print("  Flutter App             : mobile_app/ (Auto-Scan Wi-Fi / Hotspot / USB)")
    print("  -------------------------------------------------------------")
    setup_adb_reverse()
    print("===============================================================", flush=True)

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"

    backend_proc = subprocess.Popen(
        [PYTHON_EXE, "manage.py", "runserver", "0.0.0.0:8000", "--noreload"],
        cwd=str(BACKEND_DIR),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )

    npm_cmd = "npm.cmd" if os.name == "nt" else "npm"
    frontend_proc = subprocess.Popen(
        [npm_cmd, "run", "dev"],
        cwd=str(FRONTEND_DIR),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )

    t_be = threading.Thread(target=stream_output, args=(backend_proc.stdout, "[BACKEND] "), daemon=True)
    t_fe = threading.Thread(target=stream_output, args=(frontend_proc.stdout, "[FRONTEND]"), daemon=True)
    t_be.start()
    t_fe.start()

    def shutdown(*_args):
        print("\nMenghentikan Backend & Frontend...", flush=True)
        for p in (frontend_proc, backend_proc):
            if p.poll() is None:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/F", "/T", "/PID", str(p.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    p.terminate()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    try:
        import time
        while True:
            if backend_proc.poll() is not None and frontend_proc.poll() is not None:
                break
            time.sleep(0.5)
    except KeyboardInterrupt:
        shutdown()


if __name__ == "__main__":
    main()
