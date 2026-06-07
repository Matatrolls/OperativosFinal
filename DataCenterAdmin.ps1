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
}
