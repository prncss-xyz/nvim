#!/usr/bin/env bash
set -euo pipefail

# Build against this machine's libc instead of downloading CodeDiff's glibc binary.
plugin_dir="${CODEDIFF_PLUGIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/codediff.nvim}"
plugin_dir="$(cd "$plugin_dir" && pwd)"
version="$(tr -d '[:space:]' < "$plugin_dir/VERSION")"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Build away from lazy.nvim's checkout; leave the installed library intact on failure.
cp -R "$plugin_dir/libvscode-diff" "$work_dir/"
mkdir -p "$work_dir/libvscode-diff/build/include"
sed "s/@''PROJECT_VERSION@/$version/g" \
  "$work_dir/libvscode-diff/include/version.h.in" \
  > "$work_dir/libvscode-diff/build/include/version.h"
(
  cd "$work_dir/libvscode-diff"
  # No OpenMP: the bundled glibc libgomp.so.1 is incompatible with musl.
  "${CC:-cc}" -Wall -Wextra -std=c11 -O2 -DNDEBUG -DUTF8PROC_STATIC \
    -D_POSIX_C_SOURCE=199309L -Iinclude -Ibuild/include -Ivendor \
    -fPIC -shared -o "$work_dir/libvscode_diff.so" \
    default_lines_diff_computer.c src/char_level.c src/line_level.c \
    src/myers.c src/optimize.c src/sequence.c src/range_mapping.c \
    src/string_hash_map.c src/utils.c src/print_utils.c src/utf8_utils.c \
    src/compute_moved_lines.c vendor/utf8proc.c -lm
)

library="$work_dir/libvscode_diff.so"
test -s "$library"
# The versioned file takes precedence over the unversioned manual-build fallback.
target="$plugin_dir/libvscode_diff_${version}.so"
staged="$(mktemp "$plugin_dir/.libvscode_diff.XXXXXXXX.so")"
trap 'rm -f "$staged"; rm -rf "$work_dir"' EXIT
cp "$library" "$staged"
chmod 644 "$staged"
mv -f "$staged" "$target"
printf 'Installed %s\n' "$target"
printf 'Rerun this script after updating codediff.nvim.\n'
