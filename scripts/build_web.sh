#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
dart scripts/validate_client_env.dart
flutter build web --release "$@"
