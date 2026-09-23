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

También se aceptan variantes como "Nro. Cliente", "Nombre Propietario",
"Lectura Hace 1 Mes" o "Lectura Hace 2 Meses" (sin importar mayúsculas ni
tildes). Si alguna fila tiene errores no se importa nada y la app muestra
el número de cada fila con su problema.
