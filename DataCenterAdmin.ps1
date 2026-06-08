class DataCenterAdmin {
    [void] GetSystemUsersLastLogin() {
        Write-Host "========================================="
        Write-Host " Usuarios del Sistema y Ultimo Login"
        Write-Host "========================================="
        try {
            $users = Get-LocalUser | Select-Object Name, Enabled, LastLogon
            foreach ($user in $users) {
                $status = if ($user.Enabled) { "Activo" } else { "Inactivo" }
                $lastLogon = if ($null -ne $user.LastLogon) { $user.LastLogon.ToString("yyyy-MM-dd HH:mm:ss") } else { "Nunca / Desconocido" }
                Write-Host "Usuario: $($user.Name) | Estado: $status | Ultimo Login: $lastLogon"
            }
        } catch {
            Write-Host "Error al obtener usuarios locales."
        }
    }

    [void] GetDiskStorageInfo() {
        Write-Host "========================================="
        Write-Host " Informacion de Discos Conectados"
        Write-Host "========================================="
        $disks = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -or $_.DriveType -eq 2 }
        foreach ($disk in $disks) {
            $totalBytes = if ($disk.Size) { $disk.Size } else { 0 }
            $freeBytes = if ($disk.FreeSpace) { $disk.FreeSpace } else { 0 }
            Write-Host "Unidad: $($disk.DeviceID) | Nombre: $($disk.VolumeName) | Tamano Total: $totalBytes bytes | Espacio Libre: $freeBytes bytes"
        }
    }

    [void] GetTop10LargestFiles() {
        Write-Host "========================================="
        Write-Host " Top 10 Archivos Mas Grandes"
        Write-Host "========================================="

        # Solicitar ruta al usuario
        $targetPath = Read-Host "Ingrese la ruta o disco a analizar (ej: C:\Users o /home)"

        # Validar que la ruta existe
        if (-not (Test-Path -Path $targetPath -PathType Container)) {
            Write-Host "ERROR: La ruta '$targetPath' no existe o no es un directorio."
            return
        }

        Write-Host ""
        Write-Host "Analizando archivos en: $targetPath"
        Write-Host "Por favor espere..."
        Write-Host ""

        try {
            # Recorrer recursivamente todos los archivos, ordenar por tamaño
            # y tomar los 10 más grandes
            $top10 = Get-ChildItem -Path $targetPath -Recurse -File -ErrorAction SilentlyContinue |
                     Sort-Object -Property Length -Descending |
                     Select-Object -First 10

            if ($top10.Count -eq 0) {
                Write-Host "No se encontraron archivos en la ruta especificada."
            } else {
                foreach ($file in $top10) {
                    $sizeFormatted = "{0:N0}" -f $file.Length
                    Write-Host "Tamano: $sizeFormatted bytes | Ruta: $($file.FullName)"
                }
            }
        } catch {
            Write-Host "Error al recorrer el directorio: $_"
        }

        Write-Host ""
        Write-Host "Busqueda completada."
    }


    [void] GetMemoryAndSwapInfo() {
        Write-Host "========================================="
        Write-Host " Monitoreo de Memoria RAM y Swap"
        Write-Host "========================================="
        Write-Host ""

        try {
            # --- Memoria RAM via CIM/WMI ---
            $os = Get-CimInstance -ClassName Win32_OperatingSystem

            # Win32_OperatingSystem reporta en KiB, convertir a bytes
            $totalRamBytes     = $os.TotalVisibleMemorySize * 1024
            $freeRamBytes      = $os.FreePhysicalMemory     * 1024
            $usedRamBytes      = $totalRamBytes - $freeRamBytes

            # Porcentajes
            $freeRamPct  = if ($totalRamBytes -gt 0) { [math]::Round(($freeRamBytes  / $totalRamBytes) * 100, 2) } else { "N/A" }
            $usedRamPct  = if ($totalRamBytes -gt 0) { [math]::Round(($usedRamBytes  / $totalRamBytes) * 100, 2) } else { "N/A" }

            Write-Host "----- Memoria RAM -----"
            Write-Host ("  Total de RAM        : {0:N0} bytes" -f $totalRamBytes)
            Write-Host ("  RAM en Uso          : {0:N0} bytes  ({1}%)" -f $usedRamBytes,  $usedRamPct)
            Write-Host ("  RAM Libre           : {0:N0} bytes  ({1}%)" -f $freeRamBytes,  $freeRamPct)

            # --- Swap / Archivo de paginacion ---
            Write-Host ""
            Write-Host "----- Espacio Swap (Paginacion) -----"

            $pageFiles = Get-CimInstance -ClassName Win32_PageFileUsage -ErrorAction SilentlyContinue

            if ($null -eq $pageFiles -or @($pageFiles).Count -eq 0) {
                Write-Host "  No hay archivo de paginacion (swap) configurado."
            } else {
                $totalSwapMB = 0
                $usedSwapMB  = 0

                foreach ($pf in $pageFiles) {
                    # AllocatedBaseSize y CurrentUsage vienen en MiB
                    $totalSwapMB += $pf.AllocatedBaseSize
                    $usedSwapMB  += $pf.CurrentUsage
                }

                $freeSwapMB      = $totalSwapMB - $usedSwapMB
                $totalSwapBytes  = $totalSwapMB * 1MB
                $usedSwapBytes   = $usedSwapMB  * 1MB
                $freeSwapBytes   = $freeSwapMB  * 1MB

                $usedSwapPct = if ($totalSwapMB -gt 0) { [math]::Round(($usedSwapMB  / $totalSwapMB) * 100, 2) } else { "N/A" }
                $freeSwapPct = if ($totalSwapMB -gt 0) { [math]::Round(($freeSwapMB  / $totalSwapMB) * 100, 2) } else { "N/A" }

                Write-Host ("  Total Swap          : {0:N0} bytes" -f $totalSwapBytes)
                Write-Host ("  Swap en Uso         : {0:N0} bytes  ({1}%)" -f $usedSwapBytes, $usedSwapPct)
                Write-Host ("  Swap Libre          : {0:N0} bytes  ({1}%)" -f $freeSwapBytes, $freeSwapPct)
            }

        } catch {
            Write-Host "Error al obtener informacion de memoria: $_"
        }

        Write-Host ""
    }

    [void] PerformDirectoryBackup() {
        Write-Host "========================================="
        Write-Host " Copia de Seguridad (Backup)"
        Write-Host "========================================="

        # 1. Solicitar directorio de origen
        $sourceDir = Read-Host "Ingrese la ruta del directorio origen que desea respaldar"

        # Validar que exista y sea un directorio accesible
        if (-not (Test-Path -Path $sourceDir -PathType Container)) {
            Write-Host "ERROR: El directorio origen '$sourceDir' no existe o no es accesible."
            return
        }

        # 2. Identificar memoria USB conectada
        Write-Host "Buscando dispositivos USB/removibles conectados..."
        $usbDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
        $destUsb = ""

        if ($null -ne $usbDrives -and @($usbDrives).Count -gt 0) {
            Write-Host "Se encontraron los siguientes dispositivos extraíbles:"
            $i = 1
            foreach ($drive in $usbDrives) {
                Write-Host "  [$i] $($drive.DeviceID) ($($drive.VolumeName))"
                $i++
            }
            Write-Host "  [$i] Ingresar ruta personalizada (Simulación/Fallback)"

            $usbChoice = Read-Host "Seleccione el dispositivo para el respaldo [1-$i]"
            if ($usbChoice -gt 0 -and $usbChoice -lt $i) {
                $destUsb = $usbDrives[$usbChoice - 1].DeviceID
                $destUsb = "$destUsb\"
            } else {
                $customDest = Read-Host "Ingrese la ruta de destino personalizada para simular el USB"
                $destUsb = $customDest
            }
        } else {
            Write-Host "AVISO: No se detectaron memorias USB conectadas automáticamente."
            $destUsb = Read-Host "Ingrese la ruta del directorio que actuará como USB (Simulación/Fallback)"
        }

        # Validar que la ruta destino no esté vacía
        if ([string]::IsNullOrWhiteSpace($destUsb)) {
            Write-Host "ERROR: No se especificó una ruta de destino válida."
            return
        }

        if (-not (Test-Path -Path $destUsb -PathType Container)) {
            try {
                $null = New-Item -ItemType Directory -Path $destUsb -Force -ErrorAction Stop
            } catch {
                Write-Host "ERROR: El destino '$destUsb' no existe y no se pudo crear: $_"
                return
            }
        }

        # 3. Verificar espacio suficiente
        # Calcular tamaño del origen en bytes
        $sourceSize = 0
        try {
            $files = Get-ChildItem -Path $sourceDir -Recurse -File -ErrorAction SilentlyContinue
            if ($null -ne $files) {
                $sourceSize = ($files | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $sourceSize) { $sourceSize = 0 }
            }
        } catch {
            $sourceSize = 0
        }

        # Obtener espacio libre del destino
        $destFree = 999999999999
        try {
            $driveLetter = [System.IO.Path]::GetPathRoot($destUsb)
            if ($driveLetter.EndsWith("\")) {
                $driveLetter = $driveLetter.Substring(0, $driveLetter.Length - 1)
            }
            if ($driveLetter.EndsWith(":")) {
                $logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = '$driveLetter'" -ErrorAction SilentlyContinue
                if ($null -ne $logicalDisk) {
                    $destFree = $logicalDisk.FreeSpace
                }
            }
        } catch {
            $destFree = 999999999999
        }
        if ($null -eq $destFree) { $destFree = 999999999999 }

        $sourceFmt = "{0:N0}" -f $sourceSize
        $destFmt = "{0:N0}" -f $destFree

        Write-Host "Espacio requerido: $sourceFmt bytes"
        Write-Host "Espacio disponible: $destFmt bytes"

        if ($destFree -ne 999999999999 -and $destFree -lt $sourceSize) {
            Write-Host "ERROR: Espacio insuficiente en el destino para realizar el respaldo."
            return
        }

        # 4. Crear carpeta de respaldo con fecha y hora
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $backupDirName = "respaldo_$timestamp"
        $backupDir = Join-Path $destUsb $backupDirName

        Write-Host "Creando carpeta de respaldo en: $backupDir"
        try {
            $null = New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop
        } catch {
            Write-Host "ERROR: No se pudo crear la carpeta de respaldo: $_"
            return
        }

        # 5. Copiar archivos y directorios conservando estructura
        Write-Host "Copiando archivos..."
        try {
            Copy-Item -Path "$sourceDir\*" -Destination $backupDir -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Advertencia al copiar algunos archivos: $_"
        }

        # 6. Generar catálogo
        $catalogFile = Join-Path $backupDir "catalogo.txt"
        $dateStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $header = "Catálogo de Respaldo - $dateStr`r`n" +
                  "==================================================`r`n" +
                  "Directorio de origen: $sourceDir`r`n" +
                  "Archivo | Fecha de Ultima Modificacion`r`n" +
                  "--------------------------------------------------`r`n"
        
        try {
            Set-Content -Path $catalogFile -Value $header -Encoding Utf8 -ErrorAction Stop

            $backedFiles = Get-ChildItem -Path $backupDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "catalogo.txt" }
            if ($null -ne $backedFiles) {
                foreach ($file in $backedFiles) {
                    $relPath = $file.FullName.Substring($backupDir.Length + 1)
                    $modTime = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                    Add-Content -Path $catalogFile -Value "$relPath | $modTime" -Encoding Utf8
                }
            }
            Write-Host ""
            Write-Host "¡Respaldo completado exitosamente!"
            Write-Host "Carpeta de respaldo: $backupDir"
            Write-Host "Catálogo creado: $catalogFile"
        } catch {
            Write-Host "Error al crear el catálogo de respaldo: $_"
        }
    }
}

