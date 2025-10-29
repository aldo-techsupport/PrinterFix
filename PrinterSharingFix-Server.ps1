# Printer Sharing Fix - SERVER Side
# Mengatasi masalah printer sharing di Windows 10/11 untuk komputer SERVER
# Error codes: 0x0000011b, 0x000003e3, 0x00000709, 0x00000bcb, dll

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Fungsi untuk menjalankan perintah sebagai Administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    [System.Windows.Forms.MessageBox]::Show("Script ini harus dijalankan sebagai Administrator!`n`nKlik kanan pada file dan pilih 'Run as Administrator'", "Perlu Hak Administrator", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
}

# Folder backup
$backupFolder = [Environment]::GetFolderPath("MyDocuments") + "\Backup Printer"

# Fungsi untuk log
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    $textBoxLog.AppendText("$logMessage`r`n")
    $textBoxLog.ScrollToCaret()
}

# Fungsi Backup Registry
function Backup-PrinterRegistry {
    Write-Log "=== Memulai: Backup Registry Printer ==="
    try {
        if (-not (Test-Path $backupFolder)) {
            New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
            Write-Log "[OK] Folder backup dibuat: $backupFolder"
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = "$backupFolder\PrinterRegistry_Server_$timestamp.reg"
        
        # Backup registry keys
        $regKeys = @(
            "HKLM\System\CurrentControlSet\Control\Print",
            "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers"
        )
        
        foreach ($key in $regKeys) {
            reg export $key "$backupFolder\temp_$timestamp.reg" /y 2>$null
        }
        
        # Export full backup
        reg export "HKLM\System\CurrentControlSet\Control\Print" $backupFile /y | Out-Null
        
        Write-Log "[OK] Backup registry berhasil: $backupFile"
        Write-Log "[INFO] Lokasi: $backupFolder"
        
        # Simpan info backup
        $backupInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Type = "Server"
            File = $backupFile
        }
        $backupInfo | ConvertTo-Json | Out-File "$backupFolder\LastBackup_Server.json"
        
        return $true
    } catch {
        Write-Log "[ERROR] Gagal backup: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Restore Registry
function Restore-PrinterRegistry {
    Write-Log "=== Memulai: Restore Registry Printer ==="
    try {
        if (-not (Test-Path $backupFolder)) {
            Write-Log "[ERROR] Folder backup tidak ditemukan: $backupFolder"
            [System.Windows.Forms.MessageBox]::Show("Folder backup tidak ditemukan!`n`nBelum ada backup yang dibuat.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return $false
        }
        
        # Cari file backup
        $backupFiles = Get-ChildItem -Path $backupFolder -Filter "PrinterRegistry_Server_*.reg" | Sort-Object LastWriteTime -Descending
        
        if ($backupFiles.Count -eq 0) {
            Write-Log "[ERROR] Tidak ada file backup ditemukan"
            [System.Windows.Forms.MessageBox]::Show("Tidak ada file backup ditemukan!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return $false
        }
        
        # Tampilkan dialog pilih backup
        $restoreForm = New-Object System.Windows.Forms.Form
        $restoreForm.Text = "Pilih Backup untuk Restore"
        $restoreForm.Size = New-Object System.Drawing.Size(500, 300)
        $restoreForm.StartPosition = "CenterScreen"
        
        $listBox = New-Object System.Windows.Forms.ListBox
        $listBox.Location = New-Object System.Drawing.Point(10, 10)
        $listBox.Size = New-Object System.Drawing.Size(460, 200)
        
        foreach ($file in $backupFiles) {
            $listBox.Items.Add("$($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($file.Name)")
        }
        $listBox.SelectedIndex = 0
        $restoreForm.Controls.Add($listBox)
        
        $btnRestore = New-Object System.Windows.Forms.Button
        $btnRestore.Location = New-Object System.Drawing.Point(290, 220)
        $btnRestore.Size = New-Object System.Drawing.Size(80, 30)
        $btnRestore.Text = "Restore"
        $btnRestore.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $restoreForm.Controls.Add($btnRestore)
        
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Location = New-Object System.Drawing.Point(390, 220)
        $btnCancel.Size = New-Object System.Drawing.Size(80, 30)
        $btnCancel.Text = "Batal"
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $restoreForm.Controls.Add($btnCancel)
        
        $result = $restoreForm.ShowDialog()
        
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $listBox.SelectedIndex -ge 0) {
            $selectedFile = $backupFiles[$listBox.SelectedIndex]
            
            $confirm = [System.Windows.Forms.MessageBox]::Show("Restore backup dari:`n$($selectedFile.FullName)`n`nRegistry akan dikembalikan ke kondisi backup ini.`nLanjutkan?", "Konfirmasi Restore", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            
            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                Write-Log "Melakukan restore dari: $($selectedFile.Name)"
                reg import $selectedFile.FullName | Out-Null
                Write-Log "[OK] Restore berhasil!"
                Write-Log "[INFO] Restart Print Spooler untuk menerapkan perubahan"
                Restart-PrintSpooler
                
                [System.Windows.Forms.MessageBox]::Show("Restore berhasil!`n`nRestart komputer untuk menerapkan perubahan.", "Sukses", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                return $true
            }
        }
        
        return $false
    } catch {
        Write-Log "[ERROR] Gagal restore: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 1: Nonaktifkan RPC over SMB (Fix untuk 0x0000011b)
function Fix-RPCoverSMB {
    Write-Log "=== Memulai Fix: Nonaktifkan RPC over SMB (Error 0x0000011b) ==="
    try {
        $regPath = "HKLM:\System\CurrentControlSet\Control\Print"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "RpcAuthnLevelPrivacyEnabled" -Value 0 -Type DWord
        Write-Log "[OK] Registry key berhasil diset: RpcAuthnLevelPrivacyEnabled = 0"
        Write-Log "[INFO] Restart Print Spooler service diperlukan"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 2: Restart Print Spooler Service
function Restart-PrintSpooler {
    Write-Log "=== Memulai: Restart Print Spooler Service ==="
    try {
        Write-Log "Menghentikan Print Spooler..."
        Stop-Service -Name Spooler -Force
        Start-Sleep -Seconds 2
        Write-Log "Memulai Print Spooler..."
        Start-Service -Name Spooler
        Write-Log "[OK] Print Spooler berhasil di-restart"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal restart Print Spooler: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 3: Bersihkan Print Queue
function Clear-PrintQueue {
    Write-Log "=== Memulai: Bersihkan Print Queue ==="
    try {
        Stop-Service -Name Spooler -Force
        Start-Sleep -Seconds 2
        
        $spoolFolder = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $spoolFolder) {
            Get-ChildItem -Path $spoolFolder -File | Remove-Item -Force
            Write-Log "[OK] File di folder spool berhasil dihapus"
        }
        
        Start-Service -Name Spooler
        Write-Log "[OK] Print Queue berhasil dibersihkan"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal membersihkan queue: $($_.Exception.Message)"
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        return $false
    }
}

# Fungsi Fix 4: Set Printer Sharing Permissions
function Set-PrinterPermissions {
    Write-Log "=== Memulai: Set Printer Sharing Permissions ==="
    try {
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "RestrictDriverInstallationToAdministrators" -Value 0 -Type DWord
        Set-ItemProperty -Path $regPath -Name "NoWarningNoElevationOnInstall" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "UpdatePromptSettings" -Value 2 -Type DWord
        
        Write-Log "[OK] Point and Print permissions berhasil dikonfigurasi"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal set permissions: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 5: Enable File and Printer Sharing
function Enable-FileAndPrinterSharing {
    Write-Log "=== Memulai: Enable File and Printer Sharing ==="
    try {
        netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes | Out-Null
        Write-Log "[OK] File and Printer Sharing di firewall berhasil diaktifkan"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal enable firewall rule: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 6: Set SMB Settings
function Set-SMBSettings {
    Write-Log "=== Memulai: Konfigurasi SMB Settings ==="
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
        Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
        Write-Log "[OK] SMB2 diaktifkan, SMB1 dinonaktifkan (keamanan)"
        return $true
    } catch {
        Write-Log "[WARNING] Gagal set SMB: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix All
function Fix-All {
    Write-Log "`r`n========================================="
    Write-Log "MEMULAI PERBAIKAN LENGKAP - SERVER SIDE"
    Write-Log "=========================================`r`n"
    
    # Backup dulu
    $backupResult = [System.Windows.Forms.MessageBox]::Show("Backup registry sebelum melakukan perbaikan?`n`n(Sangat direkomendasikan)", "Backup Registry", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($backupResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        Backup-PrinterRegistry
        Write-Log ""
    }
    
    $btnFixAll.Enabled = $false
    $btnFix1.Enabled = $false
    $btnFix2.Enabled = $false
    $btnFix3.Enabled = $false
    $btnFix4.Enabled = $false
    $btnFix5.Enabled = $false
    $btnFix6.Enabled = $false
    $btnBackup.Enabled = $false
    $btnRestore.Enabled = $false
    
    Fix-RPCoverSMB
    Start-Sleep -Seconds 1
    Set-PrinterPermissions
    Start-Sleep -Seconds 1
    Enable-FileAndPrinterSharing
    Start-Sleep -Seconds 1
    Set-SMBSettings
    Start-Sleep -Seconds 1
    Clear-PrintQueue
    Start-Sleep -Seconds 1
    Restart-PrintSpooler
    
    Write-Log "`r`n[SELESAI] Semua perbaikan telah dijalankan"
    Write-Log "[PENTING] Restart komputer untuk menerapkan semua perubahan"
    
    $result = [System.Windows.Forms.MessageBox]::Show("Perbaikan selesai!`n`nRestart komputer sekarang?", "Restart Diperlukan", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Restart-Computer -Force
    }
    
    $btnFixAll.Enabled = $true
    $btnFix1.Enabled = $true
    $btnFix2.Enabled = $true
    $btnFix3.Enabled = $true
    $btnFix4.Enabled = $true
    $btnFix5.Enabled = $true
    $btnFix6.Enabled = $true
    $btnBackup.Enabled = $true
    $btnRestore.Enabled = $true
}

# Buat Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Printer Sharing Fix - SERVER Software By Alre1408"
$form.Size = New-Object System.Drawing.Size(700, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Label Header
$labelHeader = New-Object System.Windows.Forms.Label
$labelHeader.Location = New-Object System.Drawing.Point(10, 10)
$labelHeader.Size = New-Object System.Drawing.Size(660, 40)
$labelHeader.Text = "Perbaikan Masalah Printer Sharing - KOMPUTER SERVER`nError: 0x0000011b, 0x000003e3, 0x00000709, 0x00000bcb"
$labelHeader.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelHeader)

# GroupBox untuk Backup/Restore
$groupBoxBackup = New-Object System.Windows.Forms.GroupBox
$groupBoxBackup.Location = New-Object System.Drawing.Point(10, 60)
$groupBoxBackup.Size = New-Object System.Drawing.Size(660, 70)
$groupBoxBackup.Text = "Backup & Restore"
$form.Controls.Add($groupBoxBackup)

# Tombol Backup
$btnBackup = New-Object System.Windows.Forms.Button
$btnBackup.Location = New-Object System.Drawing.Point(20, 25)
$btnBackup.Size = New-Object System.Drawing.Size(300, 30)
$btnBackup.Text = "💾 Backup Registry Sekarang"
$btnBackup.BackColor = [System.Drawing.Color]::LightBlue
$btnBackup.Add_Click({ Backup-PrinterRegistry })
$groupBoxBackup.Controls.Add($btnBackup)

# Tombol Restore
$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Location = New-Object System.Drawing.Point(340, 25)
$btnRestore.Size = New-Object System.Drawing.Size(300, 30)
$btnRestore.Text = "♻️ Restore dari Backup"
$btnRestore.BackColor = [System.Drawing.Color]::LightYellow
$btnRestore.Add_Click({ Restore-PrinterRegistry })
$groupBoxBackup.Controls.Add($btnRestore)

# GroupBox untuk tombol
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Location = New-Object System.Drawing.Point(10, 140)
$groupBox.Size = New-Object System.Drawing.Size(660, 200)
$groupBox.Text = "Pilih Perbaikan"
$form.Controls.Add($groupBox)

# Tombol Fix All
$btnFixAll = New-Object System.Windows.Forms.Button
$btnFixAll.Location = New-Object System.Drawing.Point(20, 25)
$btnFixAll.Size = New-Object System.Drawing.Size(620, 35)
$btnFixAll.Text = "JALANKAN SEMUA PERBAIKAN (Recommended)"
$btnFixAll.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnFixAll.BackColor = [System.Drawing.Color]::Green
$btnFixAll.ForeColor = [System.Drawing.Color]::White
$btnFixAll.Add_Click({ Fix-All })
$groupBox.Controls.Add($btnFixAll)

# Tombol Fix 1
$btnFix1 = New-Object System.Windows.Forms.Button
$btnFix1.Location = New-Object System.Drawing.Point(20, 70)
$btnFix1.Size = New-Object System.Drawing.Size(300, 30)
$btnFix1.Text = "Fix 1: Nonaktifkan RPC over SMB"
$btnFix1.Add_Click({ Fix-RPCoverSMB; Restart-PrintSpooler })
$groupBox.Controls.Add($btnFix1)

# Tombol Fix 2
$btnFix2 = New-Object System.Windows.Forms.Button
$btnFix2.Location = New-Object System.Drawing.Point(340, 70)
$btnFix2.Size = New-Object System.Drawing.Size(300, 30)
$btnFix2.Text = "Fix 2: Restart Print Spooler"
$btnFix2.Add_Click({ Restart-PrintSpooler })
$groupBox.Controls.Add($btnFix2)

# Tombol Fix 3
$btnFix3 = New-Object System.Windows.Forms.Button
$btnFix3.Location = New-Object System.Drawing.Point(20, 110)
$btnFix3.Size = New-Object System.Drawing.Size(300, 30)
$btnFix3.Text = "Fix 3: Bersihkan Print Queue"
$btnFix3.Add_Click({ Clear-PrintQueue })
$groupBox.Controls.Add($btnFix3)

# Tombol Fix 4
$btnFix4 = New-Object System.Windows.Forms.Button
$btnFix4.Location = New-Object System.Drawing.Point(340, 110)
$btnFix4.Size = New-Object System.Drawing.Size(300, 30)
$btnFix4.Text = "Fix 4: Set Printer Permissions"
$btnFix4.Add_Click({ Set-PrinterPermissions })
$groupBox.Controls.Add($btnFix4)

# Tombol Fix 5
$btnFix5 = New-Object System.Windows.Forms.Button
$btnFix5.Location = New-Object System.Drawing.Point(20, 150)
$btnFix5.Size = New-Object System.Drawing.Size(300, 30)
$btnFix5.Text = "Fix 5: Enable Firewall Sharing"
$btnFix5.Add_Click({ Enable-FileAndPrinterSharing })
$groupBox.Controls.Add($btnFix5)

# Tombol Fix 6
$btnFix6 = New-Object System.Windows.Forms.Button
$btnFix6.Location = New-Object System.Drawing.Point(340, 150)
$btnFix6.Size = New-Object System.Drawing.Size(300, 30)
$btnFix6.Text = "Fix 6: Konfigurasi SMB"
$btnFix6.Add_Click({ Set-SMBSettings })
$groupBox.Controls.Add($btnFix6)

# Label Log
$labelLog = New-Object System.Windows.Forms.Label
$labelLog.Location = New-Object System.Drawing.Point(10, 350)
$labelLog.Size = New-Object System.Drawing.Size(660, 20)
$labelLog.Text = "Log Aktivitas:"
$labelLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelLog)

# TextBox Log
$textBoxLog = New-Object System.Windows.Forms.TextBox
$textBoxLog.Location = New-Object System.Drawing.Point(10, 375)
$textBoxLog.Size = New-Object System.Drawing.Size(660, 140)
$textBoxLog.Multiline = $true
$textBoxLog.ScrollBars = "Vertical"
$textBoxLog.ReadOnly = $true
$textBoxLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($textBoxLog)

# Tombol Close
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(570, 525)
$btnClose.Size = New-Object System.Drawing.Size(100, 30)
$btnClose.Text = "Tutup"
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

# Tampilkan pesan awal
Write-Log "Printer Sharing Fix Tool - SERVER Side"
Write-Log "Folder Backup: $backupFolder"
Write-Log "Siap untuk memperbaiki masalah printer sharing"
Write-Log "REKOMENDASI: Backup registry sebelum melakukan perbaikan!"
Write-Log ""

# Tampilkan form
$form.ShowDialog()
