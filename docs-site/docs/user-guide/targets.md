---
sidebar_position: 2
---

# Targets

A **target** represents an AI system you want to test. Scanner supports API-based models and browser-based chat UIs.

## Creating a Target

1. Navigate to **Targets** in the sidebar
2. Click **New Target**
3. Fill in the target configuration (see below)
4. Click **Create Target**

## Target Configuration Fields

| Field | Required | Description |
|---|---|---|
| **Name** | Yes | Display name for this target |
| **Generator** | Yes | The garak generator class (e.g., `rest.RestGenerator`) |
| **URI** | Varies | Model endpoint URL or model identifier |
| **JSON Config** | No | Additional generator options as JSON |

## Common Target Templates

### OpenAI (GPT models)

| Field | Value |
|---|---|
| Generator | `openai.OpenAIGenerator` |
| URI | `gpt-4o` (or any OpenAI model ID) |

Set `OPENAI_API_KEY` as a target-specific environment variable (see [Environment Variables](./environment-variables)).

### OpenRouter

| Field | Value |
|---|---|
| Generator | `openai.OpenAIGenerator` |
| URI | `openai/gpt-4o` |
| JSON Config | `{"api_base": "https://openrouter.ai/api/v1"}` |

Set `OPENROUTER_API_KEY`.

### Anthropic (Claude via LiteLLM)

| Field | Value |
|---|---|
| Generator | `litellm.LiteLLMGenerator` |
| URI | `claude-3-5-sonnet-20241022` |

Set `ANTHROPIC_API_KEY`.

### Azure OpenAI

| Field | Value |
|---|---|
| Generator | `azure.AzureOpenAIGenerator` |
| URI | Your deployment name |
| JSON Config | `{"api_base": "https://YOUR_RESOURCE.openai.azure.com/"}` |

Set `AZURE_API_KEY`.

### Ollama (Local Models)

| Field | Value |
|---|---|
| Generator | `ollama.OllamaGenerator` |
| URI | `llama3.2` (or any Ollama model name) |

No API key needed. Ollama must be accessible from within the Docker network. If running Ollama on your host machine, use `http://host.docker.internal:11434` as the base URL in your JSON config.

### Hugging Face Inference API

| Field | Value |
|---|---|
| Generator | `huggingface.HFInferenceAPIGenerator` |
| URI | `mistralai/Mixtral-8x7B-Instruct-v0.1` |

Set `HF_TOKEN`.

### Generic REST API

For any OpenAI-compatible HTTP endpoint:

| Field | Value |
|---|---|
| Generator | `rest.RestGenerator` |
| URI | `http://your-api-host/v1/chat/completions` |

### Mock LLM (Testing)

| Field | Value |
|---|---|
| Generator | `rest.RestGenerator` |
| URI | `http://mock-llm:5000/vulnerable` |

The Mock LLM ships with the Docker Compose setup and requires no API keys. See [Mock LLM](./mock-llm) for details on all available endpoints.

## Per-Target API Keys

Each target can have its own set of environment variables (API keys) that override any global variables with the same name. This lets you:

- Use different API keys per target
- Isolate credentials for different environments
- Test the same model with different authentication contexts

To set a per-target API key:

1. Open the target's detail page
2. Scroll to **Environment Variables**
3. Click **Add Variable**
4. Set the variable name (e.g., `OPENAI_API_KEY`) and value

See [Environment Variables](./environment-variables) for the full list of supported variable names.

## Webchat Targets

Webchat targets use Playwright browser automation to interact with chat UIs that don't expose a direct API.

:::info
Webchat scanning requires additional Playwright setup. This feature is marked **experimental** in the current release.
:::

## Managing Targets

- **Edit**: Click a target name to view and edit its configuration
- **Delete**: Remove a target from the target detail page
- **Test connection**: Not yet available — run a scan against the Mock LLM first to validate your setup

:::note
Target configurations (including JSON config) are **encrypted at rest** using per-tenant encryption keys derived from `SECRET_KEY_BASE`.
:::
