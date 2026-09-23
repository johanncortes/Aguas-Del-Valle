# aguas_monte_patria

Water Meter Reader MVP for Aguas del Valle - Monte Patria

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Aguas-Del-Valle

## Importar la ruta del mes (Excel)

Menú ⋮ → **Importar Ruta (Excel)**. Reemplaza todos los clientes actuales
por los del archivo (exporta antes las lecturas del ciclo).

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
parten en 0 y los pines se ubican en una grilla por sector alrededor del
mapa, marcados con "Ubicación por confirmar". En la primera visita use
**Reubicar** para dejar cada pin en su lugar real, o importe una ruta Excel
con Latitud/Longitud reales (reemplaza la lista precargada).
