#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./proofs}"
mkdir -p "$OUT_DIR"

cat > "${OUT_DIR}/auth1.pca" <<'EOF'
EOF

cat > "${OUT_DIR}/auth1.pcx" <<'EOF'
x : admin says mayGrade(kz3, kz3, hw1)
EOF

cat > "${OUT_DIR}/auth2.pca" <<'EOF'
EOF

cat > "${OUT_DIR}/auth2.pcx" <<'EOF'
x : journal says publish(article1)
EOF

cat > "${OUT_DIR}/auth3.pca" <<'EOF'
EOF

cat > "${OUT_DIR}/auth3.pcx" <<'EOF'
x : hipaa says mayRead(keyam, mfredrikmr)
EOF

cat > "${OUT_DIR}/auth4.pca" <<'EOF'
EOF

cat > "${OUT_DIR}/auth4.pcx" <<'EOF'
x : admin says mayRead(ziyongm, file1)
EOF

cat > "${OUT_DIR}/auth5.pca" <<'EOF'
EOF

cat > "${OUT_DIR}/auth5.pcx" <<'EOF'
x : admin says mayOpen(skuchib2, ghc6017)
EOF

echo "Wrote proof templates to: $OUT_DIR"
echo "Each auth<n>.pca is empty by default."
echo "Each auth<n>.pcx has a parseable placeholder typing that you should replace with your real proof."
echo "Files:"
ls -1 "$OUT_DIR"/auth{1,2,3,4,5}.{pca,pcx}
