# Practical Guide: Running Lab 2 Experiments

This guide provides step-by-step instructions to reproduce all experiments from Lab 2.

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+ (for docker-compose experiments)
- Bash/Shell terminal
- At least 2GB free disk space for Docker images

## Part 1: Python Application Experiments

### Setup

```bash
cd lab2-research/python-research
```

### Experiment 1: Basic Dockerfile

```bash
# Build image
time docker build -t spaceship:basic -f Dockerfile.basic .

# Check image size
docker images spaceship:basic

# View build history
docker history spaceship:basic

# Test the application
docker run -p 8000:8000 spaceship:basic &
sleep 2
curl http://localhost:8000/
kill %1
```

**Record**:
- Image size: `docker images spaceship:basic` → SIZE column
- Build time: Captured by `time` command

### Experiment 2: Optimized Dockerfile

```bash
# First build (cold cache)
time docker build -t spaceship:optimized -f Dockerfile.optimized .

# Record first build time and image size
docker images spaceship:optimized

# Modify code (add a comment)
echo "# Added for Lab 2 Research" >> spaceship/app.py

# Rebuild (warm cache)
time docker build -t spaceship:optimized -f Dockerfile.optimized .

# Record rebuild time (should be much faster!)
```

**Key Observation**: Second build should be significantly faster due to layer caching.

### Experiment 3: Alpine Dockerfile

```bash
time docker build -t spaceship:alpine -f Dockerfile.alpine .
docker images spaceship:alpine

# Compare sizes
docker images | grep spaceship
```

**Metrics to Compare**:
```
REPOSITORY  TAG        IMAGE ID  CREATED      SIZE
spaceship   basic      ...       ...          ~180MB
spaceship   optimized  ...       ...          ~180MB (same as basic)
spaceship   alpine     ...       ...          ~100MB (40% smaller)
```

### Experiment 4: NumPy Experiments

#### Prepare

```bash
# Verify numpy is in requirements
cat requirements/backend.in

# Test the endpoint
docker run -p 8000:8000 spaceship:numpy-debian &
sleep 3
curl http://localhost:8000/api/matrix/multiply | python -m json.tool | head -20
kill %1
```

#### Debian Version

```bash
time docker build -t spaceship:numpy-debian -f Dockerfile.numpy-debian .
docker images spaceship:numpy-debian
```

#### Alpine Version

```bash
time docker build -t spaceship:numpy-alpine -f Dockerfile.numpy-alpine .
docker images spaceship:numpy-alpine

# Compare build output - note if compilation happens
```

**Analysis**:
- Alpine build should show numpy compilation (longer output)
- Debian build should use pre-compiled wheels (shorter output)
- Alpine final size should still be smaller than Debian

## Part 2: DNS Resolution Research

### Setup

```bash
# Create isolated network
docker network create dns-lab
```

### Run DNS Server

```bash
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  dnsmasq -k --log-queries --log-facility=-"

# Keep this running in one terminal window
# (You'll see DNS queries printed)
```

### Test from Ubuntu (glibc)

In another terminal:

```bash
DNS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)

docker run --rm --network dns-lab \
  --dns=$DNS_IP \
  --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal
```

**Expected Output**: `10.0.0.50 myservice.internal`

### Test from Alpine (musl)

```bash
DNS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server)

docker run --rm --network dns-lab \
  --dns=$DNS_IP \
  --dns-search="corp" \
  alpine:latest getent hosts myservice.internal
```

**Expected Output**: Same as Ubuntu (should both work, or both fail)

### Analysis

1. Check DNS server logs (first terminal window)
2. Look for differences in query patterns
3. Note whether:
   - Both containers resolve successfully
   - One fails and one succeeds
   - Query behavior differs (search domain appending, etc.)

## Part 3: Golang Experiments

### Setup

```bash
cd ../go-research
```

### Experiment 1: Basic Build

