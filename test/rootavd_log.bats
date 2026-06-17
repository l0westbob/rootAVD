#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "log helpers preserve legacy output prefixes" {
  run bash -c '
    SOURCING=true source "$1" SOURCING
    info "info message"
    warn "warn message"
    question "question message"
  ' _ "$REPO_ROOT/rootAVD.sh"

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "[*] info message" ]
  [ "${lines[1]}" = "[-] warn message" ]
  [ "${lines[2]}" = "[?] question message" ]
}

@test "error helper writes legacy error prefix to stderr" {
  stdout="$BATS_TEST_TMPDIR/stdout.txt"
  stderr="$BATS_TEST_TMPDIR/stderr.txt"

  bash -c '
    SOURCING=true source "$1" SOURCING
    error "error message"
  ' _ "$REPO_ROOT/rootAVD.sh" >"$stdout" 2>"$stderr"

  [ "$(cat "$stdout")" = "" ]
  [ "$(cat "$stderr")" = "[!] error message" ]
}
