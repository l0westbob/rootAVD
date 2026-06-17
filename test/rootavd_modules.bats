#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "planned rootAVD module set is exact" {
  actual="$BATS_TEST_TMPDIR/actual-modules.txt"

  find "$REPO_ROOT/lib/rootavd" -maxdepth 1 -type f -name '*.sh' \
    -exec basename {} \; | sort > "$actual"

  run diff -u "$REPO_ROOT/test/fixtures/rootavd_required_modules.expected" "$actual"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "module loading list covers every non-bootstrap module exactly once" {
  listed="$BATS_TEST_TMPDIR/listed-modules.txt"
  listed_sorted="$BATS_TEST_TMPDIR/listed-modules.sorted"
  actual_sorted="$BATS_TEST_TMPDIR/actual-modules.sorted"

  run bash -c 'source "$1" SOURCING >/dev/null; rootavd_module_files' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  printf "%s\n" "$output" > "$listed"
  sort "$listed" > "$listed_sorted"
  find "$REPO_ROOT/lib/rootavd" -maxdepth 1 -type f -name '*.sh' \
    ! -name 'bootstrap.sh' -exec basename {} \; | sort > "$actual_sorted"

  run comm -3 "$listed_sorted" "$actual_sorted"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]

  run sh -c 'sort "$1" | uniq -d' _ "$listed"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "listed modules can be sourced as libraries without output" {
  run bash -c '
    ROOTAVD="$1"
    ROOTAVD_LIB_DIR="$ROOTAVD/lib/rootavd"
    ROOTAVD_BUNDLED=false

    # shellcheck disable=SC1091
    . "$ROOTAVD_LIB_DIR/bootstrap.sh"

    while IFS= read -r module; do
      [ -n "$module" ] || continue
      # shellcheck source=/dev/null
      . "$ROOTAVD_LIB_DIR/$module"
    done << ROOTAVD_MODULE_LIST
$(rootavd_module_files)
ROOTAVD_MODULE_LIST
  ' _ "$REPO_ROOT"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "library modules keep shell exits behind explicit abort or template boundaries" {
  matches="$BATS_TEST_TMPDIR/module-exits.txt"
  violations="$BATS_TEST_TMPDIR/module-exit-violations.txt"
  : > "$violations"

  if grep -R -n -E '(^|[;&({[:space:]])exit([[:space:]]|$)' "$REPO_ROOT/lib/rootavd" > "$matches"; then
    :
  fi

  while IFS=: read -r file line text; do
    [ -n "$file" ] || continue
    case "$file:$line" in
      "$REPO_ROOT/lib/rootavd/bootstrap.sh:15") continue ;;
      "$REPO_ROOT/lib/rootavd/bluestacks_loader_template.sh:"*) continue ;;
      "$REPO_ROOT/lib/rootavd/apps.sh:17") continue ;;
    esac
    printf "%s:%s:%s\n" "$file" "$line" "$text" >> "$violations"
  done < "$matches"

  run cat "$violations"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "root loader and modules parse with sh for emulator payload execution" {
  run sh -c '
    root="$1"
    sh -n "$root/rootAVD.sh"
    find "$root/lib/rootavd" -name "*.sh" -exec sh -n {} \;
  ' _ "$REPO_ROOT"

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
