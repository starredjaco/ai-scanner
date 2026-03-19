---
sidebar_position: 5
---

# Probes

## Community Probes

Scanner ships with **179 community probes** across **35 vulnerability families**, sourced from [NVIDIA garak's](https://github.com/NVIDIA/garak) community probe library. These probes are bundled into the container image at build time and synced into the database on first boot.

## How Probes Are Synced

The `SyncProbesJob` background job reads probe definitions from `ProbeSourceRegistry` and upserts them into the database. On first boot, this runs automatically as part of startup.

The community probe data is bundled from garak's published JSON at container build time:

```
/rails/config/probes/community_probes.json
```

## Adding Custom Probe Sources

You can register additional probe sources via `ProbeSourceRegistry`. This is the mechanism used by [vendored engines](../development/engines) to supply additional probes.

```ruby
# In your engine's initializer
ProbeSourceRegistry.register(MyCustomProbeSource)
```

Your source class must implement `.sync_probes`:

```ruby
class MyCustomProbeSource
  def self.sync_probes
    # Read probe definitions from your source
    # Create or update Probe records
    [
      { name: "my_probe.CustomProbe", description: "...", family: "custom" },
    ].each do |probe_data|
      Probe.find_or_create_by(name: probe_data[:name])
           .update!(probe_data)
    end
  end
end
```

See [Extension Points → ProbeSourceRegistry](../development/extension-points#probesourceregistry) for the full API.

## OWASP LLM Top 10 Alignment

Scanner's community probe families map to the [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/). When reviewing scan results, you can use these mappings to prioritize remediation by risk category.

## Probe Updates

Community probes are updated when you rebuild the container image. Pull the latest image (or rebuild from source) to get new probes added to garak's community library.

```bash
# Option A: pre-built image
docker compose pull scanner
docker compose up -d

# Option B: built from source
git pull
docker compose build scanner
docker compose up -d
```

After updating, run `SyncProbesJob` to update the database with any new probes:

```bash
docker compose exec scanner rails runner "SyncProbesJob.perform_now"
```

Or restart the application — the sync runs automatically on boot.
