#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
Usage: ./retrieve_secrets.sh [options]

Runs pca_serve1..5 (or a custom target list), captures secrets from successful
authorizations, and writes pca_auth<n>.txt files.

Options:
  --serve-base PATH      Prefix for server binaries (default: ~mfredrik/bin/pca_serve)
                         Example: if PATH=/x/pca_serve, script runs /x/pca_serve1, /x/pca_serve2, ...
  --pca-template PATH    Template for .pca files, must include "{n}" (default: ./auth{n}.pca)
  --pcx-template PATH    Template for .pcx files, must include "{n}" (default: ./auth{n}.pcx)
  --targets LIST         Comma-separated challenge numbers (default: 1,2,3,4,5)
  --out-dir DIR          Directory for pca_auth<n>.txt outputs (default: .)
  --overwrite            Overwrite existing pca_auth<n>.txt files
  --help                 Show this message

Example:
  ./retrieve_secrets.sh \
    --pca-template ./proofs/auth{n}.pca \
    --pcx-template ./proofs/auth{n}.pcx \
    --out-dir ./secrets
EOF
}

replace_n() {
  local template="$1"
  local n="$2"
  printf '%s' "${template//\{n\}/$n}"
}

expand_user_path() {
  local path="$1"
  if [[ "$path" == "~/"* ]]; then
    printf '%s' "${HOME}${path:1}"
    return
  fi

  if [[ "$path" =~ ^~([A-Za-z_][A-Za-z_0-9-]*)(/.*)?$ ]]; then
    local user="${BASH_REMATCH[1]}"
    local rest="${BASH_REMATCH[2]}"
    local user_home
    user_home="$(getent passwd "$user" | cut -d: -f6)"
    if [[ -n "$user_home" ]]; then
      printf '%s' "${user_home}${rest}"
      return
    fi
  fi

  printf '%s' "$path"
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SERVE_BASE="~mfredrik/bin/pca_serve"
PCA_TEMPLATE="./auth{n}.pca"
PCX_TEMPLATE="./auth{n}.pcx"
TARGETS="1,2,3,4,5"
OUT_DIR="."
OVERWRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serve-base)
      SERVE_BASE="$2"
      shift 2
      ;;
    --pca-template)
      PCA_TEMPLATE="$2"
      shift 2
      ;;
    --pcx-template)
      PCX_TEMPLATE="$2"
      shift 2
      ;;
    --targets)
      TARGETS="$2"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$PCA_TEMPLATE" != *"{n}"* ]]; then
  echo "--pca-template must include {n}" >&2
  exit 2
fi

if [[ "$PCX_TEMPLATE" != *"{n}"* ]]; then
  echo "--pcx-template must include {n}" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"

IFS=',' read -r -a TARGET_LIST <<< "$TARGETS"

retrieved=0
unresolved=0
errors=0

for n_raw in "${TARGET_LIST[@]}"; do
  n="$(echo "$n_raw" | xargs)"
  if [[ ! "$n" =~ ^[0-9]+$ ]]; then
    echo "[ERROR] Invalid target number: $n_raw" >&2
    errors=$((errors + 1))
    continue
  fi

  serve_bin_template="${SERVE_BASE}${n}"
  serve_bin="$(expand_user_path "$serve_bin_template")"
  pca_file="$(replace_n "$PCA_TEMPLATE" "$n")"
  pcx_file="$(replace_n "$PCX_TEMPLATE" "$n")"
  out_file="${OUT_DIR}/pca_auth${n}.txt"

  echo "== Challenge $n =="
  echo "  server: $serve_bin"
  echo "  pca:    $pca_file"
  echo "  pcx:    $pcx_file"

  if [[ ! -x "$serve_bin" ]]; then
    echo "  [ERROR] Server binary not executable: $serve_bin" >&2
    if [[ "$serve_bin" == "$HOME/mfredrik/bin/"* ]]; then
      echo "  [HINT] You likely used ~/mfredrik/... which expands inside your own home." >&2
      echo "         Use ~mfredrik/bin/pca_serve (no slash after ~)." >&2
    fi
    errors=$((errors + 1))
    continue
  fi

  if [[ ! -f "$pca_file" ]]; then
    echo "  [ERROR] Missing .pca file: $pca_file" >&2
    errors=$((errors + 1))
    continue
  fi

  if [[ ! -f "$pcx_file" ]]; then
    echo "  [ERROR] Missing .pcx file: $pcx_file" >&2
    errors=$((errors + 1))
    continue
  fi

  if [[ -f "$out_file" && "$OVERWRITE" -ne 1 ]]; then
    echo "  [SKIP] Output exists (use --overwrite): $out_file"
    continue
  fi

  set +e
  output="$("$serve_bin" "$pca_file" "$pcx_file" 2>&1)"
  code=$?
  set -e

  printf '%s\n' "$output"

  secret=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^success[[:space:]]+(.+)$ ]]; then
      secret="${BASH_REMATCH[1]}"
    fi
  done <<< "$output"

  if [[ "$code" -eq 0 && -n "$secret" ]]; then
    printf '%s\n' "$secret" > "$out_file"
    echo "  [OK] Wrote secret to $out_file"
    retrieved=$((retrieved + 1))
  else
    echo "  [NO SECRET] exit=$code"
    unresolved=$((unresolved + 1))
  fi
done

echo
echo "Summary:"
echo "  retrieved:  $retrieved"
echo "  unresolved: $unresolved"
echo "  errors:     $errors"

if [[ "$errors" -ne 0 ]]; then
  exit 1
fi

