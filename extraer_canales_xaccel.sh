#!/bin/bash

###############################################################################
# Script: extraer_canales_xaccel.sh
# Descripción:
#   Extrae URLs UDP y slugs RTMP de un dump MySQL comprimido de xaccel-codec.
#   Relaciona ambos usando el campo stream_id entre las tablas stream_config
#   (para UDP) y stream_output_config (para slug RTMP).
#   El resultado es un archivo tipo:
#     udp://@225.1.11.203:11203|usa.cbs.bufalo.wivb
# Autor: chuymex
###############################################################################

#######################
# 1. Configuración global
#######################

# Detecta el archivo dump .gz más reciente en el path típico del sistema.
DUMP_GZ=$(ls -1t /opt/xaccel-codec/backup/xaccel-codec*.gz 2>/dev/null | head -n 1)

# Archivo de salida final
OUTPUT_FILE="canales.txt"

# Delimitador entre URL y slug
DELIM="|"

# Directorio temporal para trabajo intermedio (se borra al final)
TMPDIR="/tmp/extraer_canales_xaccel.$$"
mkdir -p "$TMPDIR"

echo "Usando archivo dump detectado: $DUMP_GZ"

#######################
# 2. Descomprime el dump y lo deja como texto plano para procesamiento
#######################
zcat "$DUMP_GZ" > "$TMPDIR/dump.sql"

#######################
# 3. Extrae pares UDP y stream_id desde stream_config
#######################
# - Busca el registro de stream_config
# - Divide cada registro en línea
# - Extrae:
#     a) stream_id (último campo)
#     b) input_urls (campo tipo JSON al inicio)
# - Detecta y asocia la URL udp://@... con el stream_id
grep "INSERT INTO \`stream_config\`" "$TMPDIR/dump.sql" | \
  sed 's/),(/)\n(/g' | \
  while read -r registro; do
    # Busca el último número antes del paréntesis final como stream_id
    stream_id=$(echo "$registro" | grep -oP ',[ ]*[0-9]+[ ]*\)[;]*$' | grep -oP '[0-9]+')
    # Busca el primer array entre corchetes como input_urls
    input_urls=$(echo "$registro" | grep -oP '\[[^]]*\]')
    # Busca la URL UDP dentro del array
    udp=$(echo "$input_urls" | grep -oP 'udp://@[0-9\.]+:[0-9]+')
    # Si encuentra ambos, imprime el par
    if [[ -n "$udp" && -n "$stream_id" ]]; then
      echo "$stream_id|$udp"
    fi
  done > "$TMPDIR/udp_by_streamid.txt"

#######################
# 4. Extrae pares slug RTMP y stream_id desde stream_output_config
#######################
# - Busca el registro de stream_output_config
# - Divide cada registro en línea
# - Extrae:
#     a) stream_id (último campo)
#     b) url (campo con la ruta RTMP)
# - Del campo url, extrae el slug después de /local/
grep "INSERT INTO \`stream_output_config\`" "$TMPDIR/dump.sql" | \
  sed 's/),(/)\n(/g' | \
  while read -r registro; do
    # Busca el último número antes del paréntesis final como stream_id
    stream_id=$(echo "$registro" | grep -oP ',[ ]*[0-9]+[ ]*\)[;]*$' | grep -oP '[0-9]+')
    # Busca la url RTMP (puede incluir comillas simples)
    url=$(echo "$registro" | grep -oP "rtmp://localhost:9922/local/[^'\", )]+")
    # Solo si el campo es RTMP-local válido, extrae el slug
    if [[ "$url" =~ rtmp://localhost:9922/local/(.*) ]]; then
        slug="${BASH_REMATCH[1]}"
        if [[ -n "$slug" && -n "$stream_id" ]]; then
          echo "$stream_id|$slug"
        fi
    fi
  done > "$TMPDIR/slug_by_streamid.txt"

#######################
# 5. Une ambos archivos por stream_id y genera la salida final
#######################
# - Usa join por stream_id
# - Formato final: udp_url|slug
join -t'|' -1 1 -2 1 <(sort -t'|' -k1,1 "$TMPDIR/udp_by_streamid.txt") <(sort -t'|' -k1,1 "$TMPDIR/slug_by_streamid.txt") | \
  awk -F'|' -v d="$DELIM" '{print $2 d $3}' > "$OUTPUT_FILE"

#######################
# 6. Limpieza temporal y cierre
#######################
rm -rf "$TMPDIR"

echo "Archivo generado correctamente: $OUTPUT_FILE"

###############################################################################
# NOTAS FINALES:
# - Empareja UDP y slug por stream_id.
# - El slug es idéntico al de la url RTMP después de /local/.
# - Resistente a dumps con campos JSON y comas internas.
# - Si un stream_id no tiene ambos (UDP y RTMP), no aparece en el archivo final.
###############################################################################
