#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "BlueStacks loader template output stays stable" {
    run bash -c '
    SOURCING=true source "$1"
    MAGISKBASE=/magisk
    RM_RUSTY_MAGISK=""
    remove_backup=""
    random_count=0
    random_str() {
      random_count=$((random_count + 1))
      printf "token%s\n" "$random_count"
    }
    magisk_loader
    printf "%s" "$overlay_loader" | cksum
    printf "%s" "$magiskloader" | cksum
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "999044680 7078" ]
    [ "${lines[1]}" = "4141881016 2035" ]
}

@test "BlueStacks overlay keeps runtime loop variables escaped" {
    run bash -c '
    SOURCING=true source "$1"
    MAGISKBASE=/magisk
    RM_RUSTY_MAGISK=""
    remove_backup=""
    random_count=0
    random_str() {
      random_count=$((random_count + 1))
      printf "token%s\n" "$random_count"
    }
    magisk_loader

    printf "%s\n" "$overlay_loader" | grep -F "[ \"\$count\" -gt \"10\" ] && break"
    printf "%s\n" "$overlay_loader" | grep -F "count=\$((\$count + 1))"
  ' _ "$REPO_ROOT/rootAVD.sh"

    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[ \"\$count\" -gt \"10\" ] && break" ]
    [ "${lines[1]}" = "count=\$((\$count + 1))" ]
}
