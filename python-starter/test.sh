#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR" || exit 1

pass_count=0
fail_count=0

report_pass() {
  local name="$1"
  echo "[PASS] $name"
  pass_count=$((pass_count + 1))
}

report_fail() {
  local name="$1"
  local expected="$2"
  local got="$3"
  echo "[FAIL] $name (expected exit $expected, got $got)"
  fail_count=$((fail_count + 1))
}

run_case() {
  local name="$1"
  local expected_code="$2"
  shift 2

  set +e
  local output
  output="$("$@" 2>&1)"
  local code=$?
  set -e

  echo "----- $name output begin -----"
  echo "$output"
  echo "----- $name output end -------"

  if [ "$code" -eq "$expected_code" ]; then
    report_pass "$name"
  else
    report_fail "$name" "$expected_code" "$code"
  fi
}

cleanup() {
  rm -f .tmp_example.pca .tmp_example.pcx .tmp_bad.pcx .tmp_malformed.pca
}

trap cleanup EXIT

cat > .tmp_example.pca <<'EOF'
c1 : admin says (!X. p(X) -> q(X));
c2 : admin says p(nineteen);
EOF

cat > .tmp_example.pcx <<'EOF'
{
let {x1}_admin = c1 in
let {x2}_admin = c2 in
x1 [nineteen] x2
}_admin
:
admin says q(nineteen)
EOF

cat > .tmp_bad.pcx <<'EOF'
{
let {x1}_admin = c1 in
x1 [nineteen]
}_admin
:
admin says q(nineteen)
EOF

cat > .tmp_malformed.pca <<'EOF'
c1 : admin says p(;
EOF

if [ -x "./pca_serve" ]; then
  SERVE_CMD=(./pca_serve)
else
  SERVE_CMD=(bash ./pca_serve.sh)
fi

set -e
run_case "example should succeed" 0 "${SERVE_CMD[@]}" .tmp_example.pca .tmp_example.pcx
run_case "bad proof should fail" 2 "${SERVE_CMD[@]}" .tmp_example.pca .tmp_bad.pcx
run_case "malformed policy should error" 1 "${SERVE_CMD[@]}" .tmp_malformed.pca .tmp_example.pcx

echo
echo "Summary: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
