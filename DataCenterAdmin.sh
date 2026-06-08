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


# OPCION 5 - Sebastian Cosme
# Función para realizar respaldo de un directorio especificado a una memoria USB
function perform_directory_backup() {
    echo "========================================="
    echo " Copia de Seguridad (Backup)"
    echo "========================================="

    # 1. Solicitar directorio de origen
    read -rp "Ingrese la ruta del directorio origen que desea respaldar: " source_dir

    # Validar que exista y sea un directorio accesible
    if [[ ! -d "$source_dir" ]]; then
        echo "ERROR: El directorio origen '$source_dir' no existe o no es accesible."
        return 1
    fi

    # 2. Identificar memoria USB conectada
    echo "Buscando dispositivos USB/removibles conectados..."
    usb_mounts=()

    # Método 1: lsblk (más confiable en Linux moderno)
    if command -v lsblk >/dev/null 2>&1; then
        while read -r mountpoint rm; do
            if [[ "$rm" == "1" && -n "$mountpoint" && "$mountpoint" != "/" ]]; then
                usb_mounts+=("$mountpoint")
            fi
        done < <(lsblk -rn -o MOUNTPOINT,RM 2>/dev/null)
    fi

    # Método 2: Buscar en directorios típicos de montaje de medios (/media o /run/media)
    if [ ${#usb_mounts[@]} -eq 0 ]; then
        for d in /media/* /media/*/* /run/media/*/*; do
            if [ -d "$d" ] && mountpoint -q "$d" 2>/dev/null; then
                usb_mounts+=("$d")
            fi
        done
    fi

    local dest_usb=""

    if [ ${#usb_mounts[@]} -gt 0 ]; then
        echo "Se encontraron los siguientes dispositivos extraíbles:"
        for i in "${!usb_mounts[@]}"; do
            echo "  [$((i+1))] ${usb_mounts[i]}"
        done
        echo "  [$(( ${#usb_mounts[@]} + 1 ))] Ingresar ruta personalizada (Simulación/Fallback)"

        read -rp "Seleccione el dispositivo para el respaldo [1-$(( ${#usb_mounts[@]} + 1 ))]: " usb_choice
        if [[ "$usb_choice" -gt 0 && "$usb_choice" -le "${#usb_mounts[@]}" ]]; then
            dest_usb="${usb_mounts[$((usb_choice-1))]}"
        else
            read -rp "Ingrese la ruta de destino personalizada para simular el USB: " custom_dest
            dest_usb="$custom_dest"
        fi
    else
        echo "AVISO: No se detectaron memorias USB conectadas automáticamente."
        read -rp "Ingrese la ruta del directorio que actuará como USB (Simulación/Fallback): " dest_usb
    fi

    # Validar que la ruta destino no esté vacía y que exista
    if [[ -z "$dest_usb" ]]; then
        echo "ERROR: No se especificó una ruta de destino válida."
        return 1
    fi

    if [[ ! -d "$dest_usb" ]]; then
        # Intentar crear el directorio si no existe para la simulación
        mkdir -p "$dest_usb" 2>/dev/null
        if [[ ! -d "$dest_usb" ]]; then
            echo "ERROR: El destino '$dest_usb' no existe y no se pudo crear."
            return 1
        fi
    fi

    # 3. Verificar espacio suficiente
    # Calcular tamaño del origen en bytes
    local source_size
    source_size=$(du -sb "$source_dir" 2>/dev/null | awk '{print $1}')
    if [[ -z "$source_size" ]]; then
        source_size=$(find "$source_dir" -type f -printf "%s\n" 2>/dev/null | awk '{s+=$1} END {print s}')
    fi
    source_size=${source_size:-0}

    # Obtener espacio libre del destino en bytes
    local dest_free
    dest_free=$(df -P -B1 "$dest_usb" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -z "$dest_free" ]]; then
        # Fallback usando df -k
        dest_free=$(df -k "$dest_usb" 2>/dev/null | tail -n 1 | awk '{print $4}')
        if [[ -n "$dest_free" ]]; then
            dest_free=$(( dest_free * 1024 ))
        fi
    fi
    # Si sigue vacío (por ejemplo en un directorio montado especial o simulación), asumir suficiente espacio para pruebas
    dest_free=${dest_free:-999999999999}

    local source_fmt
    source_fmt=$(printf "%'d" "$source_size")
    local dest_fmt
    dest_fmt=$(printf "%'d" "$dest_free")

    echo "Espacio requerido: $source_fmt bytes"
    echo "Espacio disponible: $dest_fmt bytes"

    if [ "$dest_free" -ne 999999999999 ] && [ "$dest_free" -lt "$source_size" ]; then
        echo "ERROR: Espacio insuficiente en el destino para realizar el respaldo."
        return 1
    fi

    # 4. Crear carpeta de respaldo con fecha y hora
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${dest_usb}/respaldo_${timestamp}"

    echo "Creando carpeta de respaldo en: $backup_dir"
    mkdir -p "$backup_dir"
    if [[ $? -ne 0 ]]; then
        echo "ERROR: No se pudo crear la carpeta de respaldo."
        return 1
    fi

    # 5. Copiar archivos y directorios conservando estructura
    echo "Copiando archivos..."
    cp -rp "$source_dir"/* "$backup_dir/" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        # Fallback en caso de que el wildcard falle (por ejemplo, directorio vacío)
        cp -rp "$source_dir" "$backup_dir/" 2>/dev/null
    fi

    # 6. Generar el catálogo de archivos respaldados
    local catalog_file="${backup_dir}/catalogo.txt"
    echo "Catálogo de Respaldo - $(date '+%Y-%m-%d %H:%M:%S')" > "$catalog_file"
    echo "==================================================" >> "$catalog_file"
    echo "Directorio de origen: $source_dir" >> "$catalog_file"
    echo "Archivo | Fecha de Ultima Modificacion" >> "$catalog_file"
    echo "--------------------------------------------------" >> "$catalog_file"

    find "$backup_dir" -type f ! -name "catalogo.txt" 2>/dev/null | while read -r file; do
        # Obtener ruta relativa al directorio de respaldo
        local rel_path="${file#$backup_dir/}"
        local mod_time
        mod_time=$(date -r "$file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
        if [[ -z "$mod_time" ]]; then
            mod_time=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
        fi
        mod_time=${mod_time:-"Desconocida"}
        echo "$rel_path | $mod_time" >> "$catalog_file"
    done

    echo ""
    echo "¡Respaldo completado exitosamente!"
    echo "Carpeta de respaldo: $backup_dir"
    echo "Catálogo creado: $catalog_file"
}

# --- MENU PRINCIPAL ---
while true; do
    clear
    echo "=========================================================="
    echo "       MENU PRINCIPAL - DATACENTER ADMIN (BASH)"
    echo "=========================================================="
    echo " 1. Usuarios del sistema y ultimo login"
    echo " 2. Filesystems o discos conectados (Tamano y espacio libre)"
    echo " 3. Mostrar los 10 archivos mas grandes en una ruta"
    echo " 4. Monitoreo de memoria RAM y Swap (Bytes y porcentaje)"
    echo " 5. Copia de seguridad (Backup) a memoria USB"
    echo " 6. Salir"
    echo "=========================================================="
    read -rp "Seleccione una opcion [1-6]: " opcion
    echo ""
    case "$opcion" in
        1) get_system_users_last_login ;;
        2) get_disk_storage_info ;;
        3) get_top10_largest_files ;;
        4) get_memory_and_swap_info ;;
        5) perform_directory_backup ;;
        6) echo "Saliendo de DataCenterAdmin. ¡Hasta luego!"; exit 0 ;;
        *) echo "Opcion invalida. Intente de nuevo." ;;
    esac
    echo ""
    read -rp "Presione [Enter] para continuar..." dummy
done
