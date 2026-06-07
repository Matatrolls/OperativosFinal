#!/bin/bash

function get_system_users_last_login() {
    echo "========================================="
    echo " Usuarios del Sistema y Ultimo Login"
    echo "========================================="
    awk -F':' '{ if ($3 >= 1000 || $1 == "root") print $1 }' /etc/passwd | while read u; do
        last_info=$(lastlog -u "$u" | awk 'NR==2 {print $0}')
        if [[ "$last_info" == *"Never"* ]] || [[ "$last_info" == *"Nunca"* ]] || [[ -z "${last_info// }" ]]; then
            echo "Usuario: $u | Ultimo Login: Nunca"
        else
            login_details=$(echo "$last_info" | awk '{$1=""; print $0}' | sed -e 's/^[[:space:]]*//')
            echo "Usuario: $u | Ultimo Login: $login_details"
        fi
    done
}

function get_disk_storage_info() {
    echo "========================================="
    echo " Informacion de Discos Conectados"
    echo "========================================="
    df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null | tail -n +2 | while read -r filesystem total used free pcent mount; do
        echo "Filesystem: $filesystem | Montado en: $mount | Tamano Total: $total bytes | Espacio Libre: $free bytes"
    done
}
