#!/bin/bash

############################################################
# Script: extraer_canales_xaccel.sh
# Extrae URLs UDP y nombres cortos de canales desde el dump .gz más reciente.
############################################################

DUMP_DIR="/opt/xaccel-codec/backup"
DUMP_PREFIX="xaccel-codec"
DUMP_EXT="gz"
OUTPUT_FILE="canales.txt"
DELIM="|"
OUTPUT_DIR="."
UDP_PREFIX="udp://@"
CANAL_REGEX='UDP | '

DUMP_GZ=$(ls -1t "${DUMP_DIR}/${DUMP_PREFIX}"*."${DUMP_EXT}" 2>/dev/null | head -n 1)

echo "Usando archivo dump detectado: $DUMP_GZ"

{
echo "# $OUTPUT_FILE - Lista de streams UDP extraídos automáticamente de un dump MySQL (.gz) de xaccel-codec"
echo "# Formato: url_udp${DELIM}nombre_corto"
echo "# Generado por $0 el $(date)"
echo "# Dump detectado: $DUMP_GZ"
echo "# Delimitador: $DELIM"
echo "# Prefijo UDP: $UDP_PREFIX"
echo "# Regex nombre corto: $CANAL_REGEX"
echo "# Ejemplo de línea:"
echo "# ${UDP_PREFIX}225.1.1.20:5020${DELIM}a3cine"
echo "#"
} > "${OUTPUT_DIR}/${OUTPUT_FILE}"

# Extrae solo los registros que contienen URLs UDP y su nombre de canal
zcat "$DUMP_GZ" | grep "INSERT INTO \`stream_config\`" | \
sed 's/),(/)\n(/g' | grep "$UDP_PREFIX" | \
while read -r registro; do
    # Extrae el nombre largo (campo 2 entre comillas simples o dobles)
    nombre_largo=$(echo "$registro" | awk -F, '{print $2}' | sed "s/['\"]//g")
    # Extrae la URL UDP dentro de comillas dobles
    url_udp=$(echo "$registro" | grep -oP 'udp://@[0-9\.]+:[0-9]+')
    # Limpia el nombre corto
    nombre_corto=$(echo "$nombre_largo" | sed "s/$CANAL_REGEX//I" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    # Si hay URL UDP y nombre corto, imprímelo
    if [ -n "$url_udp" ] && [ -n "$nombre_corto" ]; then
        echo "$url_udp$DELIM$nombre_corto"
    fi
done >> "${OUTPUT_DIR}/${OUTPUT_FILE}"

echo "Archivo generado correctamente: ${OUTPUT_DIR}/${OUTPUT_FILE}"