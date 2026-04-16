# TabulatorControl-PCF

> **PCF Table/Matrix para Power Apps Canvas** usando [Tabulator.js](https://tabulator.info/)  
> Sigue el patrón MineroSuite — idéntico al control ECharts pero para tablas.

[![PCF](https://img.shields.io/badge/Power%20Apps-PCF-742774?style=flat-square&logo=microsoftpowerapps)](https://docs.microsoft.com/powerapps/developer/component-framework)
[![Tabulator](https://img.shields.io/badge/Tabulator.js-6.x-blue?style=flat-square)](https://tabulator.info/)
[![TypeScript](https://img.shields.io/badge/TypeScript-4.9-3178c6?style=flat-square&logo=typescript)](https://www.typescriptlang.org/)

---

## Arquitectura

```
Power Apps Canvas
    ↓ propiedad "dataJson"   (JSON string con array de objetos)
    ↓ propiedad "configJson" (JSON string con columnas y opciones)

PCF TabulatorControl
    → Tabulator.js renderiza la tabla

    ↑ propiedad output "selectedRow" (fila seleccionada → Power Apps)
```

---

## Estructura del proyecto

```
TabulatorControl-PCF/
├── TabulatorControl/
│   ├── index.ts                      ← Lógica principal del PCF
│   ├── ControlManifest.Input.xml     ← Declaración de propiedades
│   └── css/
│       └── TabulatorControl.css      ← Estilos Fluent UI
├── package.json
├── tsconfig.json
└── .pcfignore
```

---

## Requisitos previos

- [Node.js](https://nodejs.org/) >= 16
- [Power Platform CLI](https://docs.microsoft.com/powerapps/developer/component-framework/get-powerapps-cli)

```bash
npm install -g microsoft-powerapps-cli
```

---

## Instalación y build

### 1. Clonar el repositorio

```bash
git clone https://github.com/JoseMariaPortilla/TabulatorControl-PCF.git
cd TabulatorControl-PCF
```

### 2. Instalar dependencias

```bash
npm install
```

### 3. Inicializar el scaffold PCF (solo la primera vez)

```bash
pac pcf init --namespace MineroSuite --name TabulatorControl --template field
```

> ⚠️ Después de este comando, **reemplaza** los archivos generados con los del repositorio.

### 4. Modo desarrollo (test local en navegador)

```bash
npm start
```

Abre `http://localhost:8181` para ver el control con datos de prueba.

### 5. Build de producción

```bash
npm run build
```

---

## Empaquetar y subir a Power Apps

### Opción A — Solución nueva

```bash
# Crear carpeta de solución
mkdir MineroSuiteSolution && cd MineroSuiteSolution

pac solution init --publisher-name MineroSuite --publisher-prefix ms

pac solution add-reference --path ../TabulatorControl-PCF

msbuild /t:restore
msbuild /p:configuration=Release
```

El archivo `.zip` se genera en `bin/Release/`.

### Opción B — Importar directamente el .zip

1. Ve a [make.powerapps.com](https://make.powerapps.com)
2. **Soluciones** → **Importar solución**
3. Selecciona el `.zip` generado
4. Espera la importación ✅

---

## Uso en Power Apps Canvas

### Agregar el control

1. Inserta → Componentes de código → **TabulatorControl**
2. Configura las propiedades:

### Propiedad `dataJson` (input)

```javascript
// Desde una colección Power Apps:
JSON(colVentas)

// Ejemplo hardcodeado:
"[
  {"vendedor":"Ana","region":"Norte","ventas":120000,"meta":100000},
  {"vendedor":"Luis","region":"Sur","ventas":85000,"meta":90000},
  {"vendedor":"María","region":"Centro","ventas":210000,"meta":150000}
]"
```

### Propiedad `configJson` (input, opcional)

```javascript
// Configuración mínima:
"{"layout":"fitColumns","paginationSize":10}"

// Configuración completa con formatters:
"{
  "layout": "fitColumns",
  "pagination": "local",
  "paginationSize": 10,
  "columns": [
    {"title":"Vendedor", "field":"vendedor", "width":150, "headerFilter":"input"},
    {"title":"Región",   "field":"region",   "width":120, "headerFilter":"input"},
    {
      "title":"Ventas", "field":"ventas", "hozAlign":"right",
      "formatter":"money",
      "formatterParams":{"symbol":"$","thousand":",","precision":0}
    },
    {
      "title":"Meta", "field":"meta", "hozAlign":"right",
      "formatter":"money",
      "formatterParams":{"symbol":"$","thousand":",","precision":0}
    },
    {
      "title":"Avance", "field":"ventas",
      "formatter":"progress",
      "formatterParams":{"min":0,"max":200000,"color":["#e74c3c","#f39c12","#27ae60"]}
    }
  ]
}"
```

> Si `configJson` no incluye `columns`, las columnas se **generan automáticamente** desde las keys del primer objeto del array.

### Propiedad `selectedRow` (output)

```javascript
// Leer el JSON completo de la fila seleccionada:
TabulatorControl1.selectedRow

// Parsear y acceder a un campo específico:
ParseJSON(TabulatorControl1.selectedRow).vendedor

// Mostrar en una etiqueta:
Text(ParseJSON(TabulatorControl1.selectedRow).ventas)

// Usar en una condición:
If(
  !IsBlank(TabulatorControl1.selectedRow),
  Navigate(PantallaDetalle),
  Notify("Selecciona una fila", NotificationType.Information)
)
```

---

## Formatters disponibles (Tabulator.js)

| Formatter | Descripción | Ejemplo config |
|-----------|-------------|----------------|
| `money`    | Moneda con símbolo | `{"symbol":"$","thousand":",","precision":2}` |
| `progress` | Barra de progreso | `{"min":0,"max":100,"color":"#0078d4"}` |
| `star`     | Rating estrellas | `{"stars":5}` |
| `tickCross`| Checkbox visual | `{"allowEmpty":true}` |
| `color`    | Color hex → cuadro | — |
| `datetime` | Formato de fecha | `{"inputFormat":"iso","outputFormat":"dd/MM/yyyy"}` |
| `link`     | Enlace clickable | `{"urlPrefix":"https://"}` |

Referencia completa: [tabulator.info/docs/6.2/format](https://tabulator.info/docs/6.2/format)

---

## Características

| Feature | Detalle |
|---------|---------|
| Auto-columnas | Si no hay `columns` en configJson, se generan desde las keys del JSON |
| Filtros por columna | `headerFilter: "input"` disponible por columna |
| Paginación local | 10 / 20 / 50 / 100 filas por página |
| Ordenamiento | Click en cabecera, multi-columna con Shift+Click |
| Selección de fila | Click → output `selectedRow` en JSON |
| Highlight Fluent UI | Colores Microsoft `#0078d4` |
| Español | Paginación en español latinoamericano |
| Columnas redimensionables | Drag en borde de cabecera |
| Columnas movibles | Drag & drop entre columnas |
| Responsive | Colapsa columnas en contenedores pequeños |

---

## Licencia

MIT — Libre uso en proyectos Power Platform.
