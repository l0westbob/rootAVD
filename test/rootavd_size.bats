#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "entrypoint, modules, and tools stay within maintainability line budgets" {
    run bash -c '
    repo_root="$1"

    check_max_lines() {
      max_lines="$1"
      file="$2"
      line_count=$(wc -l < "$file")

      if [ "$line_count" -gt "$max_lines" ]; then
        printf "%s has %s lines, expected at most %s\n" "$file" "$line_count" "$max_lines"
        return 1
      fi
    }

    check_max_lines 100 "$repo_root/rootAVD.sh"

    while IFS= read -r -d "" module_file; do
      check_max_lines 500 "$module_file" || exit 1
    done < <(find "$repo_root/lib/rootavd" -name "*.sh" -print0)

    while IFS= read -r -d "" tool_file; do
      check_max_lines 200 "$tool_file" || exit 1
    done < <(find "$repo_root/tools" -maxdepth 1 -name "*.sh" -print0)
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
