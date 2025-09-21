#!/bin/bash

###############################################################################
# Script: extraer_canales_xaccel.sh
# Extrae URLs UDP y nombres cortos de output RTMP localhost desde el dump .gz más reciente.
# chuymex, 2025-09-21
###############################################################################

# ----------- Configuración de rutas y nombres -------------
DUMP_DIR="/opt/xaccel-codec/backup"
DUMP_PREFIX="xaccel-codec"
DUMP_EXT="gz"
OUTPUT_FILE="canales_por_grupos.txt"
DELIM="|"
OUTPUT_DIR="."
UDP_PREFIX="udp://@"
RTMP_PREFIX="rtmp://localhost:"
# ----------------------------------------------------------

# Detecta el archivo dump más reciente
DUMP_GZ=$(ls -1t "${DUMP_DIR}/${DUMP_PREFIX}"*."${DUMP_EXT}" 2>/dev/null | head -n 1)
echo "Usando archivo dump detectado: $DUMP_GZ"

# Cabecera del archivo de salida
{
    echo "# $OUTPUT_FILE - Lista de streams UDP y nombre corto del output RTMP localhost"
    echo "# Formato: url_udp${DELIM}nombre_output_localhost"
    echo "# Generado por $0 el $(date)"
    echo "# Dump detectado: $DUMP_GZ"
    echo "# Delimitador: $DELIM"
    echo "# Prefijo UDP: $UDP_PREFIX"
    echo "# Prefijo RTMP localhost: $RTMP_PREFIX"
    echo "# Ejemplo de línea:"
    echo "# ${UDP_PREFIX}225.1.1.20:5020${DELIM}discoverychannel"
    echo "#"
} > "${OUTPUT_DIR}/${OUTPUT_FILE}"

# Procesa cada registro que tiene UDP y RTMP localhost
zcat "$DUMP_GZ" | grep "INSERT INTO \`stream_config\`" | \
sed 's/),(/)\n(/g' | grep "$UDP_PREFIX" | \
while read -r registro; do
    # Extrae la URL UDP
    url_udp=$(echo "$registro" | grep -oP 'udp://@[0-9\.]+:[0-9]+')
    # Extrae la URL RTMP localhost (si hay más de una, solo toma la primera)
    url_rtmp=$(echo "$registro" | grep -oP "rtmp://localhost:[0-9]+/[^ ,)']+" | head -n 1)
    # Extrae el nombre corto del RTMP (último segmento, sin comillas ni .m3u8)
    nombre_output=""
    if [ -n "$url_rtmp" ]; then
        nombre_output=$(echo "$url_rtmp" | sed -nE "s#.*/([^/']+)\$#\1#p" | sed 's/.m3u8$//')
    fi
    # Solo imprime si hay UDP y nombre corto de RTMP
    if [ -n "$url_udp" ] && [ -n "$nombre_output" ]; then
        echo "$url_udp$DELIM$nombre_output"
    fi
done >> "${OUTPUT_DIR}/${OUTPUT_FILE}"

echo "Archivo generado correctamente: ${OUTPUT_DIR}/${OUTPUT_FILE}"

###############################################################################
# FIN DEL SCRIPT
###############################################################################
