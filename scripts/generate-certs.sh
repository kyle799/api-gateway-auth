#!/bin/bash
#
# Generate self-signed TLS certificates for development/testing
# For production, use certificates from your PKI or a trusted CA
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

NGINX_CERTS="$PROJECT_DIR/nginx/certs"
KEYCLOAK_CERTS="$PROJECT_DIR/keycloak/certs"

# Certificate settings
DAYS=365
KEY_SIZE=4096
COUNTRY="US"
ORG="Organization"
CN="${1:-gateway.local}"

echo "=== Generating TLS Certificates ==="
echo "Common Name: $CN"
echo "Valid for: $DAYS days"
echo ""

# Create directories
mkdir -p "$NGINX_CERTS" "$KEYCLOAK_CERTS"

cd "$NGINX_CERTS"

# Generate CA
echo "--- Generating CA ---"
openssl genrsa -out ca.key $KEY_SIZE 2>/dev/null
openssl req -new -x509 -days $DAYS -key ca.key -out ca.crt \
    -subj "/C=$COUNTRY/O=$ORG/CN=Internal CA" 2>/dev/null
echo "Created: ca.key, ca.crt"

# Generate server certificate with SAN
echo "--- Generating Server Certificate ---"
cat > openssl.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
O = $ORG
CN = $CN

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CN
DNS.2 = localhost
DNS.3 = kong
DNS.4 = keycloak
DNS.5 = nginx
IP.1 = 127.0.0.1
EOF

openssl genrsa -out server.key $KEY_SIZE 2>/dev/null
openssl req -new -key server.key -out server.csr -config openssl.cnf 2>/dev/null
openssl x509 -req -days $DAYS -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt -extensions v3_req -extfile openssl.cnf 2>/dev/null
rm -f openssl.cnf server.csr ca.srl

echo "Created: server.key, server.crt"

# Set permissions
chmod 600 server.key ca.key
chmod 644 server.crt ca.crt

# Copy to Keycloak
echo ""
echo "--- Copying to Keycloak ---"
cp server.crt "$KEYCLOAK_CERTS/tls.crt"
cp server.key "$KEYCLOAK_CERTS/tls.key"
cp ca.crt "$KEYCLOAK_CERTS/ca.crt"
chmod 600 "$KEYCLOAK_CERTS/tls.key"
echo "Created: keycloak/certs/tls.key, tls.crt, ca.crt"

echo ""
echo "=== Certificate Generation Complete ==="
echo ""
echo "Nginx certificates: $NGINX_CERTS"
ls -la "$NGINX_CERTS"/*.{crt,key} 2>/dev/null || true

echo ""
echo "Keycloak certificates: $KEYCLOAK_CERTS"
ls -la "$KEYCLOAK_CERTS"/*.{crt,key} 2>/dev/null || true

echo ""
echo "Certificate details:"
openssl x509 -in "$NGINX_CERTS/server.crt" -noout -subject -dates -ext subjectAltName 2>/dev/null

echo ""
echo "NOTE: These are self-signed certificates for development only."
echo "For production, use certificates from your organization's PKI."
