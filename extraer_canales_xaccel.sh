#!/bin/bash

###############################################################################
# Script: extraer_canales_xaccel.sh
# Descripción:
#   Extrae las URLs UDP y el nombre corto del canal de los outputs RTMP a localhost,
#   asociando ambos por stream_id desde el dump MySQL (.gz) más reciente de xaccel-codec.
#   El resultado se guarda en un archivo de texto con el formato: udp_url|nombre_output_localhost
# Autor: chuymex + Copilot
# Fecha: 2025-09-21
###############################################################################

# ======================= AYUDA Y ARGUMENTOS POR CONSOLA ======================
mostrar_ayuda() {
    echo "Uso: $0 [ruta_dump] [archivo_salida]"
    echo ""
    echo "  ruta_dump      Ruta donde buscar el dump .gz (por defecto: /opt/xaccel-codec/backup)"
    echo "  archivo_salida Nombre del archivo de salida (por defecto: canales.txt)"
    echo ""
    echo "Ejemplo:"
    echo "  $0 /opt/xaccel-codec/backup canales.txt"
    echo ""
    exit 1
}

# Si el usuario pide ayuda
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mostrar_ayuda
fi

# ======================= CONFIGURACIÓN PERSONALIZABLE ========================
DUMP_DIR="${1:-/opt/xaccel-codec/backup}"    # Argumento 1 o valor por defecto
DUMP_PREFIX="xaccel-codec"
DUMP_EXT="gz"
OUTPUT_FILE="${2:-canales.txt}"              # Argumento 2 o valor por defecto

# ======================= LOCALIZA EL DUMP MÁS RECIENTE =======================
DUMP_GZ=$(ls -1t "${DUMP_DIR}/${DUMP_PREFIX}"*."${DUMP_EXT}" 2>/dev/null | head -n 1)

# ----------- Validación de existencia de dump ---------
if [[ ! -f "$DUMP_GZ" ]]; then
    echo "ERROR: No se encontró ningún archivo dump en la ruta: $DUMP_DIR"
    exit 1
fi

# ======================= CABECERA DEL ARCHIVO DE SALIDA ======================
{
echo "# $OUTPUT_FILE - UDP y nombre corto del output RTMP localhost relacionados por stream_id"
echo "# Formato: udp_url|nombre_output_localhost"
echo "# Generado por $0 el $(date)"
echo "# Dump detectado: $DUMP_GZ"
echo "# Puedes personalizar la ruta de búsqueda del dump con argumento 1 o editando DUMP_DIR."
echo "# Puedes personalizar el nombre del archivo de salida con argumento 2 o editando OUTPUT_FILE."
echo "#"
} > "$OUTPUT_FILE"

# ======================= FUNCIÓN: EXTRAER UDP Y STREAM_ID ====================
extraer_udp_streamid() {
    # Procesa stream_config y obtiene UDP y stream_id
    zcat "$DUMP_GZ" | grep "INSERT INTO \`stream_config\`" | sed 's/),(/)\n(/g' | \
    while read -r registro; do
        # Extrae stream_id (último campo)
        stream_id=$(echo "$registro" | awk -F',' '{print $NF}' | sed 's/[)]//g')
        # Extrae la URL UDP
        url_udp=$(echo "$registro" | grep -oP 'udp://@[0-9\.]+:[0-9]+')
        # Si hay ambos, guarda en archivo temporal
        if [ -n "$url_udp" ] && [ -n "$stream_id" ]; then
            echo "$stream_id|$url_udp"
        fi
    done > udp_streamid_temp.txt
}

# ======================= FUNCIÓN: EXTRAER RTMP Y STREAM_ID ===================
extraer_rtmp_streamid() {
    # Procesa stream_output_config y obtiene RTMP localhost y stream_id
    zcat "$DUMP_GZ" | grep "INSERT INTO \`stream_output_config\`" | sed 's/),(/)\n(/g' | \
    while read -r registro; do
        # Extrae stream_id (penúltimo campo)
        stream_id=$(echo "$registro" | awk -F',' '{print $(NF-1)}' | sed 's/[)]//g')
        # Extrae RTMP localhost
        rtmp_url=$(echo "$registro" | grep -oP "rtmp://localhost:[0-9]+/[^ ',)]+" )
        # Extrae nombre corto (último segmento)
        if [ -n "$rtmp_url" ] && [ -n "$stream_id" ]; then
            nombre_output=$(echo "$rtmp_url" | sed -nE "s#.*/([^/']+)\$#\1#p" | sed 's/.m3u8$//')
            echo "$stream_id|$nombre_output"
        fi
    done > rtmp_streamid_temp.txt
}

# ======================= FUNCIÓN: ASOCIAR Y EXPORTAR =========================
unir_udp_rtmp_por_streamid() {
    # Une ambos archivos temporales por stream_id y exporta al archivo final
    while IFS="|" read -r stream_id udp_url; do
        nombre_output=$(grep "^$stream_id|" rtmp_streamid_temp.txt | head -n 1 | cut -d'|' -f2)
        if [ -n "$udp_url" ] && [ -n "$nombre_output" ]; then
            echo "$udp_url|$nombre_output" >> "$OUTPUT_FILE"
        fi
    done < udp_streamid_temp.txt
}

# ======================= FUNCIÓN: LIMPIEZA FINAL =============================
limpiar_temporales() {
    rm -f udp_streamid_temp.txt rtmp_streamid_temp.txt
}

# ======================= EJECUCIÓN MODULAR DEL SCRIPT ========================
echo "Usando archivo dump detectado: $DUMP_GZ"
echo "Extrayendo UDP y stream_id..."
extraer_udp_streamid
echo "Extrayendo RTMP localhost y stream_id..."
extraer_rtmp_streamid
echo "Asociando y exportando UDP ↔ RTMP por stream_id..."
unir_udp_rtmp_por_streamid
limpiar_temporales

echo "Archivo generado correctamente: $OUTPUT_FILE"

###############################################################################
# FIN DEL SCRIPT
###############################################################################
