#!/bin/bash
# Shared local/GitHub build and full-suite check. No test exclusions or retries.
set -euo pipefail

phase="${1:-}"
simulator_id="${2:-}"
case "$phase" in
  build|test|all) ;;
  *) echo 'Usage: bash scripts/ci.sh {build|test|all} <simulator-UDID>' >&2; exit 2 ;;
esac
if [[ -z "$simulator_id" ]]; then
  echo 'An installed simulator UDID is required.' >&2
  exit 2
fi

cd "$(dirname "$0")/.."
export TZ=UTC
DERIVED_DATA="${DERIVED_DATA:-$PWD/DerivedData}"
RESULT_BUNDLE="${RESULT_BUNDLE:-$DERIVED_DATA/CIResults/Glow-$(uuidgen).xcresult}"

common_args=(
  -project Glow.xcodeproj
  -scheme Glow
  -configuration Debug
  -destination "platform=iOS Simulator,id=$simulator_id"
  -derivedDataPath "$DERIVED_DATA"
  IPHONEOS_DEPLOYMENT_TARGET=26.0
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
  GCC_TREAT_WARNINGS_AS_ERRORS=YES
)

build_for_testing() {
  xcodebuild "${common_args[@]}" clean build-for-testing
}

run_tests() {
  xcrun simctl bootstatus "$simulator_id" -b
  mkdir -p "$(dirname "$RESULT_BUNDLE")"
  xcodebuild "${common_args[@]}" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -testLanguage en -testRegion US \
    test-without-building
}

case "$phase" in
  build) build_for_testing ;;
  test) run_tests ;;
  all)
    # Start boot without waiting, as in the GitHub workflow.
    simulator_state="$(xcrun simctl list devices --json | python3 -c '
import json, sys
devices = (device for group in json.load(sys.stdin)["devices"].values() for device in group)
device = next((device for device in devices if device["udid"] == sys.argv[1]), None)
if device is None:
    raise SystemExit("Simulator UDID was not found.")
print(device["state"])
' "$simulator_id")"
    if [[ "$simulator_state" != Booted ]]; then
      xcrun simctl boot "$simulator_id"
    fi
    build_for_testing
    run_tests
    ;;
esac
