#!/usr/bin/env bash
set -Eeuo pipefail

export AWS_PROFILE="${1:-default}"
export AWS_REGION="${2:-eu-west-1}"
REGION="$AWS_REGION"

TOP_N="${TOP_N:-30}"   # cuántas AMIs mostrar en el selector final

echo "🔐 AWS_PROFILE=$AWS_PROFILE"
echo "🌍 AWS_REGION=$REGION"
echo

need_jq() { command -v jq >/dev/null || { echo "❌ Falta jq (instálalo)"; exit 1; }; }
need_jq

# -----------------------------
# 1) Selector “Catálogo” (familias/productos)
# -----------------------------
echo "🛒 AMI Catalog (familias/productos):"
CATALOG=(
  "Amazon Linux 2023 (kernel 6.1)"
  "Amazon Linux 2023 (kernel 6.12)"
  "Amazon Linux 2"
  "Ubuntu Server 24.04 LTS"
  "Ubuntu Server 22.04 LTS"
  "Ubuntu Pro 24.04 LTS"
  "Debian 13"
  "Debian 12"
  "RHEL 10"
  "RHEL 9"
  "SUSE SLES 16"
  "SUSE SLES 15 SP7"
  "Windows Server 2025 Base"
  "Windows Server 2025 Core Base"
  "Windows Server 2022 Base"
  "Windows Server 2022 Core Base"
  "Windows Server 2019 Base"
  "Windows Server 2019 Core Base"
  "Windows Server 2016 Base"
  "Windows Server 2016 Core Base"
  "Windows + SQL Server (todas)"
  "Deep Learning AMIs (todas)"
  "macOS Sonoma"
  "macOS Sequoia"
  "macOS Tahoe"
)

select PRODUCT in "${CATALOG[@]}"; do
  [[ -n "$PRODUCT" ]] && break
  echo "❌ Opción inválida"
done

# -----------------------------
# 2) Arquitectura (si aplica)
# -----------------------------
ARCH="x86_64"  # default

needs_arch() {
  case "$PRODUCT" in
    "Windows"*|"Windows + SQL Server (todas)"|"macOS "*)
      return 1 ;; # no preguntamos aquí
    *)
      return 0 ;;
  esac
}

if needs_arch; then
  echo
  echo "🧠 Selecciona arquitectura:"
  ARCH_OPTS=("x86_64" "arm64")
  select ARCH in "${ARCH_OPTS[@]}"; do
    [[ -n "$ARCH" ]] && break
    echo "❌ Opción inválida"
  done
fi

# macOS: permitir Mac vs Mac-Arm cuando aplica
MAC_ARCH=""
if [[ "$PRODUCT" == macOS* ]]; then
  echo
  echo "🧠 Selecciona arquitectura macOS:"
  MAC_OPTS=("Mac" "Mac-Arm")
  select MAC_ARCH in "${MAC_OPTS[@]}"; do
    [[ -n "$MAC_ARCH" ]] && break
    echo "❌ Opción inválida"
  done
fi

# -----------------------------
# 3) Mapear producto -> (owner + filters)
# -----------------------------
OWNER=""
FILTERS=()

