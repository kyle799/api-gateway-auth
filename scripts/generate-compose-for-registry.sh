#!/bin/bash
#
# Generate docker-compose files with private registry image references
#
# Usage:
#   ./generate-compose-for-registry.sh registry.internal:5000
#   ./generate-compose-for-registry.sh darksite.local/project
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

REGISTRY="${1:-}"

if [ -z "$REGISTRY" ]; then
    echo "Usage: $0 <registry-url>"
    echo ""
    echo "Examples:"
    echo "  $0 registry.internal:5000"
    echo "  $0 darksite.local/myproject"
    echo ""
    exit 1
fi

# Remove trailing slash if present
REGISTRY="${REGISTRY%/}"

echo "=== Generating Compose Files for Registry: $REGISTRY ==="
echo ""

# Image mappings (source -> registry path)
declare -A IMAGES=(
    ["registry.access.redhat.com/ubi9/nginx-124"]="ubi9/nginx-124"
    ["apache/apisix:3.8.0-debian"]="apache/apisix:3.8.0-debian"
    ["apache/apisix-dashboard:3.0.1-alpine"]="apache/apisix-dashboard:3.0.1-alpine"
    ["quay.io/coreos/etcd:v3.5.17"]="coreos/etcd:v3.5.17"
    ["quay.io/keycloak/keycloak:19.0"]="keycloak/keycloak:24.0"
    ["postgres:16-alpine"]="library/postgres:16-alpine"
)

# Function to replace images in a compose file
generate_compose() {
    local source_file="$1"
    local output_file="$2"
    local temp_file=$(mktemp)

    cp "$source_file" "$temp_file"

    for source in "${!IMAGES[@]}"; do
        target="${REGISTRY}/${IMAGES[$source]}"
        # Escape special characters for sed
        source_escaped=$(printf '%s\n' "$source" | sed 's/[[\.*^$()+?{|]/\\&/g')
        target_escaped=$(printf '%s\n' "$target" | sed 's/[&/\]/\\&/g')
        sed -i "s|image: ${source_escaped}|image: ${target_escaped}|g" "$temp_file"
    done

    mv "$temp_file" "$output_file"
    echo "Created: $output_file"
}

# Generate both compose files
generate_compose "$PROJECT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.registry.yml"
generate_compose "$PROJECT_DIR/docker-compose.hardened.yml" "$PROJECT_DIR/docker-compose.hardened.registry.yml"

echo ""
echo "=== Generation Complete ==="
echo ""
echo "Files created:"
echo "  - docker-compose.registry.yml          (standard)"
echo "  - docker-compose.hardened.registry.yml (STIG-hardened)"
echo ""
echo "Image references updated to:"
for source in "${!IMAGES[@]}"; do
    echo "  $source -> ${REGISTRY}/${IMAGES[$source]}"
done
echo ""
echo "Usage:"
echo "  docker compose -f docker-compose.registry.yml up -d"
echo "  docker compose -f docker-compose.hardened.registry.yml up -d"
