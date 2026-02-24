# Security Compliance Guide

This document tracks DISA STIG compliance status and provides guidance for achieving full compliance in DoD/government environments.

## Quick Start for Hardened Deployment

```bash
# Use the hardened compose file
docker compose -f docker-compose.hardened.yml up -d
```

## STIG Compliance Matrix

### Container Platform SRG

| Control | Requirement | Status | Implementation |
|---------|-------------|--------|----------------|
| SRG-APP-000014 | Limit container capabilities | ✅ Done | `cap_drop: ALL` with minimal `cap_add` |
| SRG-APP-000033 | Run as non-root | ✅ Done | `user:` directive on all containers |
| SRG-APP-000038 | Resource limits | ✅ Done | `deploy.resources.limits` configured |
| SRG-APP-000068 | Read-only filesystem | ✅ Done | `read_only: true` with tmpfs for writables |
| SRG-APP-000141 | No privilege escalation | ✅ Done | `no-new-privileges: true` |
| SRG-APP-000148 | Health checks | ✅ Done | Health checks on all services |
| SRG-APP-000225 | Logging | ✅ Done | JSON file logging with rotation |
| SRG-APP-000516 | Trusted images | ⚠️ Manual | Requires image signing verification |

### Web Server SRG (Nginx)

| Control | Requirement | Status | Implementation |
|---------|-------------|--------|----------------|
| SRG-APP-000001 | Session management | ✅ Done | Session timeout configured |
| SRG-APP-000014 | Access restrictions | ✅ Done | Rate limiting, connection limits |
| SRG-APP-000015 | TLS 1.2+ only | ✅ Done | `ssl_protocols TLSv1.2 TLSv1.3` |
| SRG-APP-000033 | Hide version info | ✅ Done | `server_tokens off` |
| SRG-APP-000092 | Approved ciphers | ✅ Done | DoD/NIST approved cipher suite |
| SRG-APP-000118 | Security headers | ✅ Done | HSTS, CSP, X-Frame-Options, etc. |
| SRG-APP-000141 | Warning banner | ✅ Done | DoD consent banner at `/dod-banner` |
| SRG-APP-000225 | Audit logging | ✅ Done | Detailed access logs with timestamps |
| SRG-APP-000266 | Input validation | ✅ Done | Request size limits, timeouts |
| SRG-APP-000315 | FIPS 140-2 | ❌ Manual | Requires FIPS-validated OpenSSL |

### PostgreSQL STIG

| Control | Requirement | Status | Implementation |
|---------|-------------|--------|----------------|
| SRG-APP-000033 | Encrypted passwords | ✅ Done | `scram-sha-256` authentication |
| SRG-APP-000089 | Connection logging | ✅ Done | `log_connections = on` |
| SRG-APP-000090 | Disconnection logging | ✅ Done | `log_disconnections = on` |
| SRG-APP-000091 | DDL logging | ✅ Done | `log_statement = 'ddl'` |
| SRG-APP-000095 | Session timeout | ✅ Done | 15-minute idle timeout |
| SRG-APP-000148 | Log timestamps | ✅ Done | ISO 8601 format in log_line_prefix |
| SRG-APP-000315 | SSL connections | ⚠️ Manual | Config provided, requires certs |
| SRG-APP-000516 | FIPS 140-2 | ❌ Manual | Requires FIPS-validated PostgreSQL |

### Application Security STIG (APISIX/Keycloak)

| Control | Requirement | Status | Implementation |
|---------|-------------|--------|----------------|
| SRG-APP-000001 | Session timeout | ✅ Done | 15-minute session timeout |
| SRG-APP-000015 | TLS 1.2+ | ✅ Done | TLS protocol restrictions |
| SRG-APP-000033 | Password complexity | ⚠️ Manual | Configure in Keycloak admin |
| SRG-APP-000068 | Account lockout | ⚠️ Manual | Configure in Keycloak admin |
| SRG-APP-000141 | Warning banner | ⚠️ Manual | Configure in Keycloak theme |
| SRG-APP-000148 | Audit logging | ✅ Done | Application logging enabled |
| SRG-APP-000516 | FIPS 140-2 | ❌ Manual | Requires FIPS mode configuration |

## Compliance Summary

| Category | Automated | Manual Required |
|----------|-----------|-----------------|
| Container Platform | 7/8 | 1 (image signing) |
| Web Server | 9/10 | 1 (FIPS) |
| PostgreSQL | 6/8 | 2 (SSL certs, FIPS) |
| Application | 4/6 | 2 (Keycloak config) |
| **Total** | **26/32 (81%)** | **6 items** |

## Manual Steps Required

### 1. Generate TLS Certificates

```bash
# For development/testing (self-signed)
cd nginx/certs

# Generate CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt \
    -subj "/C=US/O=Organization/CN=Internal CA"

# Generate server certificate
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr \
    -subj "/C=US/O=Organization/CN=gateway.local"
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt

# Set permissions
chmod 600 server.key
chmod 644 server.crt ca.crt
```

