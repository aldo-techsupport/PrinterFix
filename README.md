# Printer Sharing Fix Tool untuk Windows 10/11

Tool GUI PowerShell untuk mengatasi berbagai masalah printer sharing di Windows 10 dan Windows 11.

## Masalah yang Ditangani

Tool ini mengatasi berbagai error code printer sharing yang umum terjadi:

- **0x0000011b** - Error RPC over SMB (paling umum setelah Windows Update KB5005565)
- **0x000003e3** - Error koneksi printer network
- **0x00000709** - Error saat menambahkan atau menggunakan printer
- **0x00000bcb** - Error driver printer
- **0x00000040** - Error printer driver isolation / driver issue
- **0x00004005** - Error access denied
- **0x00000002** - Printer tidak ditemukan
- Dan berbagai masalah printer sharing lainnya


**Fitur:**
- 💾 **Backup & Restore Registry** - Backup otomatis sebelum perbaikan
- Nonaktifkan RPC over SMB (fix error 0x0000011b)
- Restart Print Spooler Service
- Bersihkan Print Queue
- Set Printer Sharing Permissions
- Enable File and Printer Sharing di Firewall
- Konfigurasi SMB Settings
- Fix Error 0x00000040 (Driver Issue)

#### 10. PrinterSharingFix-Client.ps1
Script untuk komputer **CLIENT** (komputer yang mengakses printer shared)

**Fitur:**
- 💾 **Backup & Restore Registry** - Backup otomatis sebelum perbaikan
- Nonaktifkan RPC over SMB Client (fix error 0x0000011b)
- Hapus printer yang bermasalah
- Restart Print Spooler Service
- Bersihkan Print Queue
- Set Point and Print Restrictions
- Perbaiki Network Discovery
- Reset Printer Driver Cache
- Tambah printer manual dengan GUI
- Fix Error 0x00000040 (Driver Issue)

## Fitur Backup & Restore

Semua perubahan registry akan di-backup secara otomatis ke:
**`C:\Users\[Username]\Documents\Backup Printer`**

- Backup otomatis ditawarkan sebelum menjalankan perbaikan
- Bisa backup manual kapan saja dengan tombol "💾 Backup Registry Sekarang"
- Restore dari backup dengan tombol "♻️ Restore dari Backup"
- Setiap backup diberi timestamp untuk mudah diidentifikasi
- Backup terpisah untuk Server dan Client

## Cara Penggunaan

### Cara Paling Mudah (RECOMMENDED):

1. **Double-click** pada file **`PrinterSharingFix-AutoAdmin.bat`**
2. Klik **"Yes"** saat diminta hak Administrator (UAC prompt)
3. Pilih menu:
   - **[1] SERVER** - Jika komputer ini yang share printer
   - **[2] CLIENT** - Jika komputer ini yang akses printer
4. Tool GUI akan terbuka, klik **"JALANKAN SEMUA PERBAIKAN"**
5. Pilih **"Yes"** untuk backup registry (sangat direkomendasikan)
6. Tunggu proses selesai, lalu restart komputer


### Cara Manual:

#### Untuk Server (Komputer yang Share Printer):

1. Klik kanan pada file `PrinterSharingFix-Server.ps1`
2. Pilih **"Run with PowerShell"** atau **"Run as Administrator"**
3. Jika muncul peringatan execution policy, ketik `Y` dan Enter
4. Klik tombol **"JALANKAN SEMUA PERBAIKAN"** (recommended)
5. Restart komputer setelah selesai

#### Untuk Client (Komputer yang Akses Printer):

1. Klik kanan pada file `PrinterSharingFix-Client.ps1`
2. Pilih **"Run with PowerShell"** atau **"Run as Administrator"**
3. Jika muncul peringatan execution policy, ketik `Y` dan Enter
4. Klik tombol **"JALANKAN SEMUA PERBAIKAN"** (recommended)
5. Restart komputer setelah selesai
6. Setelah restart, tambahkan printer kembali menggunakan tombol **"Fix 8: Tambah Printer Manual"**

## Troubleshooting

### Jika script tidak bisa dijalankan:

Buka PowerShell sebagai Administrator dan jalankan:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Jika masih error setelah fix:

1. Pastikan kedua komputer (server dan client) sudah menjalankan fix masing-masing
2. Pastikan kedua komputer sudah di-restart
3. Pastikan firewall tidak memblokir File and Printer Sharing
4. Pastikan kedua komputer dalam network yang sama
5. Coba ping dari client ke server untuk memastikan koneksi

### Cara manual menambahkan printer setelah fix:

1. Buka **Settings** > **Devices** > **Printers & scanners**
2. Klik **"Add a printer or scanner"**
3. Klik **"The printer that I want isn't listed"**
4. Pilih **"Select a shared printer by name"**
5. Ketik: `\\NAMA-SERVER\NAMA-PRINTER`
6. Klik **Next** dan ikuti instruksi

## Catatan Penting

- **HARUS dijalankan sebagai Administrator** (gunakan file AutoAdmin.bat untuk otomatis)
- **Selalu backup registry sebelum perbaikan** (tool akan menawarkan backup otomatis)
- Backup disimpan di: `Documents\Backup Printer`
- Restart komputer setelah menjalankan fix
- Jalankan fix di SERVER terlebih dahulu, baru di CLIENT
- Beberapa fix memerlukan restart untuk efektif
- Jika terjadi masalah, gunakan fitur **Restore** untuk mengembalikan registry

## Cara Restore Jika Terjadi Masalah

1. Jalankan tool yang sama (Server atau Client)
2. Klik tombol **"♻️ Restore dari Backup"**
3. Pilih backup yang ingin di-restore (biasanya yang paling baru)
4. Klik **"Restore"** dan konfirmasi
5. Restart komputer

## Penjelasan Error Code

### 0x0000011b
Error ini muncul setelah Windows Update KB5005565 (September 2021) yang mengubah cara Windows menangani RPC over SMB untuk printer sharing. Fix utama adalah menonaktifkan RpcAuthnLevelPrivacyEnabled.

### 0x000003e3
Error koneksi ke printer network, biasanya karena masalah permissions atau firewall. Fix dengan mengatur Point and Print policies dan firewall rules.

### 0x00000709
Error saat set default printer atau koneksi ke printer. Fix dengan membersihkan registry printer yang corrupt dan reset print spooler.

### 0x00000bcb
Error driver printer, biasanya karena driver tidak kompatibel atau corrupt. Fix dengan reset driver cache dan reinstall printer.

### 0x00000040
Error printer driver isolation atau masalah driver. Biasanya terjadi saat install driver printer atau connect ke network printer. Fix dengan disable driver isolation policy dan clear driver cache.

## Lisensi

Tool ini gratis untuk digunakan dan dimodifikasi sesuai kebutuhan.

## Disclaimer

Gunakan tool ini dengan risiko Anda sendiri. Selalu backup data penting sebelum melakukan perubahan sistem.
