#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" > /dev/null 2>&1; then
        printf '[!] Required command not found: %s\n' "$command_name" >&2
        return 1
    fi
}

check_max_lines() {
    local max_lines="$1"
    local file="$2"
    local line_count

    line_count=$(wc -l < "$file")
    if [ "$line_count" -gt "$max_lines" ]; then
        printf '[!] %s has %s lines, expected at most %s\n' "$file" "$line_count" "$max_lines" >&2
        return 1
    fi
}

require_command bash
require_command sh
require_command git
require_command shellcheck
require_command shfmt
require_command bats

check_max_lines 100 rootAVD.sh

if [ -d lib/rootavd ]; then
    while IFS= read -r -d '' file; do
        check_max_lines 500 "$file"
    done < <(find lib/rootavd -name '*.sh' -print0)
fi

while IFS= read -r -d '' file; do
    check_max_lines 200 "$file"
done < <(find tools -maxdepth 1 -name '*.sh' -print0)

bash -n rootAVD.sh
sh -n rootAVD.sh

if [ -d lib/rootavd ]; then
    while IFS= read -r -d '' file; do
        bash -n "$file"
        sh -n "$file"
    done < <(find lib/rootavd -name '*.sh' -print0)
fi

shellcheck --severity=style rootAVD.sh tools/*.sh

if [ -d lib/rootavd ]; then
    shellcheck --severity=style lib/rootavd/*.sh
fi

if [ -d test ]; then
    shellcheck --severity=style test/*.bats
fi

shfmt_files=(rootAVD.sh tools/*.sh)
if [ -d lib/rootavd ]; then
    while IFS= read -r -d '' file; do
        shfmt_files+=("$file")
    done < <(find lib/rootavd -name '*.sh' ! -name 'bluestacks_loader_template.sh' -print0)
fi
shfmt -d -i 4 -ci -sr "${shfmt_files[@]}"

git -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol diff --check
tools/build-rootavd-bundle.sh
tools/smoke-nondestructive.sh
bats test
