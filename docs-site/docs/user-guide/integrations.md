---
sidebar_position: 7
---

# Integrations

Scanner can forward scan results to external log management and SIEM systems when a scan completes.

## Supported Integrations

| Type | Description |
|---|---|
| **Splunk** | Sends structured JSON events via HTTP Event Collector (HEC) |
| **Rsyslog** | Forwards logs in **RFC 3164 (BSD syslog)** format via UDP, TCP, TLS, or HTTP |

## Setting Up an Integration

1. Log in to Scanner
2. Navigate to **Configuration → Integrations**
3. Click **New Integration**
4. Fill in the configuration fields (see below for each type)
5. Click **Create Output Server**
6. Click **Test Integration** to verify connectivity

To use an integration in a scan:
1. Navigate to **Scans → New Scan**
2. Select your integration from the **Output Server** dropdown
3. When the scan completes, results are automatically forwarded

---

## Splunk

### Configuration

| Field | Description |
|---|---|
| **Name** | Display name (e.g., "Production Splunk") |
| **Server Type** | `Splunk` |
| **Host** | Splunk server hostname or IP |
| **Port** | `8088` (Splunk HEC default) |
| **Protocol** | `https` (recommended) |

### Authentication

Use **Token Authentication** with your Splunk HEC token:

1. In Splunk Web: **Settings → Data Inputs → HTTP Event Collector**
2. Create or copy your HEC token (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
3. Paste it in the **Access Token** field

### Data Format

Scanner sends structured JSON events to Splunk:

```json
{
  "event": {
    "report_id": "abc-123",
    "scan_name": "Weekly GPT-4 Scan",
    "target": "production-gpt4",
    "status": "completed",
    "asr": 12.5,
    "probes_run": 45,
    "timestamp": "2026-03-18T14:30:00Z"
  }
}
```

---

## Rsyslog

### Wire Format: RFC 3164

:::important RFC 3164 (BSD Syslog)
Scanner sends syslog messages in **RFC 3164 (BSD syslog)** format — not RFC 5424.

Configure your syslog receiver accordingly. RFC 5424 receivers may parse these messages incorrectly.
:::

#### Message Structure

```
<PRI>TIMESTAMP HOSTNAME TAG: CONTENT
```

| Field | Value |
|---|---|
| **PRI** | `<134>` (facility=`local0` / 16, severity=`info` / 6) |
| **Timestamp** | `%b %d %H:%M:%S` — e.g., `Mar 18 14:30:00` (no year, no timezone, per RFC 3164) |
| **Hostname** | Derived from `BrandConfig.host_url`, or `scanner.local` if not set |
| **Tag** | `scanner_app` |
| **Content** | JSON payload (scan report data) |

#### Example Raw Message

```
<134>Mar 18 14:30:00 scanner.local scanner_app: {"report_id":"abc-123","scan_name":"Weekly GPT-4 Scan","asr":12.5}
```

#### Rsyslog Receiver Configuration Example

For a TCP receiver on your rsyslog server (`/etc/rsyslog.conf`):

```
# Load TCP input module
module(load="imtcp")
input(type="imtcp" port="514")

# Route scanner messages to a dedicated file
if $programname == 'scanner_app' then /var/log/scanner.log
```

For UDP:

```
module(load="imudp")
input(type="imudp" port="514")
```

### Scanner Configuration

| Field | Description |
|---|---|
| **Name** | Display name (e.g., "Central Syslog") |
| **Server Type** | `Rsyslog` |
| **Host** | Rsyslog server hostname or IP |
| **Protocol** | `udp`, `tcp`, `tls`, or `http`/`https` |

#### Port Defaults by Protocol

| Protocol | Default Port |
|---|---|
| UDP | 514 |
| TCP | 514 |
| TLS | 6514 |
| HTTP | 80 |
| HTTPS | 443 |

### TLS Configuration

When using the `tls` protocol, provide certificate paths in **Additional Settings** (JSON):

```json
{
  "tls_cert_file": "/storage/certs/client.pem",
  "tls_key_file": "/storage/certs/client.key",
  "ca_file": "/storage/certs/ca.pem"
}
```

Mount your certificates into the Scanner container via Docker volumes.

### HTTP/HTTPS Authentication

For HTTP/HTTPS transport, Scanner supports:

- **API Key** — sent as `X-API-Key` header
- **Basic Auth** — username and password (use HTTPS only)
- **No authentication** — for internal/trusted networks

---

## Testing Connectivity

Click **Test Integration** from the integration detail page to send a test message. For Rsyslog, the test message uses the same RFC 3164 format as production messages.

If the test succeeds, you'll see a confirmation. If it fails, check:
- Host and port are correct and reachable from the Scanner container
- Firewall rules allow the connection
- Protocol matches your server's input module
- For TLS: certificates are valid and accessible

## Data Forwarded

Each integration event contains:

- Report ID and UUID
- Scan name and target
- Execution timestamps
- Overall ASR score and status
- Per-probe vulnerability findings
- Statistics (attempts, pass/fail ratios)
