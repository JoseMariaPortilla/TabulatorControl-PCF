#!/bin/bash
# =============================================================================
#  build-solution.sh  (v3 - pac via APT repositorio oficial Microsoft)
#  Compatible con .NET 6, 7, 8 en Linux/Codespaces
#  Uso: bash build-solution.sh
# =============================================================================
set -e

SOLUTION_NAME="MineroSuiteTabulatorSolution"
PUBLISHER_NAME="MineroSuite"
PUBLISHER_PREFIX="ms"
PCF_DIR="$(pwd)"
SOLUTION_DIR="/tmp/${SOLUTION_NAME}"

echo ""
echo "=== TabulatorControl PCF — Build & Package v3 ==="
echo ""

# ── PASO 1: Verificar herramientas basicas ────────────────────────────────────
echo "[1/7] Verificando herramientas..."
node --version && echo "  OK: Node.js"
npm --version  && echo "  OK: npm"
dotnet --version && echo "  OK: .NET"

# ── Instalar pac CLI via repositorio APT oficial de Microsoft ─────────────────
if ! command -v pac &> /dev/null; then
  echo "  Instalando pac CLI via repositorio APT de Microsoft..."

  # Agregar repositorio Microsoft
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

  # Detectar version de Ubuntu/Debian
  . /etc/os-release
  DISTRO="${ID}${VERSION_ID}"

  # Agregar el repo de prod de Power Platform
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/ppa/prod/${ID}/${VERSION_ID} stable main" | \
    sudo tee /etc/apt/sources.list.d/microsoft-prod.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y powerapps-cli 2>/dev/null || true

  # Si APT falla, usar la version 1.x de dotnet tool (compatible con .NET 6)
  if ! command -v pac &> /dev/null; then
    echo "  APT no disponible, instalando via dotnet tool version 1.x..."
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool --version 1.29.6 2>/dev/null || \
    dotnet tool install --global Microsoft.PowerApps.CLI.Tool --version 1.28.3 2>/dev/null || true
    export PATH="$PATH:$HOME/.dotnet/tools"
  fi

  # Si aun no hay pac, usar el binario precompilado
  if ! command -v pac &> /dev/null; then
    echo "  Descargando pac binario precompilado..."
    PAC_VERSION="1.29.6"
    PAC_URL="https://api.nuget.org/v3-flatcontainer/microsoft.powerapps.cli/${PAC_VERSION}/microsoft.powerapps.cli.${PAC_VERSION}.nupkg"
    mkdir -p /tmp/pac_install
    curl -sL "${PAC_URL}" -o /tmp/pac_install/pac.nupkg
    cd /tmp/pac_install
    unzip -q pac.nupkg -d pac_extracted 2>/dev/null || true
    # Buscar binario linux-x64
    PAC_BIN=$(find pac_extracted -name "pac" -type f 2>/dev/null | head -1)
    if [ -n "$PAC_BIN" ]; then
      chmod +x "$PAC_BIN"
      sudo cp "$PAC_BIN" /usr/local/bin/pac
      echo "  OK: pac instalado desde NuGet"
    fi
    cd "${PCF_DIR}"
  fi
else
  echo "  OK: pac ya disponible: $(pac --version | head -1)"
fi

export PATH="$PATH:$HOME/.dotnet/tools"

# Verificar pac
if command -v pac &> /dev/null; then
  echo "  OK: pac $(pac --version | head -1)"
  PAC_OK=true
else
  echo "  WARN: pac no disponible - se omitira la creacion de solucion"
  PAC_OK=false
fi

# ── PASO 2: npm install ───────────────────────────────────────────────────────
echo ""
echo "[2/7] Instalando dependencias npm..."
npm install
echo "  OK"

# ── PASO 3: ManifestTypes.d.ts ───────────────────────────────────────────────
echo ""
echo "[3/7] Creando ManifestTypes.d.ts..."
mkdir -p TabulatorControl/generated

cat > TabulatorControl/generated/ManifestTypes.d.ts << 'MANIFEST_EOF'
/*
 * Generated — DO NOT EDIT manually
 */
export interface IInputs {
  dataJson: ComponentFramework.PropertyTypes.StringProperty;
  configJson: ComponentFramework.PropertyTypes.StringProperty;
}
export interface IOutputs {
  selectedRow?: string;
}
MANIFEST_EOF

echo "  OK: ManifestTypes.d.ts creado"

# ── PASO 4: Build PCF ─────────────────────────────────────────────────────────
echo ""
echo "[4/7] Compilando PCF (npm run build)..."
npm run build
echo "  OK: PCF compilado"

# ── PASOS 5-7: Crear solucion (solo si pac disponible) ───────────────────────
if [ "$PAC_OK" = true ]; then

  echo ""
  echo "[5/7] Inicializando solucion Power Apps..."
  rm -rf "${SOLUTION_DIR}"
  mkdir -p "${SOLUTION_DIR}"
  cd "${SOLUTION_DIR}"
  pac solution init \
    --publisher-name "${PUBLISHER_NAME}" \
    --publisher-prefix "${PUBLISHER_PREFIX}" \
    --outputDirectory .
  echo "  OK"

  echo ""
  echo "[6/7] Agregando referencia al PCF..."
  pac solution add-reference --path "${PCF_DIR}"
  echo "  OK"

  echo ""
  echo "[7/7] Compilando solucion (dotnet build)..."
  dotnet build --configuration Release

  ZIP_FOUND=$(find . -name "*.zip" -not -path "*/obj/*" | head -1)
  if [ -n "$ZIP_FOUND" ]; then
    cp "${ZIP_FOUND}" "${PCF_DIR}/${SOLUTION_NAME}.zip"
    echo ""
    echo "============================================================="
    echo "  ZIP listo: ${PCF_DIR}/${SOLUTION_NAME}.zip"
    echo "  -> Explorer -> clic derecho en .zip -> Download"
    echo "  -> make.powerapps.com -> Soluciones -> Importar solucion"
    echo "============================================================="
  else
    echo "ERROR: No se encontro el ZIP"
    exit 1
  fi

else
  echo ""
  echo "============================================================="
  echo "  PCF compilado OK en: ${PCF_DIR}/out/"
  echo ""
  echo "  pac no disponible. Para instalar pac manualmente:"
  echo "  sudo apt-get install -y powerapps-cli"
  echo "  O bien usa GitHub Actions (ver README)"
  echo "============================================================="
fi
