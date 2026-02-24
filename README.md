# API Gateway Infrastructure

A transparent, auditable API gateway stack built on proven open-source components. Designed as a modern replacement for proprietary gateway appliances with FIPS 140-2 compliance capability.

## Why Open Source for Security Infrastructure?

Security infrastructure should be **transparent and auditable**. When your organization's API traffic flows through a gateway, you need to know exactly what's happening to that traffic.

### The Case for Self-Managed Open Source

| Concern | Proprietary Appliance | Open Source Stack |
|---------|----------------------|-------------------|
| **Code Visibility** | Closed binary, trust the vendor | Full source code available for audit |
| **Vulnerability Response** | Wait for vendor patches | Patch immediately or mitigate directly |
| **Configuration** | Vendor-defined options only | Complete control over every parameter |
| **Audit Trail** | Limited to vendor's logging | Full visibility into all components |
| **Data Handling** | Unknown internal processing | Verifiable data flow paths |
| **Supply Chain** | Opaque dependencies | Transparent, scannable dependencies |

### Security Benefits

- **No Black Boxes**: Every component's behavior can be verified by reading source code
- **Reproducible Builds**: Container images can be rebuilt from source and verified
- **Air-Gap Ready**: Full offline deployment capability for sensitive environments
- **Principle of Least Privilege**: Configure exactly what's needed, nothing more
- **Community Review**: Thousands of security researchers examine these codebases
- **No Phone Home**: No telemetry, license checks, or external dependencies required
- **FIPS Capable**: Uses FIPS-validated base images (Red Hat UBI)

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │             Security Boundary               │
                    │                                             │
┌──────────┐        │  ┌─────────┐     ┌─────────┐     ┌────────┐ │
│  Client  │───────────│  Nginx  │────▶│ APISIX  │────▶│ Backend│ │
└──────────┘        │  │  (TLS)  │     │  (GW)   │     │Services│ │
                    │  └─────────┘     └────┬────┘     └────────┘ │
                    │                       │                     │
                    │                 ┌─────▼─────┐               │
                    │                 │ Keycloak  │               │
                    │                 │  (AuthN)  │               │
                    │                 └─────┬─────┘               │
                    │                       │                     │
                    │                 ┌─────▼─────┐               │
                    │                 │  Active   │               │
                    │                 │ Directory │               │
                    │                 └───────────┘               │
                    └─────────────────────────────────────────────┘
```

## Components

| Component | Role | Image | FIPS Status |
|-----------|------|-------|-------------|
| **Nginx** | TLS termination, load balancing | Red Hat UBI9 | FIPS-capable |
| **APISIX** | API gateway, routing, rate limiting, plugins | Apache APISIX | Host FIPS mode |
| **etcd** | Configuration store for APISIX | Bitnami etcd | Host FIPS mode |
| **Keycloak** | Authentication, authorization, SSO, AD integration | Keycloak | FIPS mode available |
| **PostgreSQL** | Persistent storage for Keycloak | PostgreSQL Alpine | Host FIPS mode |

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Network access to pull images (or use offline method below)

### Development Setup

```bash
# Configure environment
cp .env.example .env
# Edit .env with secure passwords

# Start all services
docker compose up -d

# Verify services are running
docker compose ps
```

### Hardened Deployment (STIG-compliant)

```bash
# Generate TLS certificates
./scripts/generate-certs.sh gateway.yourdomain.com

# Configure environment
cp .env.example .env
vi .env  # Set secure passwords

# Deploy hardened stack
docker compose -f docker-compose.hardened.yml up -d
```

### Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| API Gateway | http://localhost:80 | Client-facing endpoint (Nginx) |
| APISIX Proxy | http://localhost:9080 | Direct gateway access |
| APISIX Admin | http://localhost:9180 | Gateway configuration API |
| APISIX Dashboard | http://localhost:9000 | Gateway admin UI |
| Keycloak | http://localhost:8080 | Identity management console |
| Prometheus Metrics | http://localhost:9091 | APISIX metrics |

## Air-Gapped Deployment

For environments without internet access:

### On Connected Machine

```bash
# Pull and package all images
./scripts/pull-and-save-images.sh

# Transfer the 'images/' directory to air-gapped environment
```

### On Air-Gapped Machine

```bash
cd images/

# Load images locally
./load-images.sh

# Or load and push to private registry
./load-images.sh registry.internal:5000
```

### Generate Registry-Specific Compose Files

```bash
# Auto-generate compose files with your registry prefix
./scripts/generate-compose-for-registry.sh registry.internal:5000

