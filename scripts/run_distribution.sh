#!/bin/bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/appdab-distribution.XXXXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
swiftc "$script_dir"/Distribution/*.swift -o "$build_dir/distribution"
"$build_dir/distribution" "$@"
