#!/usr/bin/env bash
# Build a single-architecture Docker image for Campsite locally.
# The script auto-detects host CPU (arm64 vs amd64) and builds the matching
# architecture image. Multi-arch manifest is created later in CI.
#
# Usage:
#   ./script/demo/build-images-arm64-local.sh [IMAGE_TAG] [--push]
#     --push  Also push to remote registries; if omitted, image is only built and loaded locally.
#
# Registries (both tagged when --push):
#   - public.ecr.aws/m8q5m4u3/mega/campsite-api
#   - registry.xuanwu.openatom.cn/mega/campsite-api
#
# Requirements:
#   - Docker with buildx enabled ("docker buildx create --use")
#   - If using --push you must already be logged into the destination registries.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$API_DIR"

REGISTRY_ALIAS="m8q5m4u3"               # Public ECR alias
ECR_REGISTRY="public.ecr.aws/${REGISTRY_ALIAS}"
HARBOR_REGISTRY="${HARBOR_REGISTRY:-registry.xuanwu.openatom.cn}"
REPOSITORY="mega/campsite-api"

# ----------------------------------------
# Parse CLI arguments
# ----------------------------------------
DO_PUSH=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --push)
      DO_PUSH=true
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

# Image tag via first positional arg, or env, or default
IMAGE_TAG_BASE="${IMAGE_TAG:-${1:-latest}}"

# Detect host architecture and map to Docker platform / suffix
ARCH_NATIVE="$(uname -m)"
case "$ARCH_NATIVE" in
  arm64|aarch64)
    PLATFORM="linux/arm64"
    ARCH_SUFFIX="arm64"
    ;;
  x86_64|amd64)
    PLATFORM="linux/amd64"
    ARCH_SUFFIX="amd64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH_NATIVE" >&2
    exit 1
    ;;
esac

# Build-time args (override via env vars if needed)
RUBY_VERSION="${RUBY_VERSION:-3.3.4}"
NODE_VERSION="${NODE_VERSION:-18.16.1}"
BUNDLER_VERSION="${BUNDLER_VERSION:-2.3.14}"

IMAGE_TAG="${IMAGE_TAG_BASE}-${ARCH_SUFFIX}"
ECR_IMAGE="${ECR_REGISTRY}/${REPOSITORY}:${IMAGE_TAG}"
ECR_LATEST_ARCH="${ECR_REGISTRY}/${REPOSITORY}:latest-${ARCH_SUFFIX}"
HARBOR_IMAGE="${HARBOR_REGISTRY}/${REPOSITORY}:${IMAGE_TAG}"
HARBOR_LATEST_ARCH="${HARBOR_REGISTRY}/${REPOSITORY}:latest-${ARCH_SUFFIX}"
CACHE_IMAGE="${ECR_REGISTRY}/${REPOSITORY}:buildcache-${ARCH_SUFFIX}"
CACHE_DIR="${BUILDX_CACHE_DIR:-${HOME}/.cache/campsite-api-buildx/${ARCH_SUFFIX}}"

echo "Building (${PLATFORM}) …"
echo "  ECR:    $ECR_IMAGE"
echo "  Harbor: $HARBOR_IMAGE"

# Ensure buildx is available
if ! docker buildx version >/dev/null 2>&1; then
  echo "docker buildx not available; please install Docker 19.03+ and enable buildx." >&2
  exit 1
fi

# Build image with persistent layer cache across repeated builds.
BUILD_ARGS=(
  --platform "$PLATFORM"
  --provenance=false
  --sbom=false
  -t "$ECR_IMAGE"
  -t "$ECR_LATEST_ARCH"
  -t "$HARBOR_IMAGE"
  -t "$HARBOR_LATEST_ARCH"
  --build-arg "RUBY_VERSION=$RUBY_VERSION"
  --build-arg "NODE_VERSION=$NODE_VERSION"
  --build-arg "BUNDLER_VERSION=$BUNDLER_VERSION"
  --cache-from "type=registry,ref=${CACHE_IMAGE}"
  --cache-from "type=registry,ref=${ECR_IMAGE}"
)

if $DO_PUSH; then
  BUILD_ARGS+=(--cache-to "type=registry,ref=${CACHE_IMAGE},mode=max" --push)
else
  mkdir -p "$CACHE_DIR"
  BUILD_ARGS+=(--cache-from "type=local,src=${CACHE_DIR}")
  BUILD_ARGS+=(--cache-to "type=local,dest=${CACHE_DIR},mode=max" --load)
fi

if ! docker buildx build "${BUILD_ARGS[@]}" .; then
  echo "docker buildx build failed" >&2
  exit 1
fi

echo "Image built successfully: $ECR_IMAGE / $HARBOR_IMAGE"

if $DO_PUSH; then
  echo "Image pushed successfully:"
  echo "  $ECR_IMAGE"
  echo "  $ECR_LATEST_ARCH"
  echo "  $HARBOR_IMAGE"
  echo "  $HARBOR_LATEST_ARCH"
  echo "Build cache saved to: ${CACHE_IMAGE}"
else
  echo "Image loaded locally: $ECR_IMAGE"
  echo "Build cache saved to: ${CACHE_DIR}"
fi
