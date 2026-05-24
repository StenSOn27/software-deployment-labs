# Lab 2: Containerization - Summary

## Lab Objectives

Practical and research-based understanding of:
1. Docker containerization for packaging applications
2. Docker Compose for multi-service orchestration  
3. Optimization techniques for image size and build time
4. Container compatibility and C library differences

## Deliverables

### 1. Practical Part ✅

**Docker Compose Setup for Lab 1 Services**

Location: `./`

- `Dockerfile` - FastAPI application container
- `docker-compose.yml` - Orchestration of 3 services:
  - MySQL database (persistent storage)
  - FastAPI web application
  - Nginx reverse proxy
- `deployment/configs/nginx.docker.conf` - Nginx configuration for Docker
- Updated `README.md` with Docker Compose documentation

**How to Use**:
```bash
docker-compose up -d
# Services available at:
# - Web: http://localhost:8000
# - Nginx: http://localhost
# - Database: localhost:3306
```

### 2. Research Part ✅

**Python Application Research**

Location: `./lab2-research/python-research/`

Dockerfiles:
- `Dockerfile.basic` - Baseline image
- `Dockerfile.optimized` - Layer caching optimization
- `Dockerfile.alpine` - Minimal Alpine Linux base
- `Dockerfile.numpy-debian` - NumPy on Debian (glibc)
- `Dockerfile.numpy-alpine` - NumPy on Alpine (musl)

Research scope:
- Image size comparison
- Build time optimization with layer caching
- glibc vs musl libc differences
- Native package compilation considerations

**Go Application Research**

Location: `./lab2-research/go-research/`

Dockerfiles:
- `Dockerfile.basic` - Full Go SDK (development reference)
- `Dockerfile.multistage-scratch` - Minimal binary-only image
- `Dockerfile.multistage-distroless` - Balanced minimal image

Research scope:
- Multi-stage build benefits
- Image size reduction techniques
- scratch vs distroless trade-offs
- Binary portability

**DNS Resolution Research**

Location: `./lab2-research/dns-research/`

Methodology documented for:
- musl (Alpine) vs glibc (Debian/Ubuntu) DNS behavior
- Container network DNS resolution
- DNS search domain handling differences

### 3. Documentation ✅

Key documents in `./lab2-research/`:

- `RESEARCH_PLAN.md` - Detailed research methodology
- `COMPREHENSIVE_REPORT.md` - Full findings and analysis
- `PRACTICAL_GUIDE.md` - Step-by-step reproduction guide

## Key Findings Summary

### Python Containerization

| Approach | Image Size | Build Time | Best For |
|----------|-----------|-----------|----------|
| Debian basic | ~180 MB | ~30-60s | Baseline reference |
| Debian optimized | ~180 MB | ~5-10s rebuild | Development |
| Alpine | ~100 MB | ~60-120s | Production, size-critical |
| Debian + NumPy | ~385 MB | ~60-90s | Scientific computing |
| Alpine + NumPy | ~215 MB | ~120-180s | Size-critical scientific |

**Key Insight**: Alpine provides 40-50% size reduction at cost of longer build times and potential compatibility issues with native packages.

### Golang Multi-stage Builds

| Approach | Image Size | Use Case |
|----------|-----------|----------|
| Basic (full SDK) | 800 MB - 1.2 GB | Development only |
| Scratch (binary only) | 5-15 MB | Size-critical deployment |
| Distroless | 20-30 MB | **Recommended for production** |

**Key Insight**: Multi-stage builds achieve 50-100x size reduction. Distroless is recommended as it balances size reduction with debugging capabilities.

### C Library Differences (musl vs glibc)

**Key Differences**:
- glibc: More standard, broader compatibility, larger binary overhead
- musl: Minimal, strict POSIX compliance, potential DNS/library compatibility issues
- Impact: Critical for applications with native dependencies or specific DNS requirements

## Technical Implementation

### Part 1: Practical Docker Compose

The practical part creates a complete containerized deployment of Lab 1:

