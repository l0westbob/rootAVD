#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "modular source keeps the original rootAVD function surface" {
    current="$BATS_TEST_TMPDIR/current-functions.txt"
    awk '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*\(\)[[:space:]]*\{.*/, "", line)
      print line
    }
  ' "$REPO_ROOT/rootAVD.sh" "$REPO_ROOT"/lib/rootavd/*.sh | sort -u > "$current"

    run comm -23 "$REPO_ROOT/test/fixtures/rootavd_original_functions.expected" "$current"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "generated bundle keeps the original rootAVD function surface" {
    current="$BATS_TEST_TMPDIR/bundle-functions.txt"
    "$REPO_ROOT/tools/build-rootavd-bundle.sh" > /dev/null

    awk '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*\(\)[[:space:]]*\{.*/, "", line)
      print line
    }
  ' "$REPO_ROOT/dist/rootAVD.sh" | sort -u > "$current"

    run comm -23 "$REPO_ROOT/test/fixtures/rootavd_original_functions.expected" "$current"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
