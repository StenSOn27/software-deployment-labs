# DNS Research - Expected Results and Analysis

## Test Environment

- **DNS Server**: dnsmasq running in Alpine container
- **Network**: Docker bridge network (dns-test-network)
- **Test Domain**: myservice.internal.corp → 10.0.0.50
- **Search Domain**: corp
- **Query**: getent hosts myservice.internal

## Scenario 1: Success in Both

### Expected Output

**Ubuntu (glibc)**:
```
10.0.0.50 myservice.internal
```

**Alpine (musl)**:
```
10.0.0.50 myservice.internal
```

### What Happened

1. Both containers query DNS server
2. Both apply search domain "corp" automatically
3. Both resolve myservice.internal.corp to 10.0.0.50
4. Both return the result successfully

### DNS Server Logs

```
query[A] myservice.internal from 172.18.0.2
query[A] myservice.internal.corp from 172.18.0.2
reply[A] myservice.internal.corp is 10.0.0.50

query[A] myservice.internal from 172.18.0.3
query[A] myservice.internal.corp from 172.18.0.3
reply[A] myservice.internal.corp is 10.0.0.50
```

### Analysis

✅ **Both containers work identically** - This means the DNS configuration is compatible with both glibc and musl.

**Implications**:
- Container image choice (Debian vs Alpine) won't affect DNS resolution
- Applications can safely use search domains
- Can optimize image size with Alpine without DNS concerns

---

## Scenario 2: Failure in Alpine Only

### Expected Output

**Ubuntu (glibc)**:
```
10.0.0.50 myservice.internal
```

**Alpine (musl)**:
```
getent: getaddrinfo: Name or service not known
```

### What Happened

1. Ubuntu successfully applies search domain and resolves
2. Alpine fails to resolve - possible reasons:
   - musl DNS resolver doesn't apply search domain the same way
   - musl resolver times out waiting for response
   - musl has stricter DNS validation

### DNS Server Logs

```
query[A] myservice.internal from 172.18.0.2
query[A] myservice.internal.corp from 172.18.0.2
reply[A] myservice.internal.corp is 10.0.0.50

query[A] myservice.internal from 172.18.0.3
# No follow-up query for myservice.internal.corp
# Or query times out
```

### Analysis

⚠️ **musl DNS resolver behaves differently** - This is a compatibility issue.

**Implications**:
- Cannot use search domains reliably on Alpine
- Applications must use explicit FQDNs
- DNS configuration must be thoroughly tested before using Alpine in production

**Fix Strategy**:
```dockerfile
FROM alpine:latest
RUN apk add libc6-compat  # Add glibc compatibility layer
```

---

## Scenario 3: Both Fail

### Expected Output

**Both Ubuntu and Alpine**:
```
getent: getaddrinfo: Name or service not known
```

### What Happened

1. DNS server unreachable or misconfigured
2. DNS query format incompatible
3. Network isolation issue

### Likely Causes

- DNS server not running
- DNS server port not exposed
- Wrong DNS IP address
- DNS server configuration error

### Verification

```bash
# Check if DNS server is running
docker ps | grep dns-server

# Check DNS server logs
docker logs dns-server

# Test directly from host (if on Linux)
nslookup myservice.internal.corp <dns_ip>
```

---

## Data Collection Template

Use this table to record your test results:

```
Date: ___________
Test Environment: Docker on ___________
Docker Version: ___________

┌─────────────────┬──────────────────────────────────────┬─────────────────┐
│ Container       │ Query Result                         │ Status          │
├─────────────────┼──────────────────────────────────────┼─────────────────┤
│ Ubuntu (glibc)  │ _____________________________         │ ✓ / ✗           │
├─────────────────┼──────────────────────────────────────┼─────────────────┤
│ Alpine (musl)   │ _____________________________         │ ✓ / ✗           │
└─────────────────┴──────────────────────────────────────┴─────────────────┘

DNS Server Log Snippet:
_____________________________________________________________________________

Additional Observations:
_____________________________________________________________________________

Conclusion:
_____________________________________________________________________________
```

## Interpreting Query Logs

### Query Format

```
query[RECORD_TYPE] hostname from CLIENT_IP
reply[RECORD_TYPE] hostname is RESULT
```

### Record Types

- **A**: IPv4 address lookup
- **AAAA**: IPv6 address lookup
- **PTR**: Reverse DNS lookup
- **MX**: Mail exchange records
- **TXT**: Text records

### Example Analysis

**Log Entry**:
```
query[A] myservice.internal from 172.18.0.2
query[A] myservice.internal.corp from 172.18.0.2
reply[A] myservice.internal.corp is 10.0.0.50
```

**Interpretation**:
1. Client (172.18.0.2) first queries for "myservice.internal"
2. DNS server has no direct answer
3. Using search domain, client queries for "myservice.internal.corp"
4. Found! Responds with 10.0.0.50

---

## Troubleshooting

### "Connection refused" error

```bash
# DNS server not running or port not accessible
# Solution:
docker ps  # Check if dns-server container exists
docker logs dns-server  # Check for startup errors
```

### DNS query times out

```bash
# DNS server isn't responding
# Solutions:
docker exec dns-server nslookup myservice.internal 127.0.0.1
docker restart dns-server
```

### Wrong IP address returned

```bash
# DNS server configuration issue
# Check configuration:
docker exec dns-server cat /etc/dnsmasq.conf
# Should contain: address=/myservice.internal.corp/10.0.0.50
```

### getent command not found

```bash
# Testing utility not installed
# In Ubuntu:
apt-get install libc-bin

# In Alpine:
apk add musl
```

---

## Comparative Results

After running all tests, here's what different outcomes mean:

| Ubuntu Result | Alpine Result | Meaning |
|---|---|---|
| ✓ | ✓ | Perfect: DNS compatible with both |
| ✓ | ✗ | Alpine needs glibc compat or explicit FQDNs |
| ✗ | ✗ | DNS configuration problem (both fail) |
| ✗ | ✓ | Unlikely - indicates glibc issue not musl |

---

## Next Steps

After determining DNS compatibility:

### If Both Work (✓ ✓)
- ✅ Can safely use Alpine in production
- ✅ Can use search domains reliably
- ✅ DNS configuration is portable

### If Alpine Fails (✓ ✗)
- ⚠️ **Option 1**: Use explicit FQDNs in code
  ```python
  DB_HOST = "myservice.internal.corp"  # Explicit FQDN
  ```

- ⚠️ **Option 2**: Use glibc compatibility layer
  ```dockerfile
  FROM alpine:latest
  RUN apk add libc6-compat
  ```

- ⚠️ **Option 3**: Use Debian-based image instead
  ```dockerfile
  FROM debian:bookworm-slim
  ```

- ⚠️ **Option 4**: Configure DNS manually
  ```dockerfile
  RUN echo "nameserver 1.1.1.1" > /etc/resolv.conf
  ```

### If Both Fail (✗ ✗)
- 🔴 Check DNS server configuration
- 🔴 Verify network connectivity
- 🔴 Review firewall rules
- 🔴 Test DNS server separately

---

## References

- [DNS RFC 1035](https://tools.ietf.org/html/rfc1035)
- [Docker DNS Documentation](https://docs.docker.com/config/containers/container-networking/#dns-services)
- [musl C Library](https://musl.libc.org/)
- [glibc Manual](https://www.gnu.org/software/libc/manual/)
