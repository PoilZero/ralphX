#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
TMP_ROOT="$WORKSPACE_ROOT/tmp"

mkdir -p "$TMP_ROOT"

STUB_DIR="$TMP_ROOT/ralphx-color-stubs-$$"
BASE_DIR="$TMP_ROOT/ralphx-color-tests-$$"

mkdir -p "$STUB_DIR" "$BASE_DIR"

create_stub() {
  local name="$1"
  cat > "$STUB_DIR/$name" <<'EOS'
#!/usr/bin/env bash
set -e
printf '<promise>COMPLETE</promise>\n'
EOS
  chmod +x "$STUB_DIR/$name"
}

create_stub "amp"

run_case() {
  local name="$1"
  local workdir="$BASE_DIR/$name"
  shift
  mkdir -p "$workdir"
  "$@" >"$workdir/run.log" 2>&1
  printf '%s\n' "$workdir"
}

# Case 1: RALPHX_COLOR=always emits ANSI
case1_dir=$(run_case "color-always" bash -c "cd \"$BASE_DIR/color-always\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_COLOR=always \"$ROOT_DIR/ralph.sh\" \"Color test always\" 1")
if ! grep -q $'\x1b' "$case1_dir/run.log"; then
  echo "Assertion failed: expected ANSI escapes with RALPHX_COLOR=always" >&2
  exit 1
fi

# Case 2: RALPHX_COLOR=never emits no ANSI
case2_dir=$(run_case "color-never" bash -c "cd \"$BASE_DIR/color-never\" && PATH=\"$STUB_DIR:\$PATH\" RALPHX_COLOR=never \"$ROOT_DIR/ralph.sh\" \"Color test never\" 1")
if grep -q $'\x1b' "$case2_dir/run.log"; then
  echo "Assertion failed: expected no ANSI escapes with RALPHX_COLOR=never" >&2
  exit 1
fi

echo "OK: cli color tests passed"
