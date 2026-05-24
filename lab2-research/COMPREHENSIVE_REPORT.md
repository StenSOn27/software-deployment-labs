# Lab 2: Containerization - Comprehensive Research Report

## Executive Summary

This report documents comprehensive research on containerization approaches, focusing on:
1. Python application packaging with Docker
2. Golang multi-stage builds and image optimization
3. C library (musl vs glibc) behavior in containerized environments

---

## Part 1: Python Application Containerization

### Research Overview

The goal is to understand how different Docker approaches affect image size and build time for Python applications. We examined the FastAPI starter project with various optimization techniques.

### Experiment 1: Basic Dockerfile

**Objective**: Establish baseline metrics

**Dockerfile**: `Dockerfile.basic`

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements/ ./requirements/
COPY spaceship/ ./spaceship/
COPY build/ ./build/
RUN pip install --no-cache-dir fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]
EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Build Command**:
```bash
docker build -t spaceship:basic -f Dockerfile.basic .
```

**Expected Metrics**:
- Image size: ~150-200 MB (python:3.11-slim includes Python runtime)
- Build time: ~30-60 seconds (depends on pip dependency resolution)

**Analysis**:
- Inefficient layer caching: Application code and dependencies are copied together
- Any code change requires reinstalling dependencies
- Good starting point but not optimal for development

---

### Experiment 2: Optimized Dockerfile with Layer Caching

**Objective**: Improve build time for iterative development

**Dockerfile**: `Dockerfile.optimized`

```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Layer 1: System dependencies (rarely changes)
RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

# Layer 2: Python dependencies (changes occasionally)
COPY requirements/backend.in ./requirements/backend.in
RUN pip install --no-cache-dir fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]

# Layer 3: Application code (changes frequently)
COPY build/ ./build/
COPY spaceship/ ./spaceship/

EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Build Commands**:
```bash
# First build
docker build -t spaceship:optimized -f Dockerfile.optimized .

# After code change only
docker build -t spaceship:optimized -f Dockerfile.optimized .
```

**Expected Metrics**:
- **Initial image size**: ~150-200 MB (same as basic)
- **First build time**: ~30-60 seconds
- **Rebuild after code change**: ~5-10 seconds (only rebuilds last layer)

**Analysis**:
- Layer caching dramatically improves build time for code-only changes
- Dependencies are only reinstalled when requirements change
- Recommended for development environments
- Small overhead of system dependencies (gcc) but necessary for pip compilation

---

### Experiment 3: Alpine Base Image (Minimal)

**Objective**: Reduce image size using lightweight base

**Dockerfile**: `Dockerfile.alpine`

```dockerfile
FROM python:3.11-alpine
WORKDIR /app

# Install system dependencies for compilation
RUN apk add --no-cache gcc musl-dev

# Install Python dependencies
COPY requirements/backend.in ./requirements/backend.in
RUN pip install --no-cache-dir fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]

# Copy application code
COPY build/ ./build/
COPY spaceship/ ./spaceship/

EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Build Commands**:
```bash
docker build -t spaceship:alpine -f Dockerfile.alpine .
```

**Expected Metrics**:
- **Image size**: ~80-120 MB (significantly smaller than Debian-based)
- **Build time**: ~60-120 seconds (compilation may take longer on Alpine)
- **Base image size**: ~13 MB (vs. 60 MB for python:3.11-slim)

**Analysis**:
- **Advantages**:
  - Much smaller image size (~40-50% smaller)
  - Faster image distribution
  - Lower memory footprint

- **Disadvantages**:
  - Uses musl libc instead of glibc
  - Build time may be longer due to compilation
  - Some packages compile differently on Alpine
  - DNS resolution behavior differs from glibc
  - Less compatibility with pre-compiled Python wheels

- **Use Cases**: 
  - Suitable for production deployments where size matters
  - Good for CI/CD pipelines with limited storage
  - Acceptable for stateless microservices

---

### Experiment 4: Adding NumPy Dependency

**Objective**: Evaluate impact of native compilation packages and glibc vs musl differences

**Modified Files**:
- `requirements/backend.in`: Added `numpy`
- `spaceship/routers/api.py`: Added `/matrix/multiply` endpoint

**New Endpoint**:
```python
@router.get('/matrix/multiply')
def multiply_matrices() -> dict:
    import numpy as np
    a = np.random.rand(10, 10)
    b = np.random.rand(10, 10)
    product = np.matmul(a, b)
    return {
        "matrix_a": a.tolist(),
        "matrix_b": b.tolist(),
        "product": product.tolist()
    }
```

**Comparison: Debian vs Alpine with NumPy**

#### Debian (glibc) Version

**Dockerfile**: `Dockerfile.numpy-debian`

```bash
docker build -t spaceship:numpy-debian -f Dockerfile.numpy-debian .
```

**Expected Metrics**:
- **Image size**: ~350-400 MB
- **Build time**: ~60-90 seconds
- **NumPy installation**: Uses pre-compiled wheels (faster)

#### Alpine (musl) Version

