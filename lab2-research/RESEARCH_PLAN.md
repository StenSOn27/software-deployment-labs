# Lab 2: Containerization Research Plan

## Overview

This document outlines the research methodology for Lab Work №2 on containerization. The research focuses on comparing different Docker approaches and their impact on image size and build time.

## Part 1: Python Application Research

### Project Structure
- **Source**: https://github.com/KPI-FICT-MTSD/lab-03-starter-project-python
- **Framework**: FastAPI with Pydantic
- **Dependencies**: fastapi, pydantic>=2.0, pydantic-settings, starlette, uvicorn[standard]

### Experiment 1: Basic Dockerfile
**Objective**: Establish baseline image size and build time

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements/ .
COPY spaceship/ ./spaceship/
COPY build/ ./build/

RUN pip install fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]

EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Metrics to measure**:
- Image size (output of `docker images`)
- Build time (output of `docker build --progress=plain`)

### Experiment 2: Code Modification
**Objective**: Test Docker layer caching behavior

1. Add comment to `spaceship/app.py` with name/surname
2. Add `print()` statement to display name in startup
3. Rebuild and measure:
   - Image size
   - Build time (cache hit for base layers)

### Experiment 3: Optimized Dockerfile with Layer Caching
**Objective**: Leverage Docker layer caching for faster builds

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (rarely changes)
RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (changes occasionally)
COPY requirements/backend.in .
RUN pip install --no-cache-dir fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]

# Copy application code (changes frequently)
COPY build/ ./build/
COPY spaceship/ ./spaceship/

EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Metrics**:
- Image size
- Build time (should be much faster for code-only changes)

### Experiment 4: Alpine Base Image
**Objective**: Compare Debian-based vs musl-based minimal images

```dockerfile
FROM python:3.11-alpine

WORKDIR /app
RUN apk add --no-cache gcc musl-dev

COPY requirements/backend.in .
RUN pip install --no-cache-dir fastapi pydantic>=2.0 pydantic-settings starlette uvicorn[standard]

COPY build/ ./build/
COPY spaceship/ ./spaceship/

EXPOSE 8000
CMD ["uvicorn", "spaceship.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Metrics**:
- Image size (comparison with Debian)
- Build time
- Note: Alpine uses musl libc instead of glibc

### Experiment 5: Adding NumPy Dependency
**Objective**: Evaluate impact of native compilation packages

1. Add numpy to requirements/backend.in
2. Create endpoint in `spaceship/routers/api.py`:
   ```python
   @router.get("/matrix/multiply")
   async def multiply_matrices():
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

3. Build for both Debian and Alpine, measure:
   - Image size
   - Build time
   - **Important note**: NumPy requires compilation on Alpine (musl), may differ from Debian (glibc)

## Part 2: musl vs glibc DNS Resolution

### Objective
Compare DNS resolution behavior between Alpine (musl) and Ubuntu (glibc)

### Methodology

1. Create docker network: `docker network create dns-lab`

2. Run DNS server (Alpine dnsmasq):
   ```bash
   docker run --rm -it --name dns-server --network dns-lab \
     alpine sh -c "apk add dnsmasq && \
     echo 'address=/myservice.internal.corp/10.0.0.50' > /etc/dnsmasq.conf && \
     dnsmasq -k --log-queries --log-facility=-"
   ```

3. Test from Ubuntu container:
   ```bash
   docker run --rm --network dns-lab \
     --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
     --dns-search="corp" \
     ubuntu:latest getent hosts myservice.internal
   ```

4. Test from Alpine container:
   ```bash
   docker run --rm --network dns-lab \
     --dns=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dns-server) \
     --dns-search="corp" \
     alpine:latest getent hosts myservice.internal
   ```

### Expected Findings
- **glibc (Ubuntu)**: May resolve using longer DNS search
- **musl (Alpine)**: DNS behavior may differ due to different C library implementation
- This is important for container compatibility and library behavior differences

## Part 3: Go Application with Multi-stage Builds

### Project
- **Source**: https://github.com/comsys-kpi-ua/deploy.lab-containers-starter-project-golang
- **Objective**: Reduce final image size using multi-stage builds

### Experiment 1: Basic Go Dockerfile

```dockerfile
FROM golang:1.21

WORKDIR /app
COPY . .

RUN go build -o app .

EXPOSE 8080
CMD ["./app"]
```

**Metrics**:
- Image size
- Build time
- Contents analysis (too much development tooling included)

### Experiment 2: Multi-stage Build with Scratch

```dockerfile
FROM golang:1.21 AS builder

WORKDIR /app
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o app .

FROM scratch

COPY --from=builder /app/app /app

EXPOSE 8080
CMD ["/app"]
```

**Metrics**:
- Image size (dramatic reduction)
- Build time
- Analysis: Is app still functional? File availability issues?

### Experiment 3: Distroless Images

```dockerfile
FROM golang:1.21 AS builder

WORKDIR /app
COPY . .

RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/base-debian11

COPY --from=builder /app/app /app

EXPOSE 8080
CMD ["/app"]
```

**Metrics**:
- Image size
- Build time  
- Contents comparison with scratch (includes shell, basic utilities)
- Debugging capabilities

## Measurement Methodology

### Build Time
1. Pull base image separately first: `docker pull <image>`
2. Time only the build steps: `time docker build .`
3. Run multiple times to get average
4. Note: Cache invalidation on code changes

### Image Size
- Use `docker images` for total size
- Use `docker inspect <image>` for layer details
- Use `dive` tool for detailed layer analysis if available: `dive <image>`

### Analysis Tools
- `docker inspect` - view image layers
- `docker history` - view build steps and their sizes
- `dive` - interactive image analysis tool

## Documentation

All results will be documented in a comprehensive report that includes:
1. Actual measurements for each experiment
2. Screenshots/outputs of measurements
3. Analysis of findings
4. Conclusions and recommendations for containerizing applications

## Notes

- Ensure reproducibility: Document exact command used, versions, host system specs
- For accurate comparisons, run on the same system
- Consider network conditions when measuring build time
- Cache behavior significantly impacts build time measurements
