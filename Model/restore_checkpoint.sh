#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/best_train_synth_plus_verified_latest_vocab_current_q20260504_072444.pt"

cat "$SCRIPT_DIR"/checkpoint_parts/checkpoint.pt.part-* > "$OUT"

if command -v sha256sum >/dev/null 2>&1; then
  echo "cef269a11f1da1b80088d8f621f47a0499194d305f93e23e1e366879d50bfd0e  $OUT" | sha256sum -c -
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$OUT" | awk '{print $1}')"
  expected="cef269a11f1da1b80088d8f621f47a0499194d305f93e23e1e366879d50bfd0e"
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA256 mismatch: expected $expected, got $actual" >&2
    exit 1
  fi
  echo "$OUT: OK"
else
  echo "Checkpoint restored: $OUT"
  echo "Expected SHA256: cef269a11f1da1b80088d8f621f47a0499194d305f93e23e1e366879d50bfd0e"
fi