For Keycloak:
```bash
cd keycloak/certs
# Copy or generate similar certs
cp ../../nginx/certs/server.crt tls.crt
cp ../../nginx/certs/server.key tls.key
chmod 600 tls.key
```

### 2. Configure Keycloak Password Policy

After deployment, access Keycloak admin console and configure:

1. **Realm Settings > Security Defenses > Brute Force Detection**
   - Enable brute force detection
   - Max login failures: 3
   - Wait increment: 60 seconds
   - Max wait: 900 seconds (15 min)

2. **Realm Settings > Authentication > Password Policy**
   - Minimum length: 15 characters
   - Uppercase: 1
   - Lowercase: 1
   - Digits: 1
   - Special characters: 1
   - Password history: 24
   - Password expiration: 60 days

3. **Realm Settings > Sessions**
   - SSO Session Idle: 15 minutes
   - SSO Session Max: 8 hours

### 3. Configure Active Directory Federation

1. **Identity Providers > Add provider > LDAP**
   - Connection URL: `ldaps://your-ad-server:636`
   - Users DN: `CN=Users,DC=domain,DC=com`
   - Bind DN: Service account DN
   - Enable "Use Truststore SPI"

2. **Map AD groups to Keycloak roles**

### 4. FIPS 140-2 Compliance

FIPS compliance requires using FIPS-validated cryptographic modules. Options:

#### Option A: Red Hat UBI FIPS Images (Recommended)

The hardened compose file already uses FIPS-capable images:

```yaml
# Already configured in docker-compose.hardened.yml:
nginx:
  image: registry.access.redhat.com/ubi9/nginx-124  # FIPS-capable UBI

# For Keycloak with subscription:
keycloak:
  image: registry.redhat.io/rhbk/keycloak-rhel9:24
  environment:
    KC_FIPS_MODE: strict
```

APISIX and etcd will use the host's FIPS-validated OpenSSL when running on a FIPS-enabled host.

#### Option B: Enable FIPS on Host

```bash
# On RHEL/CentOS host
sudo fips-mode-setup --enable
sudo reboot

# Verify
fips-mode-setup --check
```

### 5. Image Signing and Verification

For production, implement image signing:

```bash
# Sign images with Cosign
cosign sign --key cosign.key registry.local/nginx:alpine

# Verify before deployment
cosign verify --key cosign.pub registry.local/nginx:alpine
```

### 6. Network Segmentation (Kubernetes)

When migrating to Kubernetes, add NetworkPolicies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: apisix-policy
spec:
  podSelector:
    matchLabels:
      app: apisix
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: nginx
      ports:
        - port: 9080
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: etcd
      ports:
        - port: 2379
    - to:
        - podSelector:
            matchLabels:
              app: keycloak
      ports:
        - port: 8443
```

## Audit Checklist

Before deployment, verify:

- [ ] All default passwords changed in `.env`
- [ ] TLS certificates generated and installed
- [ ] Keycloak password policies configured
- [ ] Keycloak brute force protection enabled
- [ ] AD/LDAP federation configured and tested
- [ ] Session timeouts verified (15 min)
- [ ] DoD banner displays on login
- [ ] Audit logs flowing to SIEM
- [ ] Images scanned for vulnerabilities
- [ ] FIPS mode enabled (if required)
- [ ] Host OS hardened per applicable STIG
- [ ] Backup and recovery procedures documented

## Vulnerability Scanning

Before deployment, scan all images:

```bash
# Using Trivy
trivy image registry.access.redhat.com/ubi9/nginx-124
trivy image apache/apisix:3.8.0-debian
trivy image apache/apisix-dashboard:3.0.1-alpine
trivy image bitnami/etcd:3.5
trivy image quay.io/keycloak/keycloak:21.1
trivy image postgres:16-alpine

# Using Grype
grype registry.access.redhat.com/ubi9/nginx-124
grype apache/apisix:3.8.0-debian
```

## Incident Response

Log locations for forensic analysis:

| Component | Log Location | Contents |
|-----------|--------------|----------|
| Nginx | stdout/docker logs | Access logs, errors |
| APISIX | stdout/docker logs | API requests, routing events |
| APISIX Dashboard | stdout/docker logs | Admin actions |
| etcd | stdout/docker logs | Configuration changes |
| Keycloak | stdout/docker logs | Auth events, admin actions |
| PostgreSQL | Container pg_log/ | Connections, queries, errors |

Export logs:
```bash
docker compose -f docker-compose.hardened.yml logs --timestamps > incident_$(date +%Y%m%d).log
```

## References

- [DISA STIG Library](https://public.cyber.mil/stigs/)
- [Container Platform SRG](https://www.stigviewer.com/stig/container_platform/)
- [PostgreSQL STIG](https://www.stigviewer.com/stig/postgresql_9.x/)
- [Web Server SRG](https://www.stigviewer.com/stig/web_server/)
- [NIST SP 800-52 Rev 2 (TLS Guidelines)](https://csrc.nist.gov/publications/detail/sp/800-52/rev-2/final)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
