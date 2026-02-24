#!/bin/bash
#
# Pull and save Docker images for offline/dark site deployment
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/../images}"

# Images from docker-compose.yml
# Format: "source_image|target_path"
# target_path is the normalized path in the dark site registry
IMAGES=(
    "registry.access.redhat.com/ubi9/nginx-124|ubi9/nginx-124"
    "apache/apisix:3.8.0-debian|apache/apisix:3.8.0-debian"
    "apache/apisix-dashboard:3.0.1-alpine|apache/apisix-dashboard:3.0.1-alpine"
    "quay.io/coreos/etcd:v3.5.17|coreos/etcd:v3.5.17"
    "quay.io/keycloak/keycloak:24.0|keycloak/keycloak:24.0"
    "postgres:16-alpine|library/postgres:16-alpine"
)

echo "=== Docker Image Export for Dark Site ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# Pull all images
echo "--- Pulling images ---"
for entry in "${IMAGES[@]}"; do
    image="${entry%%|*}"
    echo "Pulling: $image"
    docker pull "$image"
done

echo ""
echo "--- Saving images to tar files ---"

for entry in "${IMAGES[@]}"; do
    image="${entry%%|*}"
    target="${entry##*|}"

    # Create safe filename from target path
    filename=$(echo "$target" | tr '/:' '_')
    tarfile="$OUTPUT_DIR/${filename}.tar"

    echo "Saving: $image -> $tarfile"
    docker save -o "$tarfile" "$image"
done

# Create a manifest file
echo ""
echo "--- Creating manifest ---"
cat > "$OUTPUT_DIR/manifest.txt" << EOF
Docker Images Export
Generated: $(date -Iseconds)
Host: $(hostname)

Images included:
EOF

for entry in "${IMAGES[@]}"; do
    image="${entry%%|*}"
    target="${entry##*|}"
    filename=$(echo "$target" | tr '/:' '_')
    size=$(du -h "$OUTPUT_DIR/${filename}.tar" | cut -f1)
    echo "  $image -> $target ($size)" >> "$OUTPUT_DIR/manifest.txt"
done

# Create image mapping file for load script
cat > "$OUTPUT_DIR/image-map.txt" << 'MAPEOF'
registry.access.redhat.com/ubi9/nginx-124|ubi9/nginx-124
apache/apisix:3.8.0-debian|apache/apisix:3.8.0-debian
apache/apisix-dashboard:3.0.1-alpine|apache/apisix-dashboard:3.0.1-alpine
quay.io/coreos/etcd:v3.5.17|coreos/etcd:v3.5.17
quay.io/keycloak/keycloak:24.0|keycloak/keycloak:24.0
postgres:16-alpine|library/postgres:16-alpine
MAPEOF

# Create load script for dark site
cat > "$OUTPUT_DIR/load-images.sh" << 'EOF'
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
REGISTRY="${1:-}"

echo "=== Loading Docker Images ==="

for tarfile in "$SCRIPT_DIR"/*.tar; do
    if [ -f "$tarfile" ]; then
        echo "Loading: $(basename "$tarfile")"
        docker load -i "$tarfile"
    fi
done

echo ""
echo "=== Loaded Images ==="
docker images | grep -E "nginx|apisix|etcd|postgres|keycloak" | head -20

# If registry specified, retag and push
if [ -n "$REGISTRY" ]; then
    echo ""
    echo "=== Pushing to Registry: $REGISTRY ==="

    # Read image mappings
    while IFS='|' read -r source target; do
        [ -z "$source" ] && continue

        new_tag="${REGISTRY}/${target}"
        echo ""
        echo "Tagging: $source -> $new_tag"
        docker tag "$source" "$new_tag"

        echo "Pushing: $new_tag"
        docker push "$new_tag"
    done < "$SCRIPT_DIR/image-map.txt"

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
else
    echo ""
    echo "Done. You can now run: docker compose up -d"
    echo ""
    echo "To push to a private registry, run:"
    echo "  ./load-images.sh <registry-url>"
    echo ""
    echo "Example:"
    echo "  ./load-images.sh darksite.local:5000"
fi
EOF

chmod +x "$OUTPUT_DIR/load-images.sh"

echo ""
echo "=== Export Complete ==="
echo ""
echo "Files created in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
echo ""
echo "Transfer the '$OUTPUT_DIR' directory to your dark site, then:"
echo ""
echo "  # Load images locally only:"
echo "  ./load-images.sh"
echo ""
echo "  # Load and push to private registry:"
echo "  ./load-images.sh darksite.local:5000"