# --- MENU PRINCIPAL ---
$admin = [DataCenterAdmin]::new()

do {
    Clear-Host
    Write-Host "=========================================================="
    Write-Host "     MENU PRINCIPAL - DATACENTER ADMIN (POWERSHELL)"
    Write-Host "=========================================================="
    Write-Host " 1. Usuarios del sistema y ultimo login"
    Write-Host " 2. Filesystems o discos conectados (Tamano y espacio libre)"
    Write-Host " 3. Mostrar los 10 archivos mas grandes en una ruta"
    Write-Host " 4. Monitoreo de memoria RAM y Swap (Bytes y porcentaje)"
    Write-Host " 5. Copia de seguridad (Backup) a memoria USB"
    Write-Host " 6. Salir"
    Write-Host "=========================================================="
    $opcion = Read-Host "Seleccione una opcion [1-6]"
    Write-Host ""
    switch ($opcion) {
        "1" { $admin.GetSystemUsersLastLogin() }
        "2" { $admin.GetDiskStorageInfo() }
        "3" { $admin.GetTop10LargestFiles() }
        "4" { $admin.GetMemoryAndSwapInfo() }
        "5" { $admin.PerformDirectoryBackup() }
        "6" { Write-Host "Saliendo de DataCenterAdmin. ¡Hasta luego!"; exit }
        Default { Write-Host "Opcion invalida. Intente de nuevo." }
    }
    Write-Host ""
    Read-Host "Presione [Enter] para continuar..."
} while ($true)
