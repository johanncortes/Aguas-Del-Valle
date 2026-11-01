# Aguas del Valle

[![CI](https://github.com/johanncortes/Aguas-Del-Valle/actions/workflows/ci.yml/badge.svg)](https://github.com/johanncortes/Aguas-Del-Valle/actions/workflows/ci.yml)

App de lectura de medidores de agua para Aguas del Valle (Monte Patria):
mapa de clientes, registro de lecturas con foto y GPS, e importación y
exportación de la ruta en Excel.

## Descargar el APK de prueba

Cada cambio en `main` (y cada pull request) ejecuta el workflow **CI**, que
analiza el código, corre los tests y compila el APK.

1. Abra la pestaña **Actions** del repositorio y entre a la última ejecución
   en verde.
2. Al final de la página, en **Artifacts**, descargue
   `aguas-del-valle-apk` (es un `.zip` con `app-release.apk` adentro).
3. Copie el APK al teléfono Android e instálelo (hay que permitir
   "instalar apps de origen desconocido").

El APK se firma por ahora con la clave de *debug*: sirve para probar en el
teléfono, pero no para publicar en Play Store. Los artefactos se guardan 30
días; para generar uno nuevo sin cambios, use **Run workflow** en Actions.

## Importar la ruta del mes (Excel)

Menú ⋮ → **Importar Ruta (Excel)**. Según el archivo:

- **Plantilla base** (sin columna "Lectura Actual"): actualiza por N° de
  cliente el nombre, sector, historial y ubicación; agrega los clientes
  nuevos como pendientes y no borra ninguno. Las lecturas del ciclo en curso
  se conservan, y una coordenada vacía no borra un pin ya ubicado.
- **Excel exportado completo** (con "Lectura Actual"): reemplaza todos los
  clientes y avanza el mes (exporta antes las lecturas del ciclo).

### Flujo oficina ↔ operario

1. Menú ⋮ → **Exportar Plantilla Base (Solo ubicaciones)**: genera un Excel
   con N° Cliente, Nombre, Sector, Latitud, Longitud y las dos lecturas
   anteriores (sin datos del ciclo).
2. La oficina completa o corrige ubicaciones y datos en ese archivo.
3. El operario lo importa: se actualizan pines y datos sin perder las
   lecturas que ya tomó.

Cada cliente también se puede corregir en terreno: en su ficha, el lápiz
abre **Editar Cliente** (nombre, sector e historial; el N° no cambia) y
permite **Borrar ubicación del mapa**.

El archivo debe ser `.xlsx` y tener una fila de encabezados (puede haber un
título arriba) con estas columnas, en cualquier orden:

| Columna | Ejemplo | Notas |
|---|---|---|
| N° Cliente | 40225001 | Obligatorio, no puede repetirse |
| Nombre | María Cortés Rojas | Obligatorio |
| Latitud | -30,7280 | Coma o punto decimal |
| Longitud | -70,7660 | Coma o punto decimal |
| Lectura Mes Anterior | 1268 | Entero ≥ 0; vacío = 0 |
| Lectura 2 Meses Atrás | 1245 | Entero ≥ 0; vacío = 0; no mayor que la del mes anterior |

### Usar el Excel exportado como ruta del mes siguiente

El botón **Exportar Excel** genera un archivo con todos los clientes
(también los pendientes), sus coordenadas y la columna "Lectura Actual".
Ese mismo archivo se puede importar el mes siguiente: para cada cliente
con lectura, la "Lectura Actual" pasa a ser la "Lectura Mes Anterior";
los clientes sin lectura conservan su historial (igual que "Cerrar mes").

Las columnas "Latitud Lectura" y "Longitud Lectura" indican dónde estaba el
teléfono al registrar la visita (auditoría GPS). Quedan en "-" si no había
GPS o permiso de ubicación; la lectura se guarda igual.

También se aceptan variantes como "Nro. Cliente", "Nombre Propietario",
"Lectura Hace 1 Mes" o "Lectura Hace 2 Meses" (sin importar mayúsculas ni
tildes). Si alguna fila tiene errores no se importa nada y la app muestra
el número de cada fila con su problema.

## Fotos de evidencia

En la pantalla de lectura, **Tomar foto de evidencia (Opcional)** abre la
cámara. La foto se guarda reducida (máx. 1600 px, calidad 70) en la carpeta
`evidence_photos` de la app y queda asociada a la visita; el Excel
exportado indica el nombre del archivo en la columna "Foto". Al cerrar el
mes la visita se reinicia (la foto deja de estar asociada, pero el archivo
se conserva en el teléfono).

## Requisitos

- Flutter 3.44 o superior (lo exige `image_picker`).

## Clientes precargados

En la primera ejecución (base de datos vacía) la app carga los 185 clientes
oficiales de `lib/data/initial_clients.dart` con su N° de cliente, nombre y
sector. Esa lista no trae coordenadas ni lecturas anteriores: las lecturas
parten en 0 y los clientes **no aparecen en el mapa** hasta tener ubicación.

Para ubicarlos (no hace falta estar en terreno): en la **Lista de
clientes** (aparecen como "Sin ubicación") abra el cliente y presione
**Ubicar manualmente en el mapa**. La app vuelve al mapa con una mira fija
en el centro: mueva el mapa hasta dejar la casa bajo la mira y presione
**Confirmar Ubicación** (o **Cancelar**). También se puede importar una ruta Excel con Latitud/Longitud
reales (reemplaza la lista precargada); en el Excel, las coordenadas vacías
o "-" se importan como "sin ubicación".
