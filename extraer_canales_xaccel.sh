#!/bin/bash

# Configuración de archivos
DUMP_GZ=$(ls -1t /opt/xaccel-codec/backup/xaccel-codec-*.gz 2>/dev/null | head -n 1)
OUTPUT_FILE="canales_por_grupos.txt"

echo "# $OUTPUT_FILE - UDP y nombre corto del output RTMP localhost relacionados por stream_id" > "$OUTPUT_FILE"
echo "# Formato: udp_url|nombre_output_localhost" >> "$OUTPUT_FILE"
echo "# Generado el $(date)" >> "$OUTPUT_FILE"
echo "#" >> "$OUTPUT_FILE"

# 1. Extrae UDP y stream_id de stream_config
zcat "$DUMP_GZ" | grep "INSERT INTO \`stream_config\`" | sed 's/),(/)\n(/g' | \
while read -r registro; do
    # Extrae stream_id (último campo de cada registro)
    stream_id=$(echo "$registro" | awk -F',' '{print $NF}' | sed 's/[)]//g')
    # Extrae la URL UDP
    url_udp=$(echo "$registro" | grep -oP 'udp://@[0-9\.]+:[0-9]+')
    # Solo si hay UDP y stream_id, guarda en archivo temporal
    if [ -n "$url_udp" ] && [ -n "$stream_id" ]; then
        echo "$stream_id|$url_udp"
    fi
done > udp_streamid_temp.txt

# 2. Extrae RTMP localhost y stream_id de stream_output_config
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

# 3. Une por stream_id y genera el archivo final
while IFS="|" read -r stream_id udp_url; do
    nombre_output=$(grep "^$stream_id|" rtmp_streamid_temp.txt | head -n 1 | cut -d'|' -f2)
    if [ -n "$udp_url" ] && [ -n "$nombre_output" ]; then
        echo "$udp_url|$nombre_output" >> "$OUTPUT_FILE"
    fi
done < udp_streamid_temp.txt

# Limpieza
rm -f udp_streamid_temp.txt rtmp_streamid_temp.txt

echo "Archivo generado correctamente: $OUTPUT_FILE"
