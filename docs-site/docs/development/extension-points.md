---
sidebar_position: 4
---

# Extension Points

Scanner is designed as an extensible base application. All features work out of the box. Organizations can add custom functionality via three extension points — without modifying core code.

Extensions are typically packaged as [vendored Rails Engines](./engines).

## Scanner.configure

The main configuration DSL, defined in `lib/scanner/configuration.rb`.

```ruby
Scanner.configure do |config|
  # Swap the probe access class
  config.probe_access_class = MyCustomProbeAccess

  # Swap the retention strategy
  config.retention_strategy_class = MyRetentionStrategy

  # Register OAuth providers
  config.auth_providers = [:google_oauth2, :github]

  # Enable portal export
  config.portal_export_enabled = true

  # Set a custom validation probe
  config.validation_probe = "my_probes.ValidationProbe"
end
```

### Configuration Options

| Option | Type | Description |
|---|---|---|
| `probe_access_class` | Class | Controls which probes are accessible. Default allows all community probes. |
| `retention_strategy_class` | Class | Determines report retention logic. Default uses `RETENTION_DAYS`. |
| `auth_providers` | Array | OAuth provider symbols (e.g., `:google_oauth2`). |
| `portal_export_enabled` | Boolean | Enables export to an external portal. |
| `validation_probe` | String | Probe name used for target validation. |

### Lifecycle Hooks

Register hooks to run at specific points in the scan lifecycle:

```ruby
Scanner.register_hook(:after_report_process) do |context|
  # context contains: report, company, scan
  MyNotificationService.notify(context[:report])
end
```

Run hooks from your own code:

```ruby
Scanner.run_hooks(:after_report_process, { report: @report, company: current_company })
```

Available hook events:
- `:after_report_process` — after a scan report is processed and saved

## BrandConfig.configure

Customize branding and white-labeling, defined in `lib/brand_config.rb`.

```ruby
BrandConfig.configure do |config|
  config.brand_name   = "Acme AI Scanner"
  config.logo_path    = "acme_logo.svg"
  config.font_family  = "Inter, sans-serif"
  config.powered_by   = "Powered by Scanner"
  config.host_url     = "https://scanner.acme.com"
end
```

### Configuration Options

| Option | Type | Description |
|---|---|---|
| `brand_name` | String | Displayed in the navbar and page titles |
| `logo_path` | String | Asset path to your logo file |
| `font_family` | String | CSS font-family for the UI |
| `powered_by` | String | Footer attribution text |
| `host_url` | String | Canonical host URL (used in syslog messages and links) |

## ProbeSourceRegistry

Register additional probe data sources for `SyncProbesJob`, defined in `app/services/probe_source_registry.rb`.

```ruby
ProbeSourceRegistry.register(MyCustomProbeSource)
```

### Implementing a Probe Source

```ruby
class MyCustomProbeSource
  def self.sync_probes
    probe_definitions.each do |probe_data|
      probe = Probe.find_or_initialize_by(name: probe_data[:name])
      probe.update!(
        description: probe_data[:description],
        family:      probe_data[:family],
        tags:        probe_data[:tags] || []
      )
    end
  end

  def self.probe_definitions
    [
      {
        name:        "my_probes.CustomJailbreak",
        description: "Tests for custom jailbreak patterns",
        family:      "jailbreak",
        tags:        ["custom", "jailbreak"]
      }
    ]
  end
end
```

`SyncProbesJob` calls `.sync_probes` on every registered source when it runs. The job runs automatically on boot and can be triggered manually:

```bash
docker compose exec scanner rails runner "SyncProbesJob.perform_now"
```

### Listing Registered Sources

```ruby
ProbeSourceRegistry.sources
# => [GarakCommunityProbeSource, MyCustomProbeSource]
```
