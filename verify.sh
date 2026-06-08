#!/usr/bin/env bash
# verify.sh <binary> <datafile>
set -euo pipefail
tr ',' '\n' < expected_10m.out > /tmp/expected.lines
"$1" "$2" | tr ',' '\n' > /tmp/got.lines
diff /tmp/expected.lines /tmp/got.lines && echo "PASS: $1"
