#!/usr/bin/env bash
# Regenerates the committed EOS bindings (lib/src/eos_bindings.dart) from a
# locally-downloaded, EULA-accepted EOS C SDK.
#
#   EOS_SDK_DIR=/path/to/EOS-SDK ./tool/regenerate_bindings.sh
#
# The EOS SDK is login + EULA gated (https://onlineservices.epicgames.com/sdk).
# Its headers and runtime libs are NOT redistributable — do not commit them.
# We commit only the generated .dart (our description of the API surface), the
# same posture as the Steamworks and GameKit bindings in this repo.
#
# EOS_SDK_DIR must point at the extracted SDK root containing `SDK/Include`
# (and `SDK/Bin/<platform>` for the runtime lib the host ships).
set -euo pipefail
cd "$(dirname "$0")/.."

: "${EOS_SDK_DIR:?Set EOS_SDK_DIR to the extracted EOS SDK root (with SDK/Include). The SDK is login-gated: download it from https://onlineservices.epicgames.com/sdk}"

INCLUDE="$EOS_SDK_DIR/SDK/Include"
[ -d "$INCLUDE" ] || INCLUDE="$EOS_SDK_DIR/Include"
[ -d "$INCLUDE" ] || { echo "No Include/ under $EOS_SDK_DIR (looked for SDK/Include and Include)"; exit 1; }

# ffigen reads headers from ./.eos-sdk/Include (gitignored). Link the SDK there.
rm -rf .eos-sdk
mkdir -p .eos-sdk
ln -s "$INCLUDE" .eos-sdk/Include

dart run ffigen --config ffigen_eos.yaml

dart format lib/src/eos_bindings.dart >/dev/null
rm -rf .eos-sdk
echo "Bindings regenerated from $INCLUDE"
echo "NOTE: ship the matching runtime lib from $EOS_SDK_DIR/SDK/Bin next to your executable:"
echo "  Windows: EOSSDK-Win64-Shipping.dll   macOS: libEOSSDK-Mac-Shipping.dylib   Linux: libEOSSDK-Linux-Shipping.so"
