@echo off
title Buka Folder Backup Printer
color 0B

echo.
echo ============================================
echo   MEMBUKA FOLDER BACKUP
echo ============================================
echo.

set "backupFolder=%USERPROFILE%\Documents\Backup Printer"

if exist "%backupFolder%" (
    echo Membuka folder: %backupFolder%
    echo.
    explorer "%backupFolder%"
    echo.
    echo Folder backup berhasil dibuka!
) else (
    echo Folder backup belum ada!
    echo.
    echo Folder akan dibuat saat Anda melakukan backup pertama kali.
    echo Lokasi: %backupFolder%
    echo.
    echo Apakah Anda ingin membuat folder sekarang? (Y/N)
    set /p create="Pilihan: "
    
    if /i "%create%"=="Y" (
        mkdir "%backupFolder%"
        echo.
        echo Folder berhasil dibuat!
        explorer "%backupFolder%"
    )
)

echo.
echo ============================================
pause