# Deploy
docker compose -f docker-compose.hardened.registry.yml up -d
```

## Configuration

### APISIX Routes and Services

Define API routes in `apisix/apisix.yaml` or via the Admin API:

```yaml
routes:
  - uri: /api/v1/*
    name: backend-api
    upstream:
      type: roundrobin
      nodes:
        "backend-service:8080": 1
    plugins:
      key-auth:
        header: "X-API-Key"
      limit-count:
        count: 100
        time_window: 60
```

Apply via Admin API:
```bash
curl -X PUT http://localhost:9180/apisix/admin/routes/1 \
  -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
  -d '{"uri": "/api/*", "upstream": {"nodes": {"backend:8080": 1}}}'
```

### APISIX + Keycloak Integration

APISIX has built-in Keycloak integration via the `authz-keycloak` plugin:

```yaml
plugins:
  authz-keycloak:
    token_endpoint: "https://keycloak:8443/realms/master/protocol/openid-connect/token"
    client_id: "apisix"
    client_secret: "your-client-secret"
```

### Keycloak Realms

1. Access Keycloak at http://localhost:8080 (or https://localhost:8443 in hardened mode)
2. Login with admin credentials from `.env`
3. Create realm and configure AD federation
4. Export realm config for version control:
   ```bash
   docker exec keycloak /opt/keycloak/bin/kc.sh export --dir /tmp/export
   ```

### TLS Configuration

```bash
# Generate certificates
./scripts/generate-certs.sh gateway.yourdomain.com

# Deploy with hardened config (TLS enabled by default)
docker compose -f docker-compose.hardened.yml up -d
```

## Security Hardening Checklist

- [ ] Change all default passwords in `.env`
- [ ] Generate and install TLS certificates
- [ ] Configure Keycloak password policies (15+ chars, complexity)
- [ ] Enable Keycloak brute force protection
- [ ] Set up AD/LDAP federation in Keycloak
- [ ] Configure APISIX rate limiting plugins
- [ ] Configure network policies (when on Kubernetes)
- [ ] Enable audit logging on all components
- [ ] Scan images for vulnerabilities before deployment
- [ ] Enable FIPS mode on host (for full compliance)

## Project Structure

```
├── docker-compose.yml              # Standard deployment
├── docker-compose.hardened.yml     # STIG-hardened deployment
├── .env.example                    # Environment template
├── nginx/
│   ├── nginx.conf                  # Standard config
│   ├── nginx.hardened.conf         # Hardened config
│   ├── dod-banner.html             # DoD consent banner
│   └── certs/                      # TLS certificates
├── apisix/
│   ├── config.yaml                 # APISIX configuration
│   ├── apisix.yaml                 # Route definitions
│   └── dashboard.yaml              # Dashboard config
├── keycloak/
│   ├── certs/                      # Keycloak TLS certs
│   └── themes/                     # Custom UI themes
├── postgres/
│   ├── postgresql.conf             # Hardened PostgreSQL
│   └── pg_hba.conf                 # Auth configuration
├── scripts/
│   ├── pull-and-save-images.sh     # Image export for dark site
│   ├── generate-certs.sh           # TLS certificate generator
│   └── generate-compose-for-registry.sh  # Registry compose generator
├── SECURITY.md                     # STIG compliance guide
└── k8s/                            # Kubernetes manifests (future)
```

## Troubleshooting

```bash
# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f apisix

# Restart a service
docker compose restart keycloak

# Check APISIX status
curl http://localhost:9080/apisix/status

# Check APISIX routes
curl http://localhost:9180/apisix/admin/routes -H "X-API-KEY: admin"

# Test Keycloak health
curl http://localhost:8080/health

# Check etcd health
docker exec etcd etcdctl endpoint health
```

## FIPS 140-2 Compliance

For full FIPS compliance, see [SECURITY.md](SECURITY.md). Options:

1. **Host-level FIPS**: Run on FIPS-enabled RHEL host
2. **Red Hat subscription images**: Use `registry.redhat.io` FIPS images
3. **Keycloak FIPS mode**: Set `KC_FIPS_MODE=strict`

## License

This project configuration is provided as-is. Individual components retain their respective licenses:
- Nginx: BSD-2-Clause
- APISIX: Apache 2.0
- etcd: Apache 2.0
- Keycloak: Apache 2.0
- PostgreSQL: PostgreSQL License
