@echo off
:: Printer Sharing Fix Tool - Auto Administrator Elevation
:: Script ini akan otomatis meminta hak Administrator

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :MAIN
) else (
    goto :ELEVATE
)

:ELEVATE
:: Request administrator privileges
echo Meminta hak Administrator...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:MAIN
title Printer Sharing Fix Tool - Windows 10/11
color 0A

:MENU
cls
echo.
echo ============================================
echo   PRINTER SHARING FIX TOOL
echo   Windows 10/11 - Auto Administrator
echo ============================================
echo.
echo   Error yang ditangani:
echo   - 0x0000011b (RPC over SMB)
echo   - 0x000003e3 (Network Connection)
echo   - 0x00000709 (Default Printer)
echo   - 0x00000bcb (Driver Issues)
echo   - 0x00000040 (Driver Isolation)
echo   - Dan error printer sharing lainnya
echo.
echo ============================================
echo.
echo   Pilih jenis komputer Anda:
echo.
echo   [1] SERVER - Komputer yang share printer
echo   [2] CLIENT - Komputer yang akses printer
echo   [3] Keluar
echo.
echo ============================================
echo.
set /p choice="Masukkan pilihan (1/2/3): "

if "%choice%"=="1" goto SERVER
if "%choice%"=="2" goto CLIENT
if "%choice%"=="3" goto EXIT
echo.
echo Pilihan tidak valid! Silakan pilih 1, 2, atau 3.
timeout /t 2 >nul
goto MENU

:SERVER
cls
echo.
echo ============================================
echo   MENJALANKAN FIX UNTUK SERVER
echo ============================================
echo.
echo Membuka tool perbaikan untuk komputer SERVER...
echo Backup akan disimpan di: %USERPROFILE%\Documents\Backup Printer
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0PrinterSharingFix-Server.ps1"
echo.
echo ============================================
echo   Proses selesai!
echo ============================================
echo.
pause
goto MENU

:CLIENT
cls
echo.
echo ============================================
echo   MENJALANKAN FIX UNTUK CLIENT
echo ============================================
echo.
echo Membuka tool perbaikan untuk komputer CLIENT...
echo Backup akan disimpan di: %USERPROFILE%\Documents\Backup Printer
echo.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0PrinterSharingFix-Client.ps1"
echo.
echo ============================================
echo   Proses selesai!
echo ============================================
echo.
pause
goto MENU

:EXIT
cls
echo.
echo Terima kasih telah menggunakan Printer Sharing Fix Tool!
echo.
timeout /t 2 >nul
exit /b 0