**Dockerfile**: `Dockerfile.numpy-alpine`

```bash
docker build -t spaceship:numpy-alpine -f Dockerfile.numpy-alpine .
```

**Expected Metrics**:
- **Image size**: ~200-250 MB (still smaller than Debian, but larger than expected)
- **Build time**: ~120-180 seconds (compilation required)
- **NumPy installation**: Requires compilation from source

**Analysis**:

| Aspect | Debian (glibc) | Alpine (musl) |
|--------|---|---|
| Image size | ~350-400 MB | ~200-250 MB |
| Build time | ~60-90 s | ~120-180 s |
| Build method | Pre-compiled wheels | Source compilation |
| NumPy wheels availability | Excellent | Limited |
| Performance | Native glibc optimizations | Standard musl |
| Runtime compatibility | Best | Good, with caveats |

**Key Findings**:
1. NumPy is available for Alpine but requires compilation
2. Alpine image remains significantly smaller even with NumPy
3. Build time trade-off exists: Alpine is slower to build but faster to distribute
4. For packages with native dependencies, Debian is more convenient
5. Choice depends on deployment frequency vs. image size constraints

---

## Part 2: musl vs glibc DNS Resolution Analysis

### Background

The C library (libc) is fundamental to Linux systems:
- **glibc**: GNU C Library (used by Debian, Ubuntu, most Linux distributions)
- **musl**: A lightweight alternative C library (used by Alpine Linux)

These libraries implement DNS resolution differently, which can cause subtle compatibility issues in containers.

### Research Methodology

#### Setup: Docker Network with DNS Server

```bash
# Create isolated network
docker network create dns-lab

# Start DNS server (Alpine with dnsmasq)
docker run --rm -it --name dns-server --network dns-lab \
  alpine sh -c "apk add dnsmasq && \
  echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
  dnsmasq -k --log-queries --log-facility=-"
```

#### Test 1: Ubuntu (glibc) DNS Resolution

```bash
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  ubuntu:latest getent hosts myservice.internal
```

**Expected Output**:
```
10.0.0.50 myservice.internal
```

**Behavior**:
- glibc DNS resolver will append search domains automatically
- Searches: `myservice.internal.corp` → `myservice.internal`
- Successfully resolves custom domain

#### Test 2: Alpine (musl) DNS Resolution

```bash
docker run --rm --network dns-lab \
  --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
  --dns-search="corp" \
  alpine:latest getent hosts myservice.internal
```

**Expected Output**:
```
10.0.0.50 myservice.internal
```

**Behavior**:
- musl DNS resolver has different search domain behavior
- May have stricter validation or different caching behavior
- May fail or succeed differently than glibc version

### Analysis

**Key Differences**:

1. **Search Domain Handling**:
   - glibc: Applies search domains more flexibly
   - musl: May be more strict about FQDN matching

2. **DNS Caching**:
   - glibc: Implements nscd (Name Service Cache Daemon)
   - musl: Simpler, more direct DNS queries

3. **Negative Caching**:
   - glibc: Caches failed lookups to reduce DNS queries
   - musl: May have different negative cache TTL

4. **Configuration Parsing**:
   - glibc: More permissive about resolv.conf syntax
   - musl: Stricter parsing

### Implications for Container Development

**Problems that may arise**:
1. Application works in Debian container but fails in Alpine
2. DNS-dependent services may behave inconsistently
3. Service discovery in distributed systems may fail

**Recommendations**:
1. Use fully qualified domain names (FQDN) when possible
2. Test DNS resolution behavior in target container environment
3. Avoid relying on search domain behavior if using Alpine
4. Document DNS requirements explicitly in deployment guides
5. Consider using explicit IP addresses or environment variables for critical services

---

## Part 3: Golang Multi-stage Builds

### Research Overview

Go applications can be optimized significantly through multi-stage builds. The build artifacts contain only the compiled binary, while the build toolchain is discarded.

### Experiment 1: Basic Golang Dockerfile

**Objective**: Establish baseline

**Dockerfile**: `Dockerfile.basic`

```dockerfile
FROM golang:1.21
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY lib/ ./lib/
COPY templates/ ./templates/
COPY main.go .
RUN go build -o app .
EXPOSE 8080
CMD ["./app"]
```

**Expected Metrics**:
- **Image size**: ~800 MB - 1.2 GB
- **Build time**: ~30-60 seconds
- **Contents**: Full Go toolchain, source code, compiled binary, all dependencies

**Analysis**:
- Wasteful: Includes entire Go SDK and build tools in final image
- Production images are unnecessarily large
- Contains source code that could be a security/licensing concern

---

### Experiment 2: Multi-stage Build with FROM scratch

**Objective**: Create minimal image with only compiled binary

