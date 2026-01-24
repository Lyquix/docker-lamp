#!/bin/bash
set -euo pipefail

# -----------------------------
# Sudo handling
# -----------------------------
NO_SUDO=0
for PARAM in "$@"; do
  if [ "$PARAM" = "--no-sudo" ]; then
    NO_SUDO=1
  fi
done

if [[ ${EUID:-999} -ne 0 ]]; then
  printf "This script must be run as root!\n"
  if [ "$NO_SUDO" -eq 0 ]; then
    exec sudo /bin/bash "$0" "$@" --no-sudo
  fi
  exit 1
fi

# -----------------------------
# Detect PHP version and paths
# -----------------------------
if ! command -v php >/dev/null 2>&1; then
  echo "php command not found. Please install PHP first."
  exit 1
fi

PHP_VERSION="$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;" 2>/dev/null || true)"
if [[ -z "$PHP_VERSION" ]]; then
  echo "Unable to detect PHP version."
  exit 1
fi

XDEBUG_INI_FILE="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"

# -----------------------------
# Helpers
# -----------------------------
is_valid_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  local IFS='.'
  read -r o1 o2 o3 o4 <<<"$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

# Extract xdebug.client_host value (if present)
get_configured_ip() {
  local file="$1"
  if [[ -f "$file" ]]; then
    # take the last occurrence, ignore comments, trim spaces
    awk -F= '
      $0 !~ /^[[:space:]]*;/ && $0 !~ /^[[:space:]]*#/ && $1 ~ /^[[:space:]]*xdebug\.client_host[[:space:]]*$/ {
        gsub(/[[:space:]]/, "", $2);
        ip=$2
      }
      END { if (ip != "") print ip }
    ' "$file"
  fi
}

# -----------------------------
# Xdebug install check
# -----------------------------
check_xdebug_installed() {
  if php -m 2>/dev/null | grep -qi '^xdebug$'; then
    echo "Xdebug is already installed."
    return 0
  fi

  echo "Xdebug is not installed. Installing Xdebug..."
  apt-get update
  apt-get install -y php-xdebug
  return 1
}

# -----------------------------
# Xdebug config check
# -----------------------------
check_xdebug_configured() {
  # Required lines (we accept whitespace variations; exact values for most keys)
  local -a required_patterns=(
    '^[[:space:]]*zend_extension[[:space:]]*=[[:space:]]*xdebug\.so[[:space:]]*$'
    '^[[:space:]]*xdebug\.mode[[:space:]]*=[[:space:]]*develop,debug[[:space:]]*$'
    '^[[:space:]]*xdebug\.client_host[[:space:]]*=[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[[:space:]]*$'
    '^[[:space:]]*xdebug\.client_port[[:space:]]*=[[:space:]]*9003[[:space:]]*$'
    '^[[:space:]]*xdebug\.max_nesting_level[[:space:]]*=[[:space:]]*500[[:space:]]*$'
    '^[[:space:]]*xdebug\.start_with_request[[:space:]]*=[[:space:]]*yes[[:space:]]*$'
    '^[[:space:]]*xdebug\.discover_client_host[[:space:]]*=[[:space:]]*0[[:space:]]*$'
    '^[[:space:]]*xdebug\.idekey[[:space:]]*=[[:space:]]*vsc[[:space:]]*$'
  )

  if [[ ! -f "$XDEBUG_INI_FILE" ]]; then
    echo "Xdebug is not configured (ini file not found: $XDEBUG_INI_FILE)."
    return 1
  fi

  # Check for required settings
  for pat in "${required_patterns[@]}"; do
    if ! grep -Eq "$pat" "$XDEBUG_INI_FILE"; then
      echo "Xdebug is not configured (missing/incorrect setting matching: $pat)."
      return 1
    fi
  done

  # Validate IP specifically
  local ip
  ip="$(get_configured_ip "$XDEBUG_INI_FILE" || true)"
  if [[ -z "$ip" ]] || ! is_valid_ipv4 "$ip"; then
    echo "Xdebug is not configured (invalid or missing xdebug.client_host)."
    return 1
  fi

  echo "Xdebug is already configured. Configured client host IP: $ip"
  return 0
}

# -----------------------------
# Configure Xdebug
# -----------------------------
xdebug_config() {
  echo "Configuring Xdebug..."
  echo "Please obtain the IP address of WSL by running the following command on the Windows Command Prompt:"
  echo "  wsl hostname -I"
  echo

  local WSL_IP=""
  while true; do
    read -r -p "Enter the WSL IP address: " WSL_IP
    if is_valid_ipv4 "$WSL_IP"; then
      break
    fi
    echo "Invalid IP address"
  done

  # Write config atomically
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
zend_extension=xdebug.so
xdebug.mode=develop,debug
xdebug.client_host=${WSL_IP}
xdebug.client_port=9003
xdebug.max_nesting_level=500
xdebug.start_with_request=yes
xdebug.discover_client_host=0
xdebug.idekey=vsc
EOF

  mkdir -p "$(dirname "$XDEBUG_INI_FILE")"
  mv "$tmp" "$XDEBUG_INI_FILE"
}

# -----------------------------
# Main action
# -----------------------------
toggle_xdebug() {
  local action=""

  # Parse args (allow flags in any order)
  for arg in "$@"; do
    case "$arg" in
      enable|disable)
        action="$arg"
        ;;
      --no-sudo)
        : # already handled earlier
        ;;
      *)
        echo "Unknown argument: $arg"
        echo "Usage: $0 [--no-sudo] {enable|disable}"
        exit 1
        ;;
    esac
  done

  if [[ -z "$action" ]]; then
    echo "Usage: $0 [--no-sudo] {enable|disable}"
    exit 1
  fi

  # Enable/disable module
  if [[ "$action" == "enable" ]]; then
    check_xdebug_installed >/dev/null || true

    local configured=0
    if check_xdebug_configured; then
        configured=1
    fi

    # Prompt user about configuration
    if [[ "$configured" -eq 1 ]]; then
        read -r -p "Xdebug is configured. Do you want to reconfigure it? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
        xdebug_config
        fi
    else
        xdebug_config
    fi

    phpenmod xdebug
    echo "Xdebug enabled"
  else
    phpdismod xdebug
    echo "Xdebug disabled"
  fi

  # Restart services (best-effort depending on installed stack)
  if command -v service >/dev/null 2>&1; then
    if service "php${PHP_VERSION}-fpm" status >/dev/null 2>&1; then
      service "php${PHP_VERSION}-fpm" restart
    fi
    if service apache2 status >/dev/null 2>&1; then
      service apache2 restart
    fi
  fi
}

toggle_xdebug "$@"
