#!/bin/bash

resolve_flutter_env() {
  local requested_env="${1:-${APP_ENV:-prod}}"

  case "$requested_env" in
    dev|prod) ;;
    *)
      echo "APP_ENV must be dev or prod. Received: ${requested_env}" >&2
      exit 1
      ;;
  esac

  local config_file="./config/${requested_env}.json"

  if [ ! -f "$config_file" ]; then
    echo "Missing ${config_file}" >&2
    echo "Create it from config/${requested_env}.example.json before building." >&2
    exit 1
  fi

  if grep -Eq "service[_-]?role|SUPABASE_SERVICE_ROLE_KEY" "$config_file"; then
    echo "${config_file} appears to contain a service role key. Use only the public anon key in app builds." >&2
    exit 1
  fi

  if ! grep -q '"SUPABASE_URL"' "$config_file"; then
    echo "${config_file} must define SUPABASE_URL." >&2
    exit 1
  fi

  if ! grep -q '"SUPABASE_ANON_KEY"' "$config_file"; then
    echo "${config_file} must define SUPABASE_ANON_KEY." >&2
    exit 1
  fi

  if ! grep -q "\"APP_ENV\"[[:space:]]*:[[:space:]]*\"${requested_env}\"" "$config_file"; then
    echo "${config_file} must define APP_ENV as \"${requested_env}\"." >&2
    exit 1
  fi

  FLUTTER_ENV_NAME="$requested_env"
  FLUTTER_ENV_CONFIG_FILE="$config_file"
  FLUTTER_ENV_ARGS=(--dart-define-from-file="$config_file")

  echo "🌿 Using ${FLUTTER_ENV_NAME} config: ${FLUTTER_ENV_CONFIG_FILE}"
}

resolve_flutter_build_version() {
  if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
    echo "❌ Cannot calculate a reliable build number from a shallow clone."
    echo "   Run: git fetch --unshallow"
    exit 1
  fi

  local app_version
  app_version=$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml)

  if [[ -z "$app_version" ]]; then
    echo "❌ Missing version in pubspec.yaml."
    exit 1
  fi

  FLUTTER_BUILD_NAME="${app_version%%+*}"
  FLUTTER_BUILD_NUMBER=$(git rev-list --count HEAD)
  FLUTTER_BUILD_VERSION_ARGS=(
    "--build-name=$FLUTTER_BUILD_NAME"
    "--build-number=$FLUTTER_BUILD_NUMBER"
  )

  echo "🏷️  Version: $FLUTTER_BUILD_NAME+$FLUTTER_BUILD_NUMBER"
}
