# extraer_canales_xaccel.sh

## Descripción

Este script automatiza la **extracción de URLs UDP y nombres cortos de canales** a partir de un archivo dump MySQL comprimido (`.gz`) generado por `xaccel-codec`. Está diseñado para trabajar con el formato estándar de los dumps generados por la plataforma, donde los canales y sus configuraciones aparecen en registros tipo SQL `INSERT INTO stream_config VALUES (...)`.

El resultado es un archivo **canales.txt** que contiene una lista de canales en formato:

```
udp://@225.1.1.20:5020|a3cine
```

Donde:
- La primera parte es la URL UDP del stream.
- La segunda parte es el nombre corto del canal, extraído y normalizado desde el registro SQL.

## ¿Para qué sirve?

- Obtener rápidamente un listado de canales UDP configurados en un sistema xaccel-codec.
- Automatizar la generación de listas para scripts, sistemas IPTV, monitoreo o documentación.
- Evitar la búsqueda manual y el parsing complejo de dumps SQL, extrayendo sólo la información relevante.

## Cómo funciona

1. **Detecta automáticamente** el archivo dump más reciente en el directorio configurado.
2. **Procesa el dump comprimido (.gz)** sin requerir descompresión manual.
3. **Filtra y extrae** únicamente los canales que tienen streams UDP.
4. **Normaliza los nombres** eliminando prefijos como `UDP | ` y espacios para dejar el nombre corto en minúsculas.
5. **Genera el archivo canales.txt** con el formato deseado.

## Uso básico

```bash
chmod +x extraer_canales_xaccel.sh
./extraer_canales_xaccel.sh
```

Por defecto genera `canales.txt` en el directorio actual.

## Opciones avanzadas

Puedes modificar parámetros en el script o usar los siguientes flags:

- `-d <directorio>`   Directorio donde buscar el dump (por defecto: `/opt/xaccel-codec/backup`)
- `-o <archivo.txt>`  Nombre del archivo txt de salida (por defecto: `canales.txt`)
- `-l <delimitador>`  Delimitador entre URL y nombre corto (por defecto: `|`)
- `-p <prefijo>`      Prefijo para identificar streams UDP (por defecto: `udp://@`)
- `-r <regex>`        Regex para extraer nombre corto (por defecto: `UDP | `)
- `-h`                Muestra la ayuda

Ejemplo:

```bash
./extraer_canales_xaccel.sh -d /mi/dump -o lista.txt -l ";" -p "udp://@" -r "UDP | "
```

## Requisitos

- Bash
- Herramientas estándar: `awk`, `grep`, `sed`, `zcat`
- Permiso de lectura sobre el archivo dump

## Salida generada

Un archivo `canales.txt` con líneas del tipo:

```
udp://@225.1.1.20:5020|a3cine
udp://@225.1.1.21:5021|fox
...
```

## Ejemplo de cabecera en canales.txt

```
# canales.txt - Lista de streams UDP extraídos automáticamente de un dump MySQL (.gz) de xaccel-codec
# Formato: url_udp|nombre_corto
# Generado por ./extraer_canales_xaccel.sh el 2025-09-20
# Dump detectado: /opt/xaccel-codec/backup/xaccel-codec-4.7.20-20250920121029-c2e1678a.gz
# Delimitador: |
# Prefijo UDP: udp://@
# Regex nombre corto: UDP | 
# Ejemplo de línea:
# udp://@225.1.1.20:5020|a3cine
```

## Notas

- El script ignora canales que no usan UDP.
- El nombre corto se procesa automáticamente para quitar espacios y prefijos.
- Puedes adaptar el script para obtener otros campos si lo necesitas.

## Autor

[chuymex](https://github.com/chuymex)