```bash
time docker build -t go-app:basic -f Dockerfile.basic .
docker images go-app:basic

# Analyze contents
docker history go-app:basic
```

**Observation**: Full Go SDK included (~800 MB - 1.2 GB)

### Experiment 2: Multi-stage Scratch

```bash
time docker build -t go-app:scratch -f Dockerfile.multistage-scratch .
docker images go-app:scratch

# Compare sizes
docker images | grep go-app
```

**Expected Size Reduction**: From ~1 GB to ~10 MB (100x smaller!)

### Experiment 3: Distroless

```bash
time docker build -t go-app:distroless -f Dockerfile.multistage-distroless .
docker images go-app:distroless

# Compare all three
docker images go-app
```

**Expected Sizes**:
- basic: ~800 MB - 1.2 GB
- scratch: ~5-15 MB
- distroless: ~20-30 MB

## Comprehensive Metrics Collection Script

```bash
#!/bin/bash
# collect_metrics.sh - Automate measurements

echo "=== IMAGE SIZE COMPARISON ==="
docker images | grep -E "spaceship|go-app"

echo ""
echo "=== BUILD TIME MEASUREMENTS ==="
echo "Rebuilding images to measure build time..."

time docker build -t spaceship:basic -f Dockerfile.basic lab2-research/python-research/ > /dev/null 2>&1
echo "basic complete"

time docker build -t spaceship:optimized -f Dockerfile.optimized lab2-research/python-research/ > /dev/null 2>&1
echo "optimized complete"

time docker build -t spaceship:alpine -f Dockerfile.alpine lab2-research/python-research/ > /dev/null 2>&1
echo "alpine complete"

time docker build -t go-app:basic -f Dockerfile.basic lab2-research/go-research/ > /dev/null 2>&1
echo "go-app:basic complete"

time docker build -t go-app:scratch -f Dockerfile.multistage-scratch lab2-research/go-research/ > /dev/null 2>&1
echo "go-app:scratch complete"

echo ""
echo "=== FINAL COMPARISON ==="
docker images | grep -E "spaceship|go-app"
```

## Cleanup

```bash
# Remove images to free space
docker rmi spaceship:basic spaceship:optimized spaceship:alpine spaceship:numpy-debian spaceship:numpy-alpine
docker rmi go-app:basic go-app:scratch go-app:distroless

# Remove network
docker network rm dns-lab

# Remove all Docker images (careful!)
# docker system prune -a
```

## Troubleshooting

### "Cannot find file or directory" errors

If you see errors like `exec format error` or `file not found`:
- The binary depends on libraries not in `scratch`
- Try distroless instead
- Add required libraries to the image

### Build failures with numpy on Alpine

Alpine requires compilation toolchain for numpy:
```bash
# Ensure these are installed
RUN apk add --no-cache gcc musl-dev python3-dev
```

### DNS doesn't resolve

Check that:
- DNS server container is still running
- Both containers are on the same network (`--network dns-lab`)
- DNS IP address is correct (rerun `docker inspect` command)

### Image size larger than expected

Check what's included:
```bash
docker history image-name
```

Look for large layers and consider if they're necessary.

## Example Output

```
REPOSITORY     TAG              IMAGE ID       CREATED        SIZE
spaceship      basic            a1b2c3d4e5f6   2 min ago      182MB
spaceship      optimized        f6e5d4c3b2a1   1 min ago      182MB
spaceship      alpine           e5d4c3b2a1f6   30 sec ago     98MB
spaceship      numpy-debian     d4c3b2a1f6e5   45 sec ago     385MB
spaceship      numpy-alpine     c3b2a1f6e5d4   2 min ago      215MB
go-app         basic            b2a1f6e5d4c3   1 min ago      845MB
go-app         scratch          a1f6e5d4c3b2   40 sec ago     12MB
go-app         distroless       f6e5d4c3b2a1   50 sec ago     25MB
```

---

For detailed analysis, see `COMPREHENSIVE_REPORT.md`
