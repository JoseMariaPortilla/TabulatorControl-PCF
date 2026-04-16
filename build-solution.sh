#!/bin/bash
# =============================================================================
#  build-solution.sh  (v5 - eslintrc sin plugin @microsoft/power-apps)
#  Uso: bash build-solution.sh
# =============================================================================
set -e

SOLUTION_NAME="MineroSuiteTabulatorSolution"
PUBLISHER_NAME="MineroSuite"
PUBLISHER_PREFIX="ms"
PCF_DIR="$(pwd)"
SOLUTION_DIR="/tmp/${SOLUTION_NAME}"

echo ""
echo "=== TabulatorControl PCF — Build & Package v5 ==="
echo ""

# ── PASO 1: Verificar herramientas ───────────────────────────────────────────
echo "[1/8] Verificando herramientas..."
node --version && echo "  OK: Node.js"
npm --version  && echo "  OK: npm"
dotnet --version && echo "  OK: .NET"
export PATH="$PATH:$HOME/.dotnet/tools"

if command -v pac &> /dev/null; then
  echo "  OK: pac disponible"
  PAC_OK=true
else
  echo "  WARN: pac no encontrado. Instala con:"
  echo "    dotnet tool install --global Microsoft.PowerApps.CLI.Tool --version 1.29.6"
  PAC_OK=false
fi

# ── PASO 2: npm install ───────────────────────────────────────────────────────
echo ""
echo "[2/8] Instalando dependencias npm..."
npm install
echo "  OK"

# ── PASO 3: ManifestTypes.d.ts ───────────────────────────────────────────────
echo ""
echo "[3/8] Creando ManifestTypes.d.ts..."
mkdir -p TabulatorControl/generated
cat > TabulatorControl/generated/ManifestTypes.d.ts << 'MANIFEST_EOF'
export interface IInputs {
  dataJson: ComponentFramework.PropertyTypes.StringProperty;
  configJson: ComponentFramework.PropertyTypes.StringProperty;
}
export interface IOutputs {
  selectedRow?: string;
}
MANIFEST_EOF
echo "  OK: ManifestTypes.d.ts"

# ── PASO 4: .eslintrc.json (sin plugin @microsoft/power-apps) ────────────────
echo ""
echo "[4/8] Creando .eslintrc.json..."
cat > TabulatorControl/.eslintrc.json << 'ESLINT_EOF'
{
  "root": true,
  "parser": "@typescript-eslint/parser",
  "parserOptions": {
    "ecmaVersion": 2021,
    "sourceType": "module"
  },
  "plugins": ["@typescript-eslint"],
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/no-unused-vars": "warn",
    "no-console": "off"
  },
  "ignorePatterns": ["generated/", "**/__tests__/"]
}
ESLINT_EOF
echo "  OK: .eslintrc.json"

# ── PASO 5: Build PCF ─────────────────────────────────────────────────────────
echo ""
echo "[5/8] Compilando PCF (npm run build)..."
npm run build
echo "  OK: PCF compilado en out/"

# ── PASOS 6-8: Solucion ZIP ──────────────────────────────────────────────────
if [ "$PAC_OK" = true ]; then

  echo ""
  echo "[6/8] Inicializando solucion..."
  rm -rf "${SOLUTION_DIR}"
  mkdir -p "${SOLUTION_DIR}"
  cd "${SOLUTION_DIR}"
  pac solution init \
    --publisher-name "${PUBLISHER_NAME}" \
    --publisher-prefix "${PUBLISHER_PREFIX}" \
    --outputDirectory .
  echo "  OK"

  echo ""
  echo "[7/8] Agregando referencia al PCF..."
  pac solution add-reference --path "${PCF_DIR}"
  echo "  OK"

  echo ""
  echo "[8/8] dotnet build..."
  dotnet build --configuration Release

  ZIP_FOUND=$(find . -name "*.zip" -not -path "*/obj/*" | head -1)
  if [ -n "$ZIP_FOUND" ]; then
    cp "${ZIP_FOUND}" "${PCF_DIR}/${SOLUTION_NAME}.zip"
    echo ""
    echo "==========================================================="
    echo "  ZIP: ${PCF_DIR}/${SOLUTION_NAME}.zip"
    echo "  -> Explorer -> clic derecho -> Download"
    echo "  -> make.powerapps.com -> Soluciones -> Importar"
    echo "==========================================================="
  else
    echo "ERROR: No se genero el ZIP"
    exit 1
  fi

else
  echo ""
  echo "==========================================================="
  echo "  PCF compilado OK. Instala pac para crear el ZIP."
  echo "==========================================================="
fi
