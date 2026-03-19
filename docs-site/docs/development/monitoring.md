---
sidebar_position: 6
---

# Monitoring Integration

Scanner includes a monitoring abstraction layer that allows APM (Application Performance Monitoring) integration without changing application code.

## Architecture

```
MonitoringService (facade)
    ↓
Adapter (base class)
    ├── NullAdapter (default, no-op)
    └── CustomAdapter (implement your own)
```

The default `NullAdapter` does nothing — monitoring is opt-in.

## Using MonitoringService

```ruby
# Wrap code in a transaction/span
MonitoringService.transaction("scan_execution", "background") do
  run_garak_scan
  MonitoringService.set_label(:scan_id, scan.id)
  MonitoringService.set_label(:target, scan.target.name)
end

# Set labels on the current transaction
MonitoringService.set_label(:user_id, current_user.id)
MonitoringService.set_labels(environment: "production", version: "1.2.3")

# Get the current trace ID (for log correlation)
trace_id = MonitoringService.current_trace_id

# Check if monitoring is active
if MonitoringService.active?
  # monitoring-specific code
end
```

## Adapter Interface

All adapters must implement:

### `transaction(name, type, &block)`

Wrap a block of code in a monitoring span.

- `name` — transaction name (e.g., `"scan_execution"`)
- `type` — transaction type: `"background"`, `"custom"`, `"request"`
- Returns the result of the block

### `set_label(key, value)`

Set a label/tag on the current transaction. Labels are indexed metadata.

### `set_labels(labels)`

Set multiple labels at once from a hash. Default implementation calls `set_label` for each pair.

### `current_trace_id`

Returns the current trace ID string, or `nil` if no active transaction.

### `trace_context`

Returns a hash of environment variables for propagating trace context to child processes.

### `active?`

Returns `true` if monitoring is enabled and running.

### `service_name`

Returns the service name string.

## Creating a Custom Adapter

```ruby title="app/services/monitoring/my_apm_adapter.rb"
module Monitoring
  class MyApmAdapter < Adapter
    def initialize
      @enabled = ENV["MY_APM_ENABLED"] == "true"
      @service_name = ENV.fetch("MY_APM_SERVICE_NAME", "scanner")
    end

    def transaction(name, type)
      return yield unless @enabled
      MyApm.start_transaction(name, type: type) { yield }
    end

    def set_label(key, value)
      return unless @enabled
      MyApm.set_tag(key.to_s, value.to_s)
    end

    def current_trace_id
      return nil unless @enabled
      MyApm.current_transaction&.trace_id
    end

    def trace_context
      return {} unless @enabled
      { "MY_APM_TRACE_ID" => MyApm.current_transaction.trace_id }
    end

    def active?
      @enabled
    end

    def service_name
      @service_name
    end
  end
end
```

Register it in `MonitoringService.create_adapter`:

```ruby title="app/services/monitoring_service.rb"
def self.create_adapter
  case determine_provider
  when :my_apm
    require_relative "monitoring/my_apm_adapter"
    Monitoring::MyApmAdapter.new
  else
    require_relative "monitoring/null_adapter"
    Monitoring::NullAdapter.new
  end
end

def self.determine_provider
  return :my_apm if ENV["MY_APM_ENABLED"] == "true"
  :null
end
```

## Distributed Tracing to garak

Scanner passes trace context to the garak subprocess so traces span both the Ruby and Python processes:

```ruby
MonitoringService.transaction("garak_scan", "background") do
  trace_context = MonitoringService.trace_context
  # trace_context is passed to garak as environment variables
  run_garak_with_env(trace_context)
end
```

## Testing

```ruby
# In RSpec: mock the service
allow(MonitoringService).to receive(:transaction).and_yield
allow(MonitoringService).to receive(:set_label)
allow(MonitoringService).to receive(:current_trace_id).and_return("test-trace-id")
```
