---
sidebar_position: 3
---

# Architecture

## Component Overview

```mermaid
graph TD
    subgraph Docker["Docker Container"]
        Thruster["Thruster\n(HTTP/2 proxy)"]
        Puma["Puma\n(Rails app server)"]
        SQ["Solid Queue\n(background jobs, in-process)"]
    end

    subgraph DBs["PostgreSQL 18 (4 databases)"]
        Primary["scanner_production\n(primary)"]
        Queue["scanner_production_queue\n(job queue)"]
        Cache["scanner_production_cache\n(cache)"]
        Cable["scanner_production_cable\n(ActionCable)"]
    end

    subgraph External["External Services"]
        AI["AI Providers\n(OpenAI, Anthropic, etc.)"]
        SIEM["SIEM\n(Splunk / Rsyslog)"]
    end

    Browser --> Thruster
    Thruster --> Puma
    Puma --> SQ
    Puma --> Primary
    Puma --> Cache
    Puma --> Cable
    SQ --> Queue
    SQ --> Garak

    subgraph Garak["garak subprocess"]
        GarakProcess["garak\n(Python, Unix socket)"]
    end

    GarakProcess --> AI
    SQ --> SIEM
```

## Key Design Decisions

### Single-Process Architecture

Puma and Solid Queue run in the same container process. This simplifies deployment — a single Docker container runs everything except PostgreSQL. The tradeoff is that you can't scale the web server and job workers independently.

### garak as a Subprocess

[NVIDIA garak](https://github.com/NVIDIA/garak) is a Python library. Scanner invokes it as a separate process and communicates via a Unix socket. This isolates Python dependency management from the Rails app and lets garak run with its own environment.

The `RunGarakScan` service class manages the garak subprocess lifecycle. Scan results are streamed back through the socket and written to the database in real time.

### Multi-Database PostgreSQL

Rails 8's multi-database support splits concerns across four databases:

| Database | Purpose |
|---|---|
| `scanner_production` | Application data (targets, scans, reports, users) |
| `scanner_production_queue` | Solid Queue job tables |
| `scanner_production_cache` | Rails cache store |
| `scanner_production_cable` | Action Cable subscription data |

This improves isolation and allows different retention/backup policies per database.

### Multi-Tenancy

Scanner uses [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant) for row-level multi-tenancy. Every company's data is scoped to their tenant in all queries. Encrypted fields use per-tenant keys derived from `SECRET_KEY_BASE`.

:::important
All code that accesses encrypted fields must run within a tenant scope:
```ruby
ActsAsTenant.with_tenant(company) { ... }
```
Controllers handle this automatically. Background jobs must do it explicitly.
:::

### Encryption at Rest

Sensitive fields are encrypted using ActiveRecord Encryption:

| Model | Encrypted Fields |
|---|---|
| `Target` | `json_config`, `web_config` |
| `EnvironmentVariable` | `env_value` |

Encryption keys are derived per-tenant from `SECRET_KEY_BASE` via HMAC. See `config/initializers/active_record_encryption.rb`.

## Extension Points

See [Extension Points](./extension-points) for the full API. The three extension points are:

- **`Scanner.configure`** — service class overrides and lifecycle hooks
- **`BrandConfig.configure`** — branding and theming
- **`ProbeSourceRegistry`** — additional probe data sources

## Technology Stack

| Layer | Technology |
|---|---|
| Framework | Ruby on Rails 8 |
| Database | PostgreSQL 18 |
| Background jobs | Solid Queue (in-process with Puma) |
| Frontend | Stimulus + Turbo (Hotwire), Tailwind CSS |
| AI Scanner | NVIDIA garak (Python) |
| Auth | Devise |
| HTTP proxy | Thruster (HTTP/2, asset compression) |
| Containerization | Docker |
