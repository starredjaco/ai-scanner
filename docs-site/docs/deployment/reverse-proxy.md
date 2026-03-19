---
sidebar_position: 2
---

# Reverse Proxy & TLS

Scanner runs plain HTTP internally. For production deployments, place it behind a reverse proxy that handles TLS termination.

## Required: Set ASSUME_SSL

When Scanner is behind a TLS-terminating proxy, set this in your `.env`:

```bash
ASSUME_SSL=true
```

This tells Rails to:
- Generate `https://` URLs in all responses
- Set the `Secure` flag on session cookies
- Trust `X-Forwarded-Proto` headers from the proxy

Without this, users will see mixed-content warnings and cookie issues.

## Nginx

### Docker Compose with Nginx

Add Nginx as a service alongside Scanner:

```yaml title="docker-compose.yml"
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - scanner

  scanner:
    # ... your scanner service config
    # Remove the ports: section — nginx handles external access
    expose:
      - "80"
```

```nginx title="nginx.conf"
server {
    listen 80;
    server_name scanner.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name scanner.example.com;

    ssl_certificate /etc/letsencrypt/live/scanner.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/scanner.example.com/privkey.pem;

    # WebSocket support (for real-time scan progress)
    location /cable {
        proxy_pass http://scanner:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }

    location / {
        proxy_pass http://scanner:80;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP $remote_addr;

        # Increase timeout for long-running scan requests
        proxy_read_timeout 300s;
    }
}
```

## Caddy

Caddy handles TLS certificate acquisition automatically via Let's Encrypt:

```caddy title="Caddyfile"
scanner.example.com {
    reverse_proxy scanner:80 {
        header_up X-Forwarded-Proto https
    }
}
```

That's it — Caddy handles HTTPS certificates automatically.

### Docker Compose with Caddy

```yaml title="docker-compose.yml"
services:
  caddy:
    image: caddy:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - scanner

  scanner:
    expose:
      - "80"
    # ...

volumes:
  caddy_data:
  caddy_config:
```

## WebSocket Support

Scanner uses WebSockets (via Action Cable) for real-time scan progress updates. Ensure your proxy:

1. Supports WebSocket upgrades (`Upgrade: websocket`, `Connection: upgrade` headers)
2. Routes `/cable` with WebSocket support
3. Has a sufficiently long timeout (WebSocket connections stay open)

Both the Nginx and Caddy examples above include WebSocket support.

## Subdomain WebSocket Setup

If you need to host WebSockets on a different subdomain (e.g., `wss://ws.scanner.example.com/cable`), set these in `.env`:

```bash
ACTION_CABLE_URL=wss://ws.scanner.example.com/cable
SESSION_COOKIE_DOMAIN=.scanner.example.com
```

The `SESSION_COOKIE_DOMAIN` with a leading dot allows cookie sharing across subdomains, which is required for WebSocket authentication.
