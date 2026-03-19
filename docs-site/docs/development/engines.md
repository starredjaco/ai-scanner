---
sidebar_position: 5
---

# Vendored Engines

Custom functionality is added to Scanner via **vendored Rails Engines** — standard Rails Engine gems placed in the `engines/` directory. This pattern lets you extend Scanner without modifying core files, making upgrades straightforward.

## Engine Structure

```
engines/
└── my_engine/
    ├── my_engine.gemspec
    ├── lib/
    │   ├── my_engine.rb           # Engine entry point
    │   └── my_engine/
    │       └── engine.rb          # Rails::Engine subclass
    ├── app/
    │   ├── controllers/
    │   ├── models/
    │   └── views/
    ├── config/
    │   └── initializers/
    └── spec/
```

## Creating an Engine

### 1. Create the Engine Directory

```bash
mkdir -p engines/my_engine/lib/my_engine
mkdir -p engines/my_engine/app/{controllers,models,views}
```

### 2. Create the Gemspec

```ruby title="engines/my_engine/my_engine.gemspec"
Gem::Specification.new do |s|
  s.name        = "my_engine"
  s.version     = "0.1.0"
  s.summary     = "My Scanner extension"
  s.files       = Dir["{app,config,lib}/**/*"]
  s.add_dependency "rails"
end
```

### 3. Create the Engine Class

```ruby title="engines/my_engine/lib/my_engine/engine.rb"
module MyEngine
  class Engine < ::Rails::Engine
    isolate_namespace MyEngine

    initializer "my_engine.configure_scanner" do
      Scanner.configure do |config|
        config.probe_access_class = MyEngine::ProbeAccess
      end

      BrandConfig.configure do |config|
        config.brand_name = "My Company Scanner"
      end

      ProbeSourceRegistry.register(MyEngine::ProbeSource)

      Scanner.register_hook(:after_report_process) do |context|
        MyEngine::ReportExporter.export(context[:report])
      end
    end
  end
end
```

### 4. Create the Entry Point

```ruby title="engines/my_engine/lib/my_engine.rb"
require "my_engine/engine"
```

### 5. Register in Gemfile

```ruby title="Gemfile"
gem "my_engine", path: "engines/my_engine"
```

## Overriding Views

Place view files in your engine's `app/views/` directory with the same path as the core view to override it:

```
engines/my_engine/app/views/
└── layouts/
    └── application.html.erb   # Overrides the main layout
```

Rails loads engine views alongside the main app — engine views take precedence for the paths they define.

## Adding Routes

```ruby title="engines/my_engine/config/routes.rb"
MyEngine::Engine.routes.draw do
  get "/custom-page", to: "custom#index"
end
```

Mount the engine in the main app's routes:

```ruby title="config/routes.rb"
mount MyEngine::Engine, at: "/my-engine"
```

## Adding Migrations

Engine migrations live in the engine's `db/migrate/` directory. Install them:

```bash
rails my_engine:install:migrations
rails db:migrate
```

## Concerns Pattern

Engines can inject behavior into core models and controllers via concerns:

```ruby title="engines/my_engine/app/models/concerns/my_engine/target_extension.rb"
module MyEngine
  module TargetExtension
    extend ActiveSupport::Concern

    included do
      has_many :custom_records, dependent: :destroy
    end
  end
end
```

```ruby title="engines/my_engine/lib/my_engine/engine.rb"
initializer "my_engine.extend_models" do
  ActiveSupport.on_load(:active_record) do
    Target.include MyEngine::TargetExtension
  end
end
```
