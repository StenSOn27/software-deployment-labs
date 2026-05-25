# DNS Resolution Research: musl vs glibc

## Overview

This directory contains research on DNS resolution differences between:
- **glibc** (GNU C Library) - used by Debian, Ubuntu, most Linux distributions
- **musl** (lightweight C library) - used by Alpine Linux

These differences are important for containerized applications because DNS resolution behavior can vary significantly between base images.

## Problem

When developing applications in containers, you might encounter situations where:
1. DNS resolution works in Debian-based containers but fails in Alpine
2. Service discovery behaves differently across container environments
3. Applications using DNS search domains fail unpredictably

## Why It Matters

The C library implements DNS resolution differently:
- **glibc**: More features, broader compatibility, complex resolver
- **musl**: Minimal, strict POSIX compliance, simpler resolver

This affects:
- DNS search domain handling
- Negative caching behavior
- Query timeouts and retries
- IPv6 resolution
- Performance characteristics

## Experiments

### Setup

The experiments use Docker containers to test DNS resolution with a custom DNS server.

**Components**:
1. DNS Server (dnsmasq) - running in Alpine container
2. Test Containers (Ubuntu with glibc, Alpine with musl)
3. Custom network for isolation

### Run Tests

**Automated Script**:
```bash
chmod +x run_dns_tests.sh
./run_dns_tests.sh
```

**Manual Steps**:

#### Step 1: Create Network
```bash
docker network create dns-lab
```

#### Step 2: Start DNS Server
```bash
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  dnsmasq -k --log-queries --log-facility=-"
```

This starts a DNS server that:
- Listens for queries on the docker network
- Maps `myservice.internal.corp` → `10.0.0.50`
- Logs all queries for analysis

#### Step 3: Test from Ubuntu (glibc)

In another terminal:
```bash
DNS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)

docker run --rm --network dns-lab \
  --dns=$DNS_IP \
  --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal
```

**Expected Output**:
```
10.0.0.50 myservice.internal
```

**What happens**:
1. Container queries DNS for `myservice.internal`
2. glibc applies search domain `corp`
3. Actually queries for `myservice.internal.corp`
4. DNS server returns `10.0.0.50`
5. Resolution succeeds

#### Step 4: Test from Alpine (musl)

In another terminal:
```bash
DNS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)

docker run --rm --network dns-lab \
  --dns=$DNS_IP \
  --dns-search="corp" \
  alpine:latest getent hosts myservice.internal
```

**Expected Output**:
```
10.0.0.50 myservice.internal
```

OR (depending on musl version):
```
getent: getaddrinfo: Name or service not known
```

## Analysis

### Comparing Behavior

Check DNS server logs in first terminal window to see query differences:

**glibc behavior** (typical):
```
query[A] myservice.internal.corp from 172.18.0.3
query[A] myservice.internal from 172.18.0.3
reply[A] myservice.internal.corp is 10.0.0.50
reply[A] myservice.internal from <address>
```

**musl behavior** (may differ):
```
query[A] myservice.internal from 172.18.0.2
query[A] myservice.internal.corp from 172.18.0.2
```

Or might fail entirely depending on musl resolver implementation.

### Key Differences Observed

| Aspect | glibc | musl |
|--------|-------|------|
| Search domain support | Flexible, applies automatically | May be stricter |
| Query order | May try FQDN first | Different order |
| Negative caching | Aggressive | More conservative |
| Timeout handling | Configurable | Fixed |
| IPv6 support | Full | Standard |
| Resolver options | Many | Basic |

## Common Issues

### Issue 1: Alpine DNS Search Fails

**Problem**: Service discovery works in Debian but fails in Alpine

**Root Cause**: musl's DNS resolver may not apply search domains the same way

**Solution**:
```python
# Instead of relying on search domains
db_host = "myservice.internal"  # Fails in some containers

# Use explicit FQDN or environment variable
db_host = os.getenv("DB_HOST", "myservice.internal.corp")
```

### Issue 2: Timeout Differences

**Problem**: Alpine containers timeout on DNS queries while Debian works

**Root Cause**: Different timeout values in musl vs glibc

**Solution**:
```bash
# Increase DNS timeout in container
docker run --dns-opt timeout:5 --dns-opt attempts:3 ...
```

### Issue 3: Cache Behavior

**Problem**: DNS entries don't update properly in Alpine

**Root Cause**: Different negative caching behavior

**Solution**: Use explicit TTL values or disable caching

## Recommendations

### 1. Use FQDN (Fully Qualified Domain Names)

```python
# Avoid
db_host = "database"

# Prefer
db_host = "database.default.svc.cluster.local"
```

### 2. Avoid DNS Search Domains

Instead of relying on search domains:
```bash
# Don't rely on this
--dns-search="corp"

# Pass explicit hostnames
--env DB_HOST=database.internal.corp
```

### 3. Test in Target Environment

```bash
# Test in actual container that will run in production
docker run --rm -it <your-image> nslookup myservice

# Or from Python
import socket
socket.getaddrinfo("myservice.internal.corp", 80)
```

### 4. Document DNS Dependencies

In your README or deployment guide:
```
## DNS Configuration

This application requires:
- Service discovery at: myservice.internal.corp
- DNS search domain: corp
- TTL: 60 seconds minimum

Note: Tested with glibc (Debian). Alpine support requires additional configuration.
```

## Tools for Debugging

### Inside Container
```bash
# Test resolution
nslookup myservice.internal
getent hosts myservice.internal

# View DNS configuration
cat /etc/resolv.conf

# Check resolver libraries
ldd /bin/sh | grep libc
```

### Docker Commands
```bash
# Inspect DNS settings
docker inspect --format='{{.HostConfig.Dns}}' <container>

# Check network DNS
docker network inspect <network>

# View logs
docker logs dns-server
```

### Network Analysis
```bash
# Tcpdump to see DNS queries
docker run --rm --network dns-lab --cap-add NET_RAW \
  tcpdump -i any "port 53"
```

## Expected Results

### Success Scenario
Both Ubuntu and Alpine:
```
✓ DNS resolution SUCCESSFUL
10.0.0.50 myservice.internal
```

### Partial Failure
Ubuntu succeeds but Alpine fails:
```
Ubuntu (glibc): ✓ SUCCESSFUL
Alpine (musl):  ✗ FAILED
```

This indicates DNS configuration or search domain issues with Alpine.

## References

- **glibc**: https://www.gnu.org/software/libc/
- **musl libc**: https://musl.libc.org/
- **Docker DNS**: https://docs.docker.com/config/containers/container-networking/#dns-services
- **DNS RFC**: https://tools.ietf.org/html/rfc1035

## Cleanup

```bash
# Stop DNS server and remove network
docker network rm dns-lab

# Or if DNS server still running
docker stop dns-server
docker network rm dns-lab
```

---

## Lab Integration

This research demonstrates why careful attention to:
1. Choice of base image (Debian vs Alpine)
2. DNS configuration in containers
3. Service discovery mechanisms

is critical for reliable containerized applications.

**Key Takeaway**: Alpine containers are smaller but require thorough testing of DNS and network behavior before production use.
