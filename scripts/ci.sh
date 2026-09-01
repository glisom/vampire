#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd -P)"
repository_root="$(cd "$script_directory/.." && pwd -P)"
cd "$repository_root"

xcodegen generate
bash -n scripts/*.sh
scripts/test-public-repo.sh
scripts/test-ci-config.sh
scripts/test-scripts.sh

xcodebuild -project Insomnia.xcodeproj -scheme InsomniaTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaHelperTests -destination 'platform=macOS' test
xcodebuild -project Insomnia.xcodeproj -scheme InsomniaIntegrationTests -destination 'platform=macOS' test
