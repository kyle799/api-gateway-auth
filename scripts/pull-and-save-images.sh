#!/bin/bash
#
# Pull and save Docker images for offline/dark site deployment
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-$SCRIPT_DIR/../images}"

# Images from docker-compose.yml
IMAGES=(
    "nginx:alpine"
    "kong:3.6"
    "postgres:16-alpine"
    "quay.io/keycloak/keycloak:24.0"
)

echo "=== Docker Image Export for Dark Site ==="
echo "Output directory: $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# Pull all images
echo "--- Pulling images ---"
for image in "${IMAGES[@]}"; do
    echo "Pulling: $image"
    docker pull "$image"
done

echo ""
echo "--- Saving images to tar files ---"

for image in "${IMAGES[@]}"; do
    # Create safe filename from image name
    filename=$(echo "$image" | tr '/:' '_')
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

for image in "${IMAGES[@]}"; do
    filename=$(echo "$image" | tr '/:' '_')
    size=$(du -h "$OUTPUT_DIR/${filename}.tar" | cut -f1)
    echo "  $image ($size)" >> "$OUTPUT_DIR/manifest.txt"
done

# Create load script for dark site
cat > "$OUTPUT_DIR/load-images.sh" << 'EOF'
#!/bin/bash
#
# Load Docker images on dark site
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Loading Docker Images ==="

for tarfile in "$SCRIPT_DIR"/*.tar; do
    if [ -f "$tarfile" ]; then
        echo "Loading: $(basename "$tarfile")"
        docker load -i "$tarfile"
    fi
done

echo ""
echo "=== Loaded Images ==="
docker images | grep -E "nginx|kong|postgres|keycloak"

echo ""
echo "Done. You can now run: docker compose up -d"
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
echo "Transfer the '$OUTPUT_DIR' directory to your dark site,"
echo "then run: ./load-images.sh"
