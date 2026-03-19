---
sidebar_position: 3
---

# Database Configuration

Scanner uses PostgreSQL 18. By default, it runs PostgreSQL as a Docker Compose service. For production, you may want to use a managed database service.

## Default (Docker Compose PostgreSQL)

No additional configuration needed — PostgreSQL runs as the `postgres` service in the compose stack:

```bash title=".env"
POSTGRES_USER=scanner
POSTGRES_PASSWORD=your_strong_password
```

## Managed PostgreSQL (RDS, Azure, Cloud SQL, etc.)

Use `DATABASE_URL` for managed PostgreSQL:

```bash title=".env"
DATABASE_URL=postgresql://scanner:password@your-db-host.rds.amazonaws.com:5432/scanner_production?sslmode=require
```

`DATABASE_URL` takes precedence over individual `POSTGRES_*` variables.

### URL Format

```
postgresql://USERNAME:PASSWORD@HOSTNAME:PORT/DATABASE_NAME?sslmode=SSLMODE
```

### Special Characters in Passwords

URL-encode special characters in your password:

| Character | Encoded |
|---|---|
| `@` | `%40` |
| `!` | `%21` |
| `#` | `%23` |
| `$` | `%24` |
| `%` | `%25` |

Example: password `p@ss!word` becomes `p%40ss%21word` in the URL.

### SSL Modes

| Mode | Description |
|---|---|
| `disable` | No SSL |
| `allow` | Try non-SSL first, then SSL |
| `prefer` | Try SSL first, then non-SSL (default) |
| `require` | SSL required, no certificate verification |
| `verify-ca` | SSL + verify server certificate |
| `verify-full` | SSL + verify server certificate and hostname |

For most managed database services, use `sslmode=require`.

## Multi-Database Setup

Scanner uses separate PostgreSQL databases for different concerns. When `DATABASE_URL` is set, Scanner auto-generates the other database names by appending suffixes:

| Database | Default Name | Override Variable |
|---|---|---|
| Primary | `scanner_production` | — |
| Queue (Solid Queue) | `scanner_production_queue` | `DATABASE_QUEUE_URL` |
| Cache (Rails cache) | `scanner_production_cache` | `DATABASE_CACHE_URL` |
| Cable (Action Cable) | `scanner_production_cable` | `DATABASE_CABLE_URL` |

To use separate servers for each database, set the individual `DATABASE_*_URL` variables.

## Individual POSTGRES_* Variables

Alternatively, configure individual variables:

```bash title=".env"
POSTGRES_USER=scanner
POSTGRES_PASSWORD=your_strong_password
POSTGRES_HOST=your-db-host.rds.amazonaws.com
POSTGRES_PORT=5432

# SSL
POSTGRES_SSL_MODE=require

# For verify-ca or verify-full
POSTGRES_SSL_CERT=/storage/certs/client-cert.pem
POSTGRES_SSL_KEY=/storage/certs/client-key.pem
POSTGRES_SSL_ROOT_CERT=/storage/certs/ca-cert.pem
```

Mount certificate files into the container if needed:

```yaml title="docker-compose.yml"
services:
  scanner:
    volumes:
      - ./certs:/storage/certs:ro
```

## Connection Pool

| Variable | Default | Description |
|---|---|---|
| `POSTGRES_POOL_SIZE` | `5` | Max connections per process |
| `POSTGRES_POOL_TIMEOUT` | `5000` | Connection checkout timeout (ms) |

For high-concurrency deployments, increase `POSTGRES_POOL_SIZE`. Each Puma thread and Solid Queue worker consumes a connection.
