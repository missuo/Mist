#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

xcrun clang -fobjc-arc -O2 \
  -framework Foundation -framework UniformTypeIdentifiers \
  -I Mist/Models -I Mist/Services/Providers -I Mist/Services/Utilities \
  tests/S3URLTests.m \
  Mist/Models/MSTS3HostConfig.m \
  Mist/Services/Providers/MSTS3Provider.m \
  Mist/Services/Utilities/MSTUploadUtilities.m \
  Mist/Services/Utilities/MSTCryptoHelper.m \
  -o "$test_dir/s3-url-tests"

"$test_dir/s3-url-tests"