**Dockerfile**: `Dockerfile.multistage-scratch`

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY lib/ ./lib/
COPY templates/ ./templates/
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM scratch
COPY --from=builder /app/app /app
EXPOSE 8080
CMD ["/app"]
```

**Key Details**:
- **`CGO_ENABLED=0`**: Disable C bindings for static linking
- **`GOOS=linux`**: Compile for Linux target
- **`FROM scratch`**: Empty base image (only ~1 KB)

**Expected Metrics**:
- **Image size**: ~5-15 MB (binary only)
- **Build time**: ~30-60 seconds (same as basic, only final image is smaller)
- **Final image layers**: Only the binary (2 layers total)

**Advantages**:
- Dramatically smaller image (~50-100x reduction)
- Fastest deployment
- Minimal attack surface

**Disadvantages**:
- Cannot debug inside container (no shell)
- Cannot inspect filesystem
- Binary must be completely self-contained
- May fail with cryptic "no such file or directory" errors if dependencies are missing
- Cannot install anything at runtime

**Use Cases**:
- Production deployments where size matters
- Kubernetes and container orchestration
- CI/CD pipelines with bandwidth constraints

---

### Experiment 3: Multi-stage Build with Distroless

**Objective**: Balance between minimal footprint and runtime capabilities

**Dockerfile**: `Dockerfile.multistage-distroless`

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY lib/ ./lib/
COPY templates/ ./templates/
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o app .

FROM gcr.io/distroless/base-debian11
COPY --from=builder /app/app /app
EXPOSE 8080
CMD ["/app"]
```

**Expected Metrics**:
- **Image size**: ~20-30 MB (binary + minimal runtime utilities)
- **Build time**: ~30-60 seconds

**Contents** (distroless images include):
- Basic libc library
- Certificate authorities (for HTTPS)
- Timezone data
- No shell, no package manager

**Advantages**:
- Smaller than regular Linux images (~10x reduction from golang:1.21)
- Can execute binaries that depend on libc
- Includes SSL/TLS certificate chains
- Still debuggable with tools like `docker exec` for logging

**Disadvantages**:
- Cannot execute shell commands interactively
- No package installation capability
- Still larger than scratch (~25 MB vs 10 MB)

**Use Cases**:
- Production deployment (preferred over scratch for ease of debugging)
- Applications that need SSL/TLS certificates
- Balance between size and debuggability

### Comparison Table: Go Image Options

| Aspect | Basic | Scratch | Distroless |
|--------|-------|---------|-----------|
| **Image Size** | 800 MB - 1.2 GB | 5-15 MB | 20-30 MB |
| **Build Time** | ~30-60 s | ~30-60 s | ~30-60 s |
| **Contains** | Full SDK, source, binary | Binary only | Binary, libc, certs |
| **Can shell in** | Yes | No | No (limited) |
| **SSL/TLS certs** | Yes (full) | No | Yes |
| **Debugging** | Easy | Very hard | Hard |
| **Production-ready** | No | Yes, for simple apps | Yes (recommended) |
| **Use case** | Development | Size-critical | Typical production |

---

## Conclusions and Recommendations

### Python Applications

1. **For Development**:
   - Use Debian-based images with optimized Dockerfiles
   - Implement proper layer caching (dependencies before code)
   - Size is less important than build speed

2. **For Production**:
   - Use Alpine for size-critical deployments
   - Consider build time trade-offs
   - Test native packages (NumPy, etc.) thoroughly on Alpine
   - Document Alpine-specific behavior

3. **Dependency Management**:
   - Use `pip freeze` or similar for reproducible builds
   - Always specify Python version explicitly
   - Consider using distroless Python images for production

### Golang Applications

1. **For Production (Recommended)**:
   - Use multi-stage builds with distroless images
   - Provides ~50x size reduction from basic images
   - Includes necessary runtime libraries
   - Maintains some debugging capability

2. **For Size-Critical Deployments**:
   - Use FROM scratch with careful binary validation
   - Ensure all dependencies are statically linked
   - Thoroughly test before deployment

3. **Build Optimization**:
   - Use layer caching for build artifacts
   - Separate dependency download from build step
   - Consider using `go mod tidy` before building

### Container Networking and Compatibility

1. **DNS Considerations**:
   - Test DNS resolution in target container environment
   - Prefer FQDN over relying on search domains
   - Document DNS dependencies

2. **C Library Implications**:
   - Test Alpine containers thoroughly if using native dependencies
   - Consider glibc vs musl differences in dependency compilation
   - Plan for longer build times with Alpine when native compilation is needed

3. **General Guidance**:
   - Use Debian-based images by default for compatibility
   - Use Alpine when size is critical and after thorough testing
   - Consider intermediate options like distroless for balanced approach

---

## References and Tools

**Docker Documentation**:
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)

**Image Analysis Tools**:
- `docker inspect` - View layer details
- `docker history` - View build steps
- `dive` - Interactive image exploration tool

**Alpine Documentation**:
- [Alpine Linux official site](https://alpinelinux.org/)
- [Alpine package index](https://pkgs.alpinelinux.org/packages)

**Go Tooling**:
- `go mod graph` - Dependency visualization
- `go tool nm` - Examine binary symbols

---

**Report Generated**: 2026-05-24
**Author**: Lab 2 Research Study
