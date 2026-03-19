# Monitoring Adapters

This directory contains the monitoring abstraction layer that allows Scanner to support multiple monitoring providers without changing application code.

## Architecture

```
MonitoringService (app/services/monitoring_service.rb)
    ↓
Adapter (base class)
    ↓
├── NullAdapter (default, no-op)
└── CustomAdapter (implement your own)
```

## Files

- **`adapter.rb`** - Abstract base class defining the monitoring contract
- **`null_adapter.rb`** - No-op implementation (default)
- **`README.md`** - This file

## Adapter Interface

All adapters must implement these methods:

### `transaction(name, type, &block)`
Wrap a block of code in a transaction/span for tracing.

**Parameters:**
- `name` (String) - Name of the transaction
- `type` (String) - Type of transaction ("background", "custom", "request")
- `block` (Block) - Code to execute within transaction context

**Returns:** Result of the block

### `set_label(key, value)`
Set a label/tag on the current transaction. Labels are indexed metadata that can be queried and aggregated.

**Parameters:**
- `key` (Symbol, String) - Label key
- `value` (Object) - Label value (converted to string)

### `set_labels(labels)`
Set multiple labels at once.

**Parameters:**
- `labels` (Hash) - Hash of label key-value pairs

**Default implementation:** Calls `set_label` for each pair

### `current_trace_id`
Get the current trace ID for distributed tracing and log correlation.

**Returns:** (String, nil) The trace ID, or nil if no active transaction

### `trace_context`
Get trace context for propagating to child processes (e.g., Python subprocess).

**Returns:** (Hash) Hash containing trace context as environment variables
- Keys are env var names for trace propagation
- Values are the trace context values

### `active?`
Check if monitoring is currently active.

**Returns:** (Boolean) true if monitoring is enabled and running

### `service_name`
Get the service name for this monitoring instance.

**Returns:** (String) The service name

## Creating a New Adapter

1. **Create adapter file** in this directory:

```ruby
# app/services/monitoring/my_provider_adapter.rb
module Monitoring
  class MyProviderAdapter < Adapter
    def initialize
      @enabled = ENV["MY_PROVIDER_ENABLED"] == "true"
      @service_name = ENV.fetch("MY_PROVIDER_SERVICE_NAME", "scanner")
    end

    def transaction(name, type)
      return yield unless @enabled

      MyProvider.start_transaction(name, type: type) do
        yield
      end
    end

    def set_label(key, value)
      return unless @enabled
      MyProvider.set_tag(key, value)
    end

    def current_trace_id
      return nil unless @enabled
      MyProvider.current_trace&.id
    end

    def trace_context
      return {} unless @enabled

      {
        "MY_PROVIDER_TRACE_ID" => MyProvider.current_trace.id,
        "MY_PROVIDER_SPAN_ID" => MyProvider.current_span.id
      }
    end

    def active?
      @enabled && MyProvider.running?
    end

    def service_name
      @service_name
    end
  end
end
```

2. **Register adapter** in `MonitoringService.create_adapter`:

```ruby
case provider
when :my_provider
  require_relative "monitoring/my_provider_adapter"
  Monitoring::MyProviderAdapter.new
else
  require_relative "monitoring/null_adapter"
  Monitoring::NullAdapter.new
end
```

3. **Update provider detection** in `MonitoringService.determine_provider`:

```ruby
if ENV["MY_PROVIDER_ENABLED"] == "true"
  return :my_provider
end
```

4. **Test the adapter:**

```ruby
# In console or test
ENV["MY_PROVIDER_ENABLED"] = "true"
MonitoringService.reset! # Clear cached adapter

MonitoringService.transaction("test", "background") do
  MonitoringService.set_label(:test, "value")
  puts MonitoringService.current_trace_id
end
```

## Usage Examples

### Basic Transaction

```ruby
MonitoringService.transaction("user_login", "request") do
  # Your code here
  user = User.authenticate(params)

  MonitoringService.set_label(:user_id, user.id)
  MonitoringService.set_label(:login_method, "password")
end
```

### Conditional Monitoring

```ruby
def process_data
  # Only wrap in transaction if monitoring is active
  if MonitoringService.active?
    MonitoringService.transaction("process_data", "background") do
      expensive_operation
    end
  else
    expensive_operation
  end
end
```

### Distributed Tracing to Child Process

```ruby
# In parent process (Ruby)
MonitoringService.transaction("parent_operation", "background") do
  trace_context = MonitoringService.trace_context

  # Pass trace context as environment variables
  env_vars = trace_context.map { |k, v| "#{k}=#{v}" }.join(" ")
  system("#{env_vars} python script.py")
end

# In child process (Python)
import os
trace_id = os.environ.get("TRACE_ID")
# Use trace_id to continue the trace
```

## Testing

```ruby
# Mock the service in tests
allow(MonitoringService).to receive(:transaction).and_yield
allow(MonitoringService).to receive(:set_label)
```

## See Also

- [monitoring_service.rb](../monitoring_service.rb) - Service facade implementation
