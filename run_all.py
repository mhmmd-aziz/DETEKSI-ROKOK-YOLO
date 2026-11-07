import os
import sys
import signal
import subprocess
import threading
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = ROOT_DIR / "backend"
FRONTEND_DIR = ROOT_DIR / "frontend"
PYTHON_EXE = r"d:\ml\miniconda3\envs\mlenv\python.exe"
if not os.path.exists(PYTHON_EXE):
    PYTHON_EXE = sys.executable


def stream_output(pipe, prefix):
    try:
        for line in iter(pipe.readline, ""):
            if not line:
                break
            print(f"{prefix} {line}", end="", flush=True)
    except Exception:
        pass


def main():
    print("===============================================================")
    print("  SmokeGuard AI - Single Terminal Runner (Backend + Frontend)")
    print("  Django Backend : http://127.0.0.1:8000")
    print("  React Frontend : http://localhost:5173")
    print("===============================================================", flush=True)

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"

    backend_proc = subprocess.Popen(
        [PYTHON_EXE, "manage.py", "runserver", "127.0.0.1:8000", "--noreload"],
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