case "$PRODUCT" in
  "Amazon Linux 2023 (kernel 6.1)")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=al2023-ami-*-kernel-6.1-*$ARCH")
    ;;
  "Amazon Linux 2023 (kernel 6.12)")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=al2023-ami-*-kernel-6.12-*$ARCH")
    ;;
  "Amazon Linux 2")
    OWNER="amazon"
    # AL2 suele ser x86_64 (hay arm64 en algunas familias, pero el “clásico” del catálogo es x86_64 gp2)
    if [[ "$ARCH" != "x86_64" ]]; then
      echo "❌ Amazon Linux 2 (catálogo base) suele ser x86_64. Elige x86_64."
      exit 1
    fi
    FILTERS+=("Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2")
    ;;

  "Ubuntu Server 24.04 LTS")
    OWNER="099720109477" # Canonical
    if [[ "$ARCH" == "arm64" ]]; then
      FILTERS+=("Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-noble-24.04-arm64-server-*")
    else
      FILTERS+=("Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*")
    fi
    ;;
  "Ubuntu Server 22.04 LTS")
    OWNER="099720109477"
    if [[ "$ARCH" == "arm64" ]]; then
      FILTERS+=("Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*")
    else
      FILTERS+=("Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*")
    fi
    ;;
  "Ubuntu Pro 24.04 LTS")
    OWNER="amazon"
    # En el catálogo aparece como "Ubuntu Pro - Ubuntu Server Pro 24.04 LTS..."
    FILTERS+=("Name=name,Values=*Ubuntu Pro*24.04*")
    # intentamos respetar arquitectura si viene en el name (no siempre consistente)
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;

  "Debian 13")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=debian-13-*")
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;
  "Debian 12")
    OWNER="136693071363" # Debian (public images)
    # Debian suele usar “amd64” en el nombre para x86_64
    if [[ "$ARCH" == "arm64" ]]; then
      FILTERS+=("Name=name,Values=debian-12-*-arm64-*")
    else
      FILTERS+=("Name=name,Values=debian-12-*-amd64-*")
    fi
    ;;

  "RHEL 10")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=Red Hat Enterprise Linux")
    FILTERS+=("Name=name,Values=*RHEL*10*")
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;
  "RHEL 9")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=Red Hat Enterprise Linux")
    FILTERS+=("Name=name,Values=*RHEL*9*")
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;

  "SUSE SLES 16")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=SUSE Linux")
    FILTERS+=("Name=name,Values=*SUSE*16*")
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;
  "SUSE SLES 15 SP7")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=SUSE Linux")
    FILTERS+=("Name=name,Values=*15*SP7*")
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;

  "Windows Server 2025 Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2025-English-Full-Base-*")
    ;;
  "Windows Server 2025 Core Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2025-English-Core-Base-*")
    ;;
  "Windows Server 2022 Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2022-English-Full-Base-*")
    ;;
  "Windows Server 2022 Core Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2022-English-Core-Base-*")
    ;;
  "Windows Server 2019 Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2019-English-Full-Base-*")
    ;;
  "Windows Server 2019 Core Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2019-English-Core-Base-*")
    ;;
  "Windows Server 2016 Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2016-English-Full-Base-*")
    ;;
  "Windows Server 2016 Core Base")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=Windows_Server-2016-English-Core-Base-*")
    ;;

  "Windows + SQL Server (todas)")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=Windows")
    FILTERS+=("Name=name,Values=*SQL*")
    ;;

  "Deep Learning AMIs (todas)")
    OWNER="amazon"
    FILTERS+=("Name=name,Values=*Deep Learning*")
    # si el name no contiene arch, el filtro por architecture ayuda
    FILTERS+=("Name=architecture,Values=$ARCH")
    ;;

  "macOS Sonoma")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=macOS")
    FILTERS+=("Name=name,Values=*Sonoma*")
    ;;
  "macOS Sequoia")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=macOS")
    FILTERS+=("Name=name,Values=*Sequoia*")
    ;;
  "macOS Tahoe")
    OWNER="amazon"
    FILTERS+=("Name=platform-details,Values=macOS")
    FILTERS+=("Name=name,Values=*Tahoe*")
    ;;
esac

# macOS arch “Mac/Mac-Arm” (en describe-images suele ser architecture=x86_64 o arm64, pero el catálogo habla de Mac/Mac-Arm)
# Intento: mapear a architecture si el usuario eligió Mac-Arm
if [[ "$PRODUCT" == macOS* ]]; then
  if [[ "$MAC_ARCH" == "Mac-Arm" ]]; then
    FILTERS+=("Name=architecture,Values=arm64")
  else
    FILTERS+=("Name=architecture,Values=x86_64")
  fi
fi

# Estado disponible siempre
FILTERS+=("Name=state,Values=available")

echo
echo "📡 Buscando AMIs oficiales para: $PRODUCT $( [[ -n "${ARCH:-}" && "$PRODUCT" != Windows* && "$PRODUCT" != macOS* ]] && echo "($ARCH)" ) ..."
echo "   (mostrando top $TOP_N más recientes)"
echo

# -----------------------------
# 4) Buscar y listar AMIs
# -----------------------------
# Construimos args --filters ...
FILTER_ARGS=()
for f in "${FILTERS[@]}"; do
  FILTER_ARGS+=(--filters "$f")
done

mapfile -t AMIS < <(
  aws ec2 describe-images \
    --owners "$OWNER" \
    --region "$REGION" \
    "${FILTER_ARGS[@]}" \
    --query 'Images[*].[ImageId,Name,CreationDate,Architecture,PlatformDetails]' \
    --output json |
  jq -r --argjson top "$TOP_N" '
    sort_by(.[2]) | reverse
    | .[:$top]
    | .[]
    | "\(. [0]) | \(. [1]) | \(. [2]) | arch=\(. [3]) | \(. [4])"
  '
)

if (( ${#AMIS[@]} == 0 )); then
  echo "❌ No se encontraron AMIs para '$PRODUCT' en $REGION con esos filtros."
  echo "💡 Consejo: prueba otra región o cambia producto/arquitectura."
  exit 1
fi

# -----------------------------
# 5) Selector final
# -----------------------------
echo "📀 Selecciona la AMI:"
select OPTION in "${AMIS[@]}"; do
  if [[ -n "$OPTION" ]]; then
    AMI_ID="${OPTION%% |*}"
    export AMI_ID
    echo
    echo "✅ AMI seleccionada: $AMI_ID"
    break
  else
    echo "❌ Opción inválida"
  fi
done
