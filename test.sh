#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/dictation-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
swiftc Sources/Voxea/KeyState.swift Tests/main.swift -o "$test_dir/key-tests"
"$test_dir/key-tests"

swiftc -I Sources/CSQLite Sources/Voxea/CorrectionStore.swift Sources/Voxea/CorrectionEngine.swift Tests/Memory/main.swift -o "$test_dir/memory-tests"
"$test_dir/memory-tests"

swiftc Sources/Voxea/Formatting.swift Tests/Formatting/main.swift -o "$test_dir/formatting-tests"
"$test_dir/formatting-tests"

swiftc Sources/Voxea/Diagnostics.swift Sources/Voxea/TextDelivery.swift Tests/Delivery/main.swift -o "$test_dir/delivery-tests"
"$test_dir/delivery-tests"
