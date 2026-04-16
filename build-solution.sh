#!/bin/bash
# =============================================================================
#  build-solution.sh
#  Compila el PCF y genera el ZIP listo para importar en Power Apps
#  Uso desde la terminal del Codespace: bash build-solution.sh
# =============================================================================
set -e

SOLUTION_NAME="MineroSuiteTabulatorSolution"
PUBLISHER_NAME="MineroSuite"
PUBLISHER_PREFIX="ms"
PCF_DIR="$(pwd)"
SOLUTION_DIR="../${SOLUTION_NAME}"

echo ""
echo "=== TabulatorControl PCF — Build & Package ==="
echo ""

# PASO 1: Verificar herramientas
echo "[1/7] Verificando herramientas..."
node --version && echo "  OK: Node.js"
npm --version  && echo "  OK: npm"
dotnet --version && echo "  OK: .NET"

if ! command -v pac &> /dev/null; then
  echo "  pac no encontrado, instalando..."
  npm install -g @microsoft/powerapps-cli
fi
echo "  OK: pac $(pac --version | head -1)"

# PASO 2: npm install
echo ""
echo "[2/7] Instalando dependencias npm..."
npm install
echo "  OK"

# PASO 3: Crear ManifestTypes.d.ts si no existe
echo ""
echo "[3/7] Creando ManifestTypes.d.ts..."
mkdir -p TabulatorControl/generated
if [ ! -f "TabulatorControl/generated/ManifestTypes.d.ts" ]; then
cat > TabulatorControl/generated/ManifestTypes.d.ts << 'MANIFEST_EOF'
export interface IInputs {
  dataJson: ComponentFramework.PropertyTypes.StringProperty;
  configJson: ComponentFramework.PropertyTypes.StringProperty;
}
export interface IOutputs {
  selectedRow?: string;
}
MANIFEST_EOF
echo "  OK: ManifestTypes.d.ts creado"
else
  echo "  OK: ManifestTypes.d.ts ya existe"
fi

# PASO 4: Build PCF
echo ""
echo "[4/7] Compilando PCF (npm run build)..."
npm run build
echo "  OK: Build completado"

# PASO 5: Crear carpeta de solución
echo ""
echo "[5/7] Inicializando solución Power Apps..."
rm -rf "${SOLUTION_DIR}"
mkdir -p "${SOLUTION_DIR}"
cd "${SOLUTION_DIR}"
pac solution init \
  --publisher-name "${PUBLISHER_NAME}" \
  --publisher-prefix "${PUBLISHER_PREFIX}" \
  --outputDirectory .
echo "  OK: Solución inicializada"

# PASO 6: Agregar referencia al PCF
echo ""
echo "[6/7] Agregando referencia al PCF..."
pac solution add-reference --path "${PCF_DIR}"
echo "  OK"

# PASO 7: Compilar con dotnet
echo ""
echo "[7/7] Compilando solución (dotnet build)..."
dotnet build --configuration Release

# Buscar y mover el ZIP
ZIP_FOUND=$(find . -name "*.zip" -not -path "*/obj/*" | head -1)
if [ -n "$ZIP_FOUND" ]; then
  cp "${ZIP_FOUND}" "${PCF_DIR}/${SOLUTION_NAME}.zip"
  echo ""
  echo "============================================================="
  echo "  ZIP listo: ${PCF_DIR}/${SOLUTION_NAME}.zip"
  echo ""
  echo "  Para descargar desde Codespaces:"
  echo "  1. En el panel izquierdo (Explorer) busca el archivo .zip"
  echo "  2. Clic derecho -> Download"
  echo ""
  echo "  Para importar en Power Apps:"
  echo "  1. make.powerapps.com -> Soluciones -> Importar solucion"
  echo "  2. Sube el ZIP"
  echo "============================================================="
else
  echo "ERROR: No se encontro el ZIP generado"
  find . -name "*.zip" 2>/dev/null
  exit 1
fi
