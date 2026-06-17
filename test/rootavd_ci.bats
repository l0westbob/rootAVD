#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  WORKFLOW="$REPO_ROOT/.github/workflows/check.yml"
}

@test "GitHub Actions workflow runs the same local check gate" {
  [ -f "$WORKFLOW" ]

  run grep -F 'run: ./tools/check.sh' "$WORKFLOW"

  [ "$status" -eq 0 ]
}

@test "GitHub Actions workflow installs required shell quality tools" {
  run grep -F 'sudo apt-get install -y bats shellcheck shfmt' "$WORKFLOW"

  [ "$status" -eq 0 ]
}

@test "local check gate keeps full ShellCheck severity coverage" {
  run grep -F 'shellcheck --severity=style' "$REPO_ROOT/tools/check.sh"

  [ "$status" -eq 0 ]
}

@test "local check gate accepts CRLF Windows wrapper lines" {
  run grep -F 'cr-at-eol' "$REPO_ROOT/tools/check.sh"

  [ "$status" -eq 0 ]
}

@test "README documents the GitHub Actions check gate" {
  run grep -F '.github/workflows/check.yml' "$REPO_ROOT/README.md"

  [ "$status" -eq 0 ]
}
