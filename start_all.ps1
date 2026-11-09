param(
    [string]$CustomIp = "",
    [switch]$BuildApk = $false,
    [switch]$InstallApk = $false
)

$ErrorActionPreference = "SilentlyContinue"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

$PythonExe = "d:\ml\miniconda3\envs\mlenv\python.exe"
if (-not (Test-Path $PythonExe)) {
    $PythonExe = "python"
}

$FlutterBat = "D:\mobile_app\flutter\bin\flutter.bat"
if (-not (Test-Path $FlutterBat)) {
    $FlutterBat = "flutter"
}

$AdbExe = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $AdbExe)) {
    $AdbExe = "adb"
}

# 1. Deteksi Otomatis IP Laptop (Wi-Fi / Hotspot HP ke Laptop / LAN)
function Get-ActiveLaptopIp {
    if ($CustomIp -ne "") {
        return $CustomIp
    }
    $ipList = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notmatch "Loopback|vEthernet|WSL|VMware|VirtualBox"
    } | Sort-Object -Property @{Expression={
        if ($_.InterfaceAlias -match "Wi-Fi|Wireless|WLAN") { 0 }
        elseif ($_.IPAddress -like "192.168.*") { 1 }
        elseif ($_.IPAddress -like "172.20.10.*") { 2 }
        else { 3 }
    }}
    if ($ipList -and $ipList.Count -gt 0) {
        return $ipList[0].IPAddress
    }
    return "127.0.0.1"
}

$ActiveIp = Get-ActiveLaptopIp
$DartFile = Join-Path $ProjectRoot "mobile_app\lib\main.dart"

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "  SMOKEGUARD AI - ALL-IN-ONE LAUNCHER (POWERSHELL)" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "  IP Laptop Terdeteksi (Wi-Fi / Hotspot HP) : http://$($ActiveIp):8000" -ForegroundColor Cyan
Write-Host "  URL USB Debugging (Kabel Data)            : http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "  URL Web Dashboard (React Vite)            : http://localhost:5173" -ForegroundColor Cyan

# 2. Update otomatis IP Wi-Fi/Hotspot di mobile_app/lib/main.dart
if ((Test-Path $DartFile) -and ($ActiveIp -ne "127.0.0.1")) {
    $content = Get-Content $DartFile -Raw -Encoding UTF8
    $updated = $content -replace "const String kDefaultLanServerUrl = 'http://[^']+';", "const String kDefaultLanServerUrl = 'http://$($ActiveIp):8000';"
    if ($updated -ne $content) {
        Set-Content -Path $DartFile -Value $updated -Encoding UTF8 -NoNewline
        Write-Host "  [AUTO-IP] mobile_app/lib/main.dart diperbarui ke http://$($ActiveIp):8000" -ForegroundColor Yellow
    }
}

# 3. Buka Port 8000 di Windows Firewall (jika dijalankan sebagai Admin) agar Hotspot HP / Wi-Fi tidak terblokir
netsh advfirewall firewall add rule name="SmokeGuard_Django_8000" dir=in action=allow protocol=TCP localport=8000 | Out-Null

# 4. Aktifkan USB Port Forwarding (adb reverse) jika HP dicolok kabel USB
& $AdbExe reverse tcp:8000 tcp:8000 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  [USB ADB] Port Forwarding aktif (tcp:8000 -> tcp:8000)" -ForegroundColor Green
}

# 5. Opsional: Build ulang APK jika diminta (-BuildApk)
$ApkPath = Join-Path $ProjectRoot "mobile_app\build\app\outputs\flutter-apk\app-debug.apk"
if ($BuildApk) {
    Write-Host "`n  [FLUTTER] Mem-build APK dengan IP terbaru ($ActiveIp)..." -ForegroundColor Yellow
    $GradlewBat = Join-Path $ProjectRoot "mobile_app\android\gradlew.bat"
    $AndroidDir = Join-Path $ProjectRoot "mobile_app\android"
    & $GradlewBat -p $AndroidDir assembleDebug
}

# 6. Opsional: Install APK ke HP via USB jika diminta (-InstallApk atau -BuildApk)
if ($InstallApk -or $BuildApk) {
    if (Test-Path $ApkPath) {
        Write-Host "  [ADB INSTALL] Meng-install APK ke HP (Silakan tekan 'Install' di layar HP jika muncul pop-up)..." -ForegroundColor Yellow
        & $AdbExe install -r $ApkPath
    }
}

# 7. Bersihkan proses lama di port 8000 & 5173 lalu jalankan Backend Django + React Web
Get-NetTCPConnection -LocalPort 8000,5173 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
    Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
}

Write-Host "=================================================================`n" -ForegroundColor Green
& $PythonExe (Join-Path $ProjectRoot "run_all.py")

