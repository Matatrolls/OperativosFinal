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
}
