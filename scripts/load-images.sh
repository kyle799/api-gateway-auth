#!/bin/bash
#
# Load Docker images on dark site and optionally push to registry
#
# Usage:
#   ./load-images.sh                    # Just load images locally
#   ./load-images.sh registry.local     # Load and push to registry
#   ./load-images.sh registry.local:5000/myproject  # With port and path
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGES_DIR="${SCRIPT_DIR}/../images"
REGISTRY="${1:-}"

# Check if images directory exists
if [ ! -d "$IMAGES_DIR" ]; then
    echo "Error: Images directory not found at $IMAGES_DIR"
    echo "Run ./scripts/pull-and-save-images.sh first to download images."
    exit 1
fi

echo "=== Loading Docker Images ==="
echo "Images directory: $IMAGES_DIR"
echo ""

for tarfile in "$IMAGES_DIR"/*.tar; do
    if [ -f "$tarfile" ]; then
        echo "Loading: $(basename "$tarfile")"
        docker load -i "$tarfile"
    fi
done

echo ""
echo "=== Loaded Images ==="
docker images | grep -E "nginx|apisix|etcd|postgres|keycloak" | head -20

# Image mappings (source -> target path in registry)
declare -A IMAGE_MAP=(
    ["registry.access.redhat.com/ubi9/nginx-124"]="ubi9/nginx-124"
    ["apache/apisix:3.8.0-debian"]="apache/apisix:3.8.0-debian"
    ["apache/apisix-dashboard:3.0.1-alpine"]="apache/apisix-dashboard:3.0.1-alpine"
    ["quay.io/coreos/etcd:v3.5.17"]="coreos/etcd:v3.5.17"
    ["quay.io/keycloak/keycloak:21.1"]="keycloak/keycloak:24.0"
    ["postgres:16-alpine"]="library/postgres:16-alpine"
)

# If registry specified, retag and push
if [ -n "$REGISTRY" ]; then
    echo ""
    echo "=== Pushing to Registry: $REGISTRY ==="

    for source in "${!IMAGE_MAP[@]}"; do
        target="${IMAGE_MAP[$source]}"
        new_tag="${REGISTRY}/${target}"

        echo ""
        echo "Tagging: $source -> $new_tag"
        docker tag "$source" "$new_tag"

        echo "Pushing: $new_tag"
        docker push "$new_tag"
    done

    echo ""
    echo "=== Push Complete ==="
    echo ""
    echo "Update your docker-compose.yml image references to use:"
    echo "  ${REGISTRY}/ubi9/nginx-124"
    echo "  ${REGISTRY}/apache/apisix:3.8.0-debian"
    echo "  ${REGISTRY}/apache/apisix-dashboard:3.0.1-alpine"
    echo "  ${REGISTRY}/coreos/etcd:v3.5.17"
    echo "  ${REGISTRY}/keycloak/keycloak:24.0"
    echo "  ${REGISTRY}/library/postgres:16-alpine"
    echo ""
    echo "Or run: ./scripts/generate-compose-for-registry.sh ${REGISTRY}"
else
    echo ""
    echo "Done. You can now run: docker compose up -d"
    echo ""
    echo "To push to a private registry, run:"
    echo "  ./scripts/load-images.sh <registry-url>"
    echo ""
    echo "Example:"
    echo "  ./scripts/load-images.sh darksite.local:5000"
fi
