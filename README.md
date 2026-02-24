# API Gateway Infrastructure

A transparent, auditable API gateway stack built on proven open-source components. Designed as a modern replacement for proprietary gateway appliances.

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

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              Security Boundary               │
                    │                                             │
┌──────────┐       │  ┌─────────┐     ┌─────────┐     ┌────────┐ │
│  Client  │──────────│  Nginx  │────▶│  Kong   │────▶│ Backend│ │
└──────────┘       │  │  (TLS)  │     │  (GW)   │     │Services│ │
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

| Component | Role | Why This Choice |
|-----------|------|-----------------|
| **Nginx** | TLS termination, load balancing | Battle-tested, minimal attack surface, extensive security track record |
| **Kong** | API gateway, routing, rate limiting | Declarative config, plugin architecture, no vendor lock-in |
| **Keycloak** | Authentication, authorization, SSO | Standards-compliant (OIDC/OAuth2/SAML), AD integration, self-hosted |
| **PostgreSQL** | Persistent storage | Industry standard, well-understood security model |

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

### Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| API Gateway | http://localhost:80 | Client-facing endpoint |
| Kong Admin | http://localhost:8001 | Gateway configuration API |
| Kong Manager | http://localhost:8002 | Gateway admin UI |
| Keycloak | http://localhost:8080 | Identity management console |

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
# Load images locally
./load-images.sh

# Or load and push to private registry
./load-images.sh registry.internal:5000
```

If pushing to a private registry, update `docker-compose.yml` image references:

```yaml
image: registry.internal:5000/library/nginx:alpine
image: registry.internal:5000/library/kong:3.6
image: registry.internal:5000/library/postgres:16-alpine
image: registry.internal:5000/keycloak/keycloak:24.0
```

## Configuration

### Kong Routes and Services

Define API routes in `kong/kong.yml` using declarative configuration:

```yaml
services:
  - name: my-api
    url: http://backend-service:8080
    routes:
      - name: my-api-route
        paths:
          - /api/v1
```

Apply configuration:
```bash
# Using Admin API
curl -X POST http://localhost:8001/config -F config=@kong/kong.yml
```

### Keycloak Realms

1. Access Keycloak at http://localhost:8080
2. Login with admin credentials from `.env`
3. Create realm and configure AD federation
4. Export realm config for version control:
   ```bash
   # Export from running instance for backup
   docker exec keycloak /opt/keycloak/bin/kc.sh export --dir /tmp/export
   ```

### TLS Configuration

Place certificates in `nginx/certs/` and uncomment the HTTPS server block in `nginx/nginx.conf`.

## Security Hardening Checklist

- [ ] Change all default passwords in `.env`
- [ ] Enable TLS termination at Nginx
- [ ] Configure Keycloak password policies
- [ ] Set up AD/LDAP federation in Keycloak
- [ ] Enable Kong rate limiting plugins
- [ ] Configure network policies (when on Kubernetes)
- [ ] Enable audit logging on all components
- [ ] Regularly update container images
- [ ] Scan images for vulnerabilities before deployment

## Project Structure

```
├── docker-compose.yml          # Service definitions
├── .env.example                # Environment template
├── nginx/
│   ├── nginx.conf              # Load balancer configuration
│   └── certs/                  # TLS certificates
├── kong/
│   ├── kong.yml                # Declarative route config
│   └── plugins/                # Custom plugins
├── keycloak/
│   └── themes/                 # Custom UI themes
├── scripts/
│   └── pull-and-save-images.sh # Offline deployment tool
└── k8s/                        # Kubernetes manifests (future)
```

## Troubleshooting

```bash
# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f kong

# Restart a service
docker compose restart keycloak

# Check Kong configuration
curl http://localhost:8001/status

# Test Keycloak health
curl http://localhost:8080/health
```

## License

This project configuration is provided as-is. Individual components retain their respective licenses:
- Nginx: BSD-2-Clause
- Kong: Apache 2.0
- Keycloak: Apache 2.0
- PostgreSQL: PostgreSQL License
