#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "generated and runtime files are ignored by default" {
    run git -C "$REPO_ROOT" check-ignore \
        dist/rootAVD.sh \
        .idea/workspace.xml \
        Apps/example.apk \
        initramfs.img \
        bzImage \
        local.rc \
        libbusybox-example.so \
        sbin-test

    [ "$status" -eq 0 ]
}

@test "Apps placeholder remains visible to git" {
    run git -C "$REPO_ROOT" check-ignore Apps/.gitkeep

    [ "$status" -eq 1 ]
}

@test "public shell entrypoints and tools stay executable" {
    run bash -c '
    repo_root="$1"
    missing=0

    for executable_file in \
      rootAVD.sh \
      tools/build-rootavd-bundle.sh \
      tools/check.sh \
      tools/smoke-adb-load.sh \
      tools/smoke-nondestructive.sh
    do
      if [ ! -x "$repo_root/$executable_file" ]; then
        printf "not executable: %s\n" "$executable_file"
        missing=1
      fi
    done

    exit "$missing"
  ' _ "$REPO_ROOT"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "first-party modules avoid broad undefined-variable suppressions" {
    run bash -c '
    repo_root="$1"
    violations="$2"
    : > "$violations"

    while IFS= read -r -d "" module_file; do
      case "${module_file##*/}" in
        bluestacks_loader_template.sh) continue ;;
      esac

      if sed -n "1,5p" "$module_file" | grep -Eq "# shellcheck disable=.*SC2154"; then
        printf "%s\n" "${module_file#$repo_root/}" >> "$violations"
      fi
    done < <(find "$repo_root/lib/rootavd" -name "*.sh" -print0)

    cat "$violations"
  ' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR/broad-sc2154.txt"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "ordinary modules avoid ShellCheck suppressions" {
    run bash -c '
    repo_root="$1"
    violations="$2"
    : > "$violations"

    while IFS= read -r -d "" module_file; do
      case "${module_file##*/}" in
        bluestacks_loader_template.sh) continue ;;
      esac

      if grep -n "# shellcheck disable=" "$module_file" > /dev/null; then
        printf "%s\n" "${module_file#$repo_root/}" >> "$violations"
      fi
    done < <(find "$repo_root/lib/rootavd" -name "*.sh" -print0)

    cat "$violations"
  ' _ "$REPO_ROOT" "$BATS_TEST_TMPDIR/module-suppressions.txt"

    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
