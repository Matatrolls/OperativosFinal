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


# OPCION 3 - Matthew
# Muestra los 10 archivos más grandes en un filesystem/ruta
function get_top10_largest_files() {
    echo "========================================="
    echo " Top 10 Archivos Mas Grandes"
    echo "========================================="

    # Solicitar ruta al usuario
    read -rp "Ingrese la ruta o filesystem a analizar (ej: /home o /): " target_path

    # Validar que la ruta existe
    if [[ ! -d "$target_path" ]]; then
        echo "ERROR: La ruta '$target_path' no existe o no es un directorio."
        return 1
    fi

    echo ""
    echo "Analizando archivos en: $target_path"
    echo "Por favor espere..."
    echo ""
    find "$target_path" -xdev -type f -printf "%s\t%p\n" 2>/dev/null \
        | sort -rn \
        | head -10 \
        | while IFS=$'\t' read -r size filepath; do
            # Formatear tamaño con separadores de miles para legibilidad
            size_fmt=$(printf "%'d" "$size")
            echo "Tamano: ${size_fmt} bytes | Ruta: ${filepath}"
          done

    echo ""
    echo "Busqueda completada."
}


# OPCION 4 - Matthew
# Muestra memoria RAM libre y swap en uso (bytes y porcentaje)

function get_memory_and_swap_info() {
    echo "========================================="
    echo " Monitoreo de Memoria RAM y Swap"
    echo "========================================="

    # Leer valores desde /proc/meminfo (en kibibytes)
    local mem_total_kb mem_free_kb mem_available_kb
    local swap_total_kb swap_free_kb swap_used_kb

    mem_total_kb=$(awk '/^MemTotal:/{print $2}'     /proc/meminfo)
    mem_free_kb=$(awk '/^MemFree:/{print $2}'       /proc/meminfo)
    mem_available_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    swap_total_kb=$(awk '/^SwapTotal:/{print $2}'   /proc/meminfo)
    swap_free_kb=$(awk '/^SwapFree:/{print $2}'     /proc/meminfo)

    # Convertir kibibytes a bytes (1 KiB = 1024 bytes)
    local mem_total_bytes mem_free_bytes mem_available_bytes
    local swap_total_bytes swap_used_bytes swap_free_bytes

    mem_total_bytes=$(( mem_total_kb     * 1024 ))
    mem_free_bytes=$(( mem_free_kb       * 1024 ))
    mem_available_bytes=$(( mem_available_kb * 1024 ))
    swap_total_bytes=$(( swap_total_kb   * 1024 ))
    swap_free_kb=${swap_free_kb:-0}
    swap_used_kb=$(( swap_total_kb - swap_free_kb ))
    swap_used_bytes=$(( swap_used_kb   * 1024 ))
    swap_free_bytes=$(( swap_free_kb   * 1024 ))

    # Calcular porcentajes (con awk para manejar decimales)
    local mem_free_pct mem_available_pct swap_used_pct swap_free_pct

    if [[ "$mem_total_kb" -gt 0 ]]; then
        mem_free_pct=$(awk "BEGIN {printf \"%.2f\", ($mem_free_kb / $mem_total_kb) * 100}")
        mem_available_pct=$(awk "BEGIN {printf \"%.2f\", ($mem_available_kb / $mem_total_kb) * 100}")
    else
        mem_free_pct="N/A"
        mem_available_pct="N/A"
    fi

    if [[ "$swap_total_kb" -gt 0 ]]; then
        swap_used_pct=$(awk "BEGIN {printf \"%.2f\", ($swap_used_kb / $swap_total_kb) * 100}")
        swap_free_pct=$(awk "BEGIN {printf \"%.2f\", ($swap_free_kb / $swap_total_kb) * 100}")
    else
        swap_used_pct="N/A"
        swap_free_pct="N/A"
    fi

    # Mostrar resultados — Memoria RAM
    echo ""
    echo "----- Memoria RAM -----"
    printf "  Total de RAM          : %'d bytes\n"     "$mem_total_bytes"
    printf "  RAM Libre (MemFree)   : %'d bytes  (%s%%)\n" "$mem_free_bytes"     "$mem_free_pct"
    printf "  RAM Disponible*       : %'d bytes  (%s%%)\n" "$mem_available_bytes" "$mem_available_pct"
    echo "  (*MemAvailable incluye cache/buffers recuperables)"

    # Mostrar resultados — Swap
    echo ""
    echo "----- Espacio Swap -----"
    if [[ "$swap_total_kb" -eq 0 ]]; then
        echo "  Sin espacio swap configurado en este sistema."
    else
        printf "  Total de Swap         : %'d bytes\n"     "$swap_total_bytes"
        printf "  Swap en Uso           : %'d bytes  (%s%%)\n" "$swap_used_bytes" "$swap_used_pct"
        printf "  Swap Libre            : %'d bytes  (%s%%)\n" "$swap_free_bytes" "$swap_free_pct"
    fi

    echo ""
}