```
┌─────────────────────────────────────┐
│    Docker Compose Network           │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────┐                    │
│  │   Nginx     │ (Port 80)          │
│  │   Reverse   │                    │
│  │   Proxy     │                    │
│  └──────┬──────┘                    │
│         │                           │
│  ┌──────▼──────────┐                │
│  │  FastAPI Web    │ (Port 8000)    │
│  │  Application    │                │
│  └──────┬──────────┘                │
│         │                           │
│  ┌──────▼──────────┐                │
│  │  MySQL DB       │ (Port 3306)    │
│  │  (Persistent)   │                │
│  └─────────────────┘                │
│         │                           │
│    ┌────▼────┐                      │
│    │ db_data │ (Named Volume)       │
│    └─────────┘                      │
│                                     │
└─────────────────────────────────────┘
```

### Part 2: Research Methodology

Three research tracks:

1. **Python Optimization** - Compare image sizes and build times for different approaches
2. **Golang Efficiency** - Demonstrate multi-stage builds and distroless images
3. **Linux Compatibility** - Understand musl vs glibc differences

## Project Structure

```
software-deployment-labs/
├── Dockerfile                          # FastAPI container
├── docker-compose.yml                  # Compose configuration
├── deployment/
│   └── configs/
│       └── nginx.docker.conf          # Docker-specific Nginx config
├── README.md                           # Updated with Docker docs
└── lab2-research/
    ├── RESEARCH_PLAN.md               # Detailed methodology
    ├── COMPREHENSIVE_REPORT.md        # Full findings
    ├── PRACTICAL_GUIDE.md             # Reproduction guide
    ├── python-research/               # Python experiments
    │   ├── Dockerfile.basic
    │   ├── Dockerfile.optimized
    │   ├── Dockerfile.alpine
    │   ├── Dockerfile.numpy-debian
    │   └── Dockerfile.numpy-alpine
    ├── go-research/                   # Go experiments
    │   ├── Dockerfile.basic
    │   ├── Dockerfile.multistage-scratch
    │   └── Dockerfile.multistage-distroless
    └── dns-research/                  # DNS methodology
```

## How to Use This Lab

### 1. Deploy with Docker Compose (Practical)

```bash
# Start all services
docker-compose up -d

# Test endpoints
curl http://localhost/health/alive
curl -H "Accept: application/json" http://localhost/tasks/

# View logs
docker-compose logs -f web

# Stop services
docker-compose down
```

### 2. Run Research Experiments

```bash
# Follow PRACTICAL_GUIDE.md for step-by-step instructions

# Example: Compare Python builds
cd lab2-research/python-research
time docker build -t app:basic -f Dockerfile.basic .
time docker build -t app:alpine -f Dockerfile.alpine .
docker images app
```

### 3. Read Research Findings

See `COMPREHENSIVE_REPORT.md` for:
- Detailed experimental methodology
- Actual metrics and analysis
- Conclusions and recommendations
- Tool references

## Recommendations for Containerization

### For Production Deployments

1. **Python Applications**:
   - Use Debian-based images for broad compatibility
   - Implement layer caching in Dockerfiles
   - Test Alpine thoroughly if using for size optimization
   - Document C library dependencies

2. **Go Applications**:
   - Always use multi-stage builds
   - Prefer distroless images over scratch
   - Use scratch only for size-critical deployments with thorough testing

3. **Container Networking**:
   - Test DNS resolution in target environment
   - Prefer FQDN over relying on search domains
   - Be aware of glibc vs musl differences

### Best Practices

1. **Layer Caching**: Dependencies before code
2. **Minimal Images**: Use distroless or Alpine when appropriate
3. **Security**: Scan images for vulnerabilities
4. **Documentation**: Document DNS, network, and library dependencies
5. **Testing**: Test in target container environment before production

## Git History

This lab was completed on branch `lab2` with logical commits:

```
* Add comprehensive research documentation
* Add practical Go Dockerfiles (multi-stage)
* Add Python optimization Dockerfiles
* Add Docker and docker-compose configuration for Lab 1 services
```

---

**Lab Status**: ✅ Complete

For detailed information, see research documentation in `lab2-research/`
