# Printer Sharing Fix - CLIENT Side
# Mengatasi masalah printer sharing di Windows 10/11 untuk komputer CLIENT
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
        $backupFile = "$backupFolder\PrinterRegistry_Client_$timestamp.reg"
        
        # Backup registry keys
        reg export "HKLM\System\CurrentControlSet\Control\Print" $backupFile /y | Out-Null
        
        Write-Log "[OK] Backup registry berhasil: $backupFile"
        Write-Log "[INFO] Lokasi: $backupFolder"
        
        # Simpan info backup
        $backupInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Type = "Client"
            File = $backupFile
        }
        $backupInfo | ConvertTo-Json | Out-File "$backupFolder\LastBackup_Client.json"
        
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
        $backupFiles = Get-ChildItem -Path $backupFolder -Filter "PrinterRegistry_Client_*.reg" | Sort-Object LastWriteTime -Descending
        
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

# Fungsi Fix 1: Nonaktifkan RPC over SMB Client (Fix untuk 0x0000011b)
function Fix-RPCoverSMBClient {
    Write-Log "=== Memulai Fix: Nonaktifkan RPC over SMB Client (Error 0x0000011b) ==="
    try {
        $regPath = "HKLM:\System\CurrentControlSet\Control\Print"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "RpcAuthnLevelPrivacyEnabled" -Value 0 -Type DWord
        Write-Log "[OK] Registry key berhasil diset: RpcAuthnLevelPrivacyEnabled = 0"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 2: Hapus Printer yang Bermasalah
function Remove-ProblematicPrinters {
    Write-Log "=== Memulai: Hapus Printer yang Bermasalah ==="
    try {
        $printers = Get-Printer | Where-Object { $_.Type -eq "Connection" }
        if ($printers.Count -eq 0) {
            Write-Log "[INFO] Tidak ada network printer yang terdeteksi"
            return $true
        }
        
        Write-Log "Ditemukan $($printers.Count) network printer(s):"
        foreach ($printer in $printers) {
            Write-Log "  - $($printer.Name)"
        }
        
        $result = [System.Windows.Forms.MessageBox]::Show("Hapus semua network printer yang terdeteksi?`n`nAnda bisa menambahkannya kembali setelah fix selesai.", "Konfirmasi", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            foreach ($printer in $printers) {
                Remove-Printer -Name $printer.Name -ErrorAction SilentlyContinue
                Write-Log "[OK] Printer dihapus: $($printer.Name)"
            }
        }
        return $true
    } catch {
        Write-Log "[ERROR] Gagal hapus printer: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 3: Restart Print Spooler Service
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

# Fungsi Fix 4: Bersihkan Print Queue
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

# Fungsi Fix 5: Set Point and Print Restrictions
function Set-PointAndPrintClient {
    Write-Log "=== Memulai: Set Point and Print Client ==="
    try {
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $regPath -Name "RestrictDriverInstallationToAdministrators" -Value 0 -Type DWord
        Set-ItemProperty -Path $regPath -Name "NoWarningNoElevationOnInstall" -Value 1 -Type DWord
        Set-ItemProperty -Path $regPath -Name "UpdatePromptSettings" -Value 2 -Type DWord
        Set-ItemProperty -Path $regPath -Name "TrustedServers" -Value 1 -Type DWord
        
        Write-Log "[OK] Point and Print client berhasil dikonfigurasi"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal set Point and Print: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 6: Perbaiki Network Discovery
function Fix-NetworkDiscovery {
    Write-Log "=== Memulai: Perbaiki Network Discovery ==="
    try {
        netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes | Out-Null
        netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes | Out-Null
        Write-Log "[OK] Network Discovery dan File Sharing diaktifkan"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal enable network discovery: $($_.Exception.Message)"
        return $false
    }
}

# Fungsi Fix 7: Reset Printer Driver Cache
function Reset-PrinterDriverCache {
    Write-Log "=== Memulai: Reset Printer Driver Cache ==="
    try {
        Stop-Service -Name Spooler -Force
        Start-Sleep -Seconds 2
        
        $driverStore = "$env:SystemRoot\System32\spool\drivers"
        Write-Log "[INFO] Driver store location: $driverStore"
        
        Start-Service -Name Spooler
        Write-Log "[OK] Print Spooler di-restart untuk refresh driver cache"
        return $true
    } catch {
        Write-Log "[ERROR] Gagal reset cache: $($_.Exception.Message)"
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        return $false
    }
}

# Fungsi Fix 8: Tambah Printer Manual
function Add-NetworkPrinter {
    Write-Log "=== Memulai: Tambah Network Printer Manual ==="
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Tambah Network Printer"
    $inputForm.Size = New-Object System.Drawing.Size(400, 150)
    $inputForm.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(360, 20)
    $label.Text = "Masukkan path printer (contoh: \\SERVER\PrinterName):"
    $inputForm.Controls.Add($label)
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 45)
    $textBox.Size = New-Object System.Drawing.Size(360, 20)
    $inputForm.Controls.Add($textBox)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(210, 75)
    $okButton.Size = New-Object System.Drawing.Size(75, 25)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($okButton)
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(295, 75)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 25)
    $cancelButton.Text = "Batal"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($cancelButton)
    
    $inputForm.AcceptButton = $okButton
    $inputForm.CancelButton = $cancelButton
    
    $result = $inputForm.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $printerPath = $textBox.Text
        if ([string]::IsNullOrWhiteSpace($printerPath)) {
            Write-Log "[ERROR] Path printer tidak boleh kosong"
            return $false
        }
        
        try {
            Write-Log "Mencoba menambahkan printer: $printerPath"
            Add-Printer -ConnectionName $printerPath
            Write-Log "[OK] Printer berhasil ditambahkan: $printerPath"
            return $true
        } catch {
            Write-Log "[ERROR] Gagal menambahkan printer: $($_.Exception.Message)"
            Write-Log "[INFO] Pastikan server dapat diakses dan printer di-share dengan benar"
            return $false
        }
    }
}

# Fungsi Fix All
function Fix-All {
    Write-Log "`r`n========================================="
    Write-Log "MEMULAI PERBAIKAN LENGKAP - CLIENT SIDE"
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
    $btnFix7.Enabled = $false
    $btnFix8.Enabled = $false
    $btnBackup.Enabled = $false
    $btnRestore.Enabled = $false
    
    Fix-RPCoverSMBClient
    Start-Sleep -Seconds 1
    Set-PointAndPrintClient
    Start-Sleep -Seconds 1
    Fix-NetworkDiscovery
    Start-Sleep -Seconds 1
    Remove-ProblematicPrinters
    Start-Sleep -Seconds 1
    Clear-PrintQueue
    Start-Sleep -Seconds 1
    Reset-PrinterDriverCache
    Start-Sleep -Seconds 1
    Restart-PrintSpooler
    
    Write-Log "`r`n[SELESAI] Semua perbaikan telah dijalankan"
    Write-Log "[PENTING] Restart komputer untuk menerapkan semua perubahan"
    Write-Log "[INFO] Setelah restart, tambahkan printer kembali dari server"
    
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
    $btnFix7.Enabled = $true
    $btnFix8.Enabled = $true
    $btnBackup.Enabled = $true
    $btnRestore.Enabled = $true
}

# Buat Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Printer Sharing Fix - CLIENT"
$form.Size = New-Object System.Drawing.Size(700, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Label Header
$labelHeader = New-Object System.Windows.Forms.Label
$labelHeader.Location = New-Object System.Drawing.Point(10, 10)
$labelHeader.Size = New-Object System.Drawing.Size(660, 40)
$labelHeader.Text = "Perbaikan Masalah Printer Sharing - KOMPUTER CLIENT`nError: 0x0000011b, 0x000003e3, 0x00000709, 0x00000bcb"
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
$groupBox.Size = New-Object System.Drawing.Size(660, 250)
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
$btnFix1.Add_Click({ Fix-RPCoverSMBClient; Restart-PrintSpooler })
$groupBox.Controls.Add($btnFix1)

# Tombol Fix 2
$btnFix2 = New-Object System.Windows.Forms.Button
$btnFix2.Location = New-Object System.Drawing.Point(340, 70)
$btnFix2.Size = New-Object System.Drawing.Size(300, 30)
$btnFix2.Text = "Fix 2: Hapus Printer Bermasalah"
$btnFix2.Add_Click({ Remove-ProblematicPrinters })
$groupBox.Controls.Add($btnFix2)

# Tombol Fix 3
$btnFix3 = New-Object System.Windows.Forms.Button
$btnFix3.Location = New-Object System.Drawing.Point(20, 110)
$btnFix3.Size = New-Object System.Drawing.Size(300, 30)
$btnFix3.Text = "Fix 3: Restart Print Spooler"
$btnFix3.Add_Click({ Restart-PrintSpooler })
$groupBox.Controls.Add($btnFix3)

# Tombol Fix 4
$btnFix4 = New-Object System.Windows.Forms.Button
$btnFix4.Location = New-Object System.Drawing.Point(340, 110)
$btnFix4.Size = New-Object System.Drawing.Size(300, 30)
$btnFix4.Text = "Fix 4: Bersihkan Print Queue"
$btnFix4.Add_Click({ Clear-PrintQueue })
$groupBox.Controls.Add($btnFix4)

# Tombol Fix 5
$btnFix5 = New-Object System.Windows.Forms.Button
$btnFix5.Location = New-Object System.Drawing.Point(20, 150)
$btnFix5.Size = New-Object System.Drawing.Size(300, 30)
$btnFix5.Text = "Fix 5: Set Point and Print"
$btnFix5.Add_Click({ Set-PointAndPrintClient })
$groupBox.Controls.Add($btnFix5)

# Tombol Fix 6
$btnFix6 = New-Object System.Windows.Forms.Button
$btnFix6.Location = New-Object System.Drawing.Point(340, 150)
$btnFix6.Size = New-Object System.Drawing.Size(300, 30)
$btnFix6.Text = "Fix 6: Network Discovery"
$btnFix6.Add_Click({ Fix-NetworkDiscovery })
$groupBox.Controls.Add($btnFix6)

# Tombol Fix 7
$btnFix7 = New-Object System.Windows.Forms.Button
$btnFix7.Location = New-Object System.Drawing.Point(20, 190)
$btnFix7.Size = New-Object System.Drawing.Size(300, 30)
$btnFix7.Text = "Fix 7: Reset Driver Cache"
$btnFix7.Add_Click({ Reset-PrinterDriverCache })
$groupBox.Controls.Add($btnFix7)

# Tombol Fix 8
$btnFix8 = New-Object System.Windows.Forms.Button
$btnFix8.Location = New-Object System.Drawing.Point(340, 190)
$btnFix8.Size = New-Object System.Drawing.Size(300, 30)
$btnFix8.Text = "Fix 8: Tambah Printer Manual"
$btnFix8.BackColor = [System.Drawing.Color]::LightBlue
$btnFix8.Add_Click({ Add-NetworkPrinter })
$groupBox.Controls.Add($btnFix8)

# Label Log
$labelLog = New-Object System.Windows.Forms.Label
$labelLog.Location = New-Object System.Drawing.Point(10, 400)
$labelLog.Size = New-Object System.Drawing.Size(660, 20)
$labelLog.Text = "Log Aktivitas:"
$labelLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($labelLog)

# TextBox Log
$textBoxLog = New-Object System.Windows.Forms.TextBox
$textBoxLog.Location = New-Object System.Drawing.Point(10, 425)
$textBoxLog.Size = New-Object System.Drawing.Size(660, 140)
$textBoxLog.Multiline = $true
$textBoxLog.ScrollBars = "Vertical"
$textBoxLog.ReadOnly = $true
$textBoxLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($textBoxLog)

# Tombol Close
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(570, 575)
$btnClose.Size = New-Object System.Drawing.Size(100, 30)
$btnClose.Text = "Tutup"
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

# Tampilkan pesan awal
Write-Log "Printer Sharing Fix Tool - CLIENT Side"
Write-Log "Folder Backup: $backupFolder"
Write-Log "Siap untuk memperbaiki masalah printer sharing"
Write-Log "REKOMENDASI: Backup registry sebelum melakukan perbaikan!"
Write-Log ""

# Tampilkan form
$form.ShowDialog()
