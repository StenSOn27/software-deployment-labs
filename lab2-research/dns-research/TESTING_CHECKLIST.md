# DNS Research - Testing Checklist

## Pre-Test Preparation

- [ ] Docker is installed: `docker --version`
- [ ] Docker daemon is running: `docker ps`
- [ ] Have 3+ terminals available
- [ ] At least 500 MB free disk space
- [ ] Network connectivity available

## Quick Test (5 minutes)

### Setup Phase
- [ ] Run: `docker network create dns-lab`
- [ ] Run: `./run_dns_tests.sh`
- [ ] Wait for script to complete

### Expected
- [ ] Both Ubuntu and Alpine show "SUCCESSFUL" or both show "FAILED"
- [ ] DNS logs are displayed
- [ ] Script completes without errors

## Manual Test (15 minutes)

### Terminal 1: DNS Server
- [ ] Run: `chmod +x run_dns_tests.sh && ./run_dns_tests.sh`
- [ ] Watch for "query" and "reply" lines
- [ ] Note the DNS query patterns

### Terminal 2: Ubuntu Container
- [ ] Get DNS IP from Terminal 1
- [ ] Run Ubuntu test command
- [ ] Record result (✓ or ✗)
- [ ] Run: `getent hosts myservice.internal`
- [ ] Run: `cat /etc/resolv.conf`

### Terminal 3: Alpine Container
- [ ] Get DNS IP from Terminal 1
- [ ] Run Alpine test command
- [ ] Record result (✓ or ✗)
- [ ] Run: `getent hosts myservice.internal`
- [ ] Run: `cat /etc/resolv.conf`

## Docker Compose Test (10 minutes)

- [ ] Run: `docker-compose up -d`
- [ ] Run: `docker-compose ps`
- [ ] All containers are "Up"

### Test Ubuntu Container
```bash
- [ ] docker-compose exec ubuntu-tester bash
- [ ] getent hosts myservice.internal
- [ ] Record result
- [ ] exit
```

### Test Alpine Container
```bash
- [ ] docker-compose exec alpine-tester sh
- [ ] getent hosts myservice.internal
- [ ] Record result
- [ ] exit
```

- [ ] Run: `docker-compose down`
- [ ] Run: `docker network rm dns-test-network` (if persists)

## Advanced Debugging

### DNS Server Diagnostics
- [ ] `docker logs dns-server 2>&1 | tail -20`
- [ ] Search for "error" or "warning" messages
- [ ] Verify dnsmasq configuration loaded

### Network Diagnostics
```bash
- [ ] docker network inspect dns-lab
- [ ] Verify both test containers are in network
- [ ] Check gateway and subnet
```

### Container DNS Settings
```bash
- [ ] docker inspect ubuntu-test-container | grep -A 5 Dns
- [ ] docker inspect alpine-test-container | grep -A 5 Dns
- [ ] Verify DNS server IP is correct
```

### Test Individual Libraries
```bash
- [ ] docker run alpine ldd /bin/sh | grep libc
- [ ] docker run ubuntu ldd /bin/bash | grep libc
```

## Data Collection

### Results Summary
```
Test Date: ___________
Tester Name: ___________

Ubuntu (glibc):     [ ] ✓ Success  [ ] ✗ Failed
Alpine (musl):      [ ] ✓ Success  [ ] ✗ Failed

Details:
- Ubuntu output: _________________________________________
- Alpine output: _________________________________________
- DNS server IP: _________________________________________
- Notable log entries: ____________________________________
```

### Metrics
- [ ] Measure DNS query time (Ubuntu):
  ```bash
  time getent hosts myservice.internal
  ```
  Result: _____ ms

- [ ] Measure DNS query time (Alpine):
  ```bash
  time getent hosts myservice.internal
  ```
  Result: _____ ms

### Observations
- [ ] Search domain applied correctly?
  - Ubuntu: [ ] Yes [ ] No [ ] Unclear
  - Alpine: [ ] Yes [ ] No [ ] Unclear

- [ ] Both resolvers use same query pattern?
  - [ ] Yes [ ] No [ ] Different

- [ ] Any timeouts or delays?
  - [ ] Yes [ ] No
  - If yes, describe: ___________________________________

## Post-Test Cleanup

- [ ] `docker network rm dns-lab` 
- [ ] `docker stop dns-server` (if still running)
- [ ] `docker-compose down` (if using compose)
- [ ] Verify all containers stopped: `docker ps | grep dns`
- [ ] Should be empty

## Reporting

- [ ] Tested on OS: ___________________
- [ ] Docker version: _________________
- [ ] Docker Compose version: _________
- [ ] Host machine specs (CPU/RAM): _______________
- [ ] Network: [ ] Connected [ ] Disconnected [ ] Limited
- [ ] Results documented: [ ] Yes [ ] No
- [ ] Screenshots/logs saved: [ ] Yes [ ] No

## Sign-off

- [ ] Tests completed
- [ ] Results verified
- [ ] Conclusions drawn
- [ ] Report written

**Test Completed**: _____________ (Date)
**Tester**: _____________ (Name)
**Result**: [ ] SUCCESS [ ] INCONCLUSIVE [ ] FAILED

---

## Quick Reference Commands

### Start DNS Server
```bash
docker network create dns-lab
docker run --rm -d --name dns-server --network dns-lab alpine:latest \
  sh -c "apk add dnsmasq && echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && dnsmasq -k --log-facility=-"
```

### Get DNS Server IP
```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server
```

### Test Ubuntu
```bash
DNS_IP=<from above>
docker run --rm --network dns-lab --dns=$DNS_IP --dns-search="corp" ubuntu:latest getent hosts myservice.internal
```

### Test Alpine
```bash
DNS_IP=<from above>
docker run --rm --network dns-lab --dns=$DNS_IP --dns-search="corp" alpine:latest getent hosts myservice.internal
```

### View DNS Logs
```bash
docker logs dns-server 2>&1 | grep query
```

### Cleanup
```bash
docker stop dns-server
docker network rm dns-lab
```

---

## Troubleshooting Common Issues

| Problem | Check | Solution |
|---------|-------|----------|
| "Cannot connect to DNS server" | DNS IP correct? | Verify with `docker inspect` |
| "getent not found" | Tool installed? | Install `libc-bin` (Ubuntu) or `musl` (Alpine) |
| "No such file or directory" | Container path? | Use correct entry point |
| "Address already in use" | Port conflict? | Change port in docker-compose.yml |
| Tests run but show FAILED | Network isolated? | Check `docker network inspect` |

---

## Success Criteria

✅ Test successful if:
- DNS server starts without errors
- At least one container can resolve hostname
- Logs show DNS queries and replies
- No hanging or timeout issues
- Results are reproducible

❌ Test failed if:
- DNS server crashes
- Both containers fail to resolve
- No DNS queries appear in logs
- Consistent timeouts occur
- Cannot reproduce results
