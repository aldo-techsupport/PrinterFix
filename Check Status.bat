@echo off
title Test Prerequisites - Printer Sharing Fix Tool
color 0E

echo.
echo ============================================
echo   TEST PREREQUISITES
echo   Printer Sharing Fix Tool
echo ============================================
echo.
echo Memeriksa sistem Anda...
echo.

:: Check Windows Version
echo [1/6] Memeriksa versi Windows...
ver | findstr /i "10.0" >nul
if %errorLevel% == 0 (
    echo     [OK] Windows 10/11 terdeteksi
) else (
    echo     [WARNING] Versi Windows tidak terdeteksi dengan benar
)
echo.

:: Check Administrator Rights
echo [2/6] Memeriksa hak Administrator...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo     [OK] Berjalan sebagai Administrator
) else (
    echo     [WARNING] TIDAK berjalan sebagai Administrator
    echo     Script utama memerlukan hak Administrator!
)
echo.

:: Check PowerShell
echo [3/6] Memeriksa PowerShell...
powershell -Command "Write-Host '    [OK] PowerShell tersedia'" 2>nul
if %errorLevel% neq 0 (
    echo     [ERROR] PowerShell tidak ditemukan!
)
echo.

:: Check Print Spooler Service
echo [4/6] Memeriksa Print Spooler Service...
sc query Spooler | findstr "RUNNING" >nul
if %errorLevel% == 0 (
    echo     [OK] Print Spooler berjalan
) else (
    echo     [WARNING] Print Spooler tidak berjalan
    echo     Mencoba start Print Spooler...
    net start Spooler >nul 2>&1
    if %errorLevel% == 0 (
        echo     [OK] Print Spooler berhasil distart
    ) else (
        echo     [ERROR] Gagal start Print Spooler
    )
)
echo.

:: Check Network
echo [5/6] Memeriksa koneksi network...
ping -n 1 127.0.0.1 >nul 2>&1
if %errorLevel% == 0 (
    echo     [OK] Network stack berfungsi
) else (
    echo     [ERROR] Network stack bermasalah
)
echo.

:: Check File Sharing
echo [6/6] Memeriksa File and Printer Sharing...
netsh advfirewall firewall show rule name="File and Printer Sharing (SMB-In)" | findstr "Enabled:.*Yes" >nul
if %errorLevel% == 0 (
    echo     [OK] File and Printer Sharing enabled
) else (
    echo     [WARNING] File and Printer Sharing mungkin disabled
)
echo.

:: Summary
echo ============================================
echo   RINGKASAN
echo ============================================
echo.
echo Jika semua [OK], Anda siap menjalankan fix!
echo.
echo Jika ada [WARNING] atau [ERROR]:
echo   - Jalankan script sebagai Administrator
echo   - Pastikan Print Spooler service berjalan
echo   - Pastikan network berfungsi
echo.
echo File yang harus dijalankan:
echo   ^> PrinterSharingFix-AutoAdmin.bat
echo.
echo ============================================
echo.

:: Check if backup folder exists
set "backupFolder=%USERPROFILE%\Documents\Backup Printer"
if exist "%backupFolder%" (
    echo INFO: Folder backup sudah ada
    echo Lokasi: %backupFolder%
    echo.
    dir "%backupFolder%\*.reg" 2>nul | findstr "File(s)" >nul
    if %errorLevel% == 0 (
        echo Backup ditemukan:
        dir /b "%backupFolder%\*.reg" 2>nul
    ) else (
        echo Belum ada file backup
    )
) else (
    echo INFO: Folder backup belum ada
    echo Akan dibuat otomatis saat backup pertama kali
)
echo.

echo ============================================
pause
