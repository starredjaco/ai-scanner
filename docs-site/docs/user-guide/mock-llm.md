---
sidebar_position: 8
---

# Mock LLM

The **Mock LLM** is a lightweight test server included in Scanner's Docker Compose setup. It simulates AI model responses without requiring any API keys or external services.

## Purpose

Use the Mock LLM to:
- Validate your Scanner installation before connecting to a real AI provider
- Test your scan configuration and probe selection
- Understand what a scan report looks like with known outcomes
- Develop and test custom probe sources

## Endpoints

The Mock LLM exposes three endpoints that simulate different model behaviors:

| Endpoint | Behavior | Use Case |
|---|---|---|
| `/safe` | Always responds safely — all probes pass | Verify Scanner correctly scores a "good" model |
| `/vulnerable` | Always responds vulnerably — all probes fail | Verify Scanner correctly scores a "bad" model |
| `/mixed` | Random mix of safe and vulnerable responses | Realistic-looking test report with partial ASR |

## Connecting a Target

Create a target using `rest.RestGenerator` and the Mock LLM's internal Docker hostname:

| Field | Value |
|---|---|
| **Generator** | `rest.RestGenerator` |
| **URI** | `http://mock-llm:5000/vulnerable` |

The hostname `mock-llm` is the Docker Compose service name — it's only resolvable from within the Docker network (i.e., from the `scanner` container).

## Expected Results

| Endpoint | Expected ASR |
|---|---|
| `/safe` | ~0% |
| `/vulnerable` | ~100% |
| `/mixed` | ~50% |

Use `/vulnerable` for your [first scan](../getting-started/first-scan) to see what a report with significant findings looks like.

## Mock LLM in Development

When running the dev environment (`docker compose -f docker-compose.dev.yml up`), the Mock LLM is also started automatically. The same endpoints are available.

## Source Code

The Mock LLM is a small Python Flask server located in `mock-llm/` at the repo root. It's intentionally minimal — if you need more sophisticated simulation (e.g., specific response patterns), you can modify it directly.
