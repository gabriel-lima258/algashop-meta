#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MICROSERVICES=(
  authorization-server
  algashop-billing
  billing-scheduler
  api-gateway-admin
  api-gateway-ecommerce
  algashop-ordering
  product-catalog
  service-registry
)

APPS_GRADLE=(
  ecommerce
)

APPS_DOCKER=(
  admin
)

failed=()
succeeded=()

echo "========================================="
echo "Building Docker images for apps (docker)"
echo "========================================="
for app in "${APPS_DOCKER[@]}"; do
  dir="$REPO_ROOT/apps/$app"
  echo "===> Building: $app"
  if (cd "$dir" && docker-compose build); then
    succeeded+=("$app")
    echo "✓ $app"
  else
    failed+=("$app")
    echo "✗ FAILED: $app"
  fi
  echo ""
done


echo "========================================="
echo "Building Docker images for apps (gradle)"
echo "========================================="
for app in "${APPS_GRADLE[@]}"; do
  dir="$REPO_ROOT/apps/$app"
  echo "===> Building: $app"
  if (cd "$dir" && ./gradlew dockerBuild); then
    succeeded+=("$app")
    echo "✓ $app"
  else
    failed+=("$app")
    echo "✗ FAILED: $app"
  fi
  echo ""
done


echo "========================================="
echo "Building Docker images for microservices"
echo "========================================="
for module in "${MICROSERVICES[@]}"; do
  dir="$REPO_ROOT/microservices/$module"
  echo "===> Building: $module"
  if (cd "$dir" && ./gradlew dockerBuild); then
    succeeded+=("$module")
    echo "✓ $module"
  else
    failed+=("$module")
    echo "✗ FAILED: $module"
  fi
  echo ""
done


echo "========================================="
echo "Build Summary"
echo "========================================="
echo "Succeeded (${#succeeded[@]}): ${succeeded[*]:-none}"
echo "Failed    (${#failed[@]}):    ${failed[*]:-none}"

[[ ${#failed[@]} -eq 0 ]]