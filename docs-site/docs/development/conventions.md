---
sidebar_position: 7
---

# Conventions

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>`

### Types

| Type | Triggers Release? | When to Use |
|---|---|---|
| `feat` | Yes (minor) | New feature |
| `fix` | Yes (patch) | Bug fix |
| `security` | Yes (patch) | Security fix |
| `perf` | Yes (patch) | Performance improvement |
| `docs` | No | Documentation only |
| `refactor` | No | Code restructuring without behavior change |
| `test` | No | Adding or fixing tests |
| `style` | No | Formatting, whitespace |
| `chore` | No | Maintenance tasks |
| `ci` | No | CI/CD changes |

### Scope

Use the issue key if available (e.g., `feat(SCAN-123): add probe filtering`), otherwise the component name (e.g., `fix(reports): correct scan count`).

### Breaking Changes

Add `BREAKING CHANGE:` to the commit footer for changes that require migration steps:

```
feat(targets): restructure JSON config format

BREAKING CHANGE: target.json_config now uses snake_case keys.
Run `rails db:migrate` and update any custom targets.
```

### Examples

```
feat(probes): add community probe filtering
fix(reports): correct scan count in summary
docs: update quick start guide
chore(deps): bump rails to 8.1
test(scans): add scheduled scan job specs
```

## Branch Naming

| Pattern | When to Use |
|---|---|
| `feature/short-description` | New feature |
| `fix/short-description` | Bug fix |
| `chore/short-description` | Maintenance |
| `docs/short-description` | Documentation |
| `hotfix/short-description` | Urgent production fix |

Examples: `feature/add-json-validator`, `fix/escape-file-paths-mac`, `docs/docusaurus-site`

## Code Style

### Ruby

RuboCop is the enforcer. Run before committing:

```bash
bundle exec rubocop -A  # auto-fix
bundle exec rubocop      # check only
```

Key style decisions:
- 2-space indentation
- Single quotes for strings (unless interpolation needed)
- Frozen string literals enabled

### Views

- Use **semantic class names** in views, not raw Tailwind utilities directly
- Define reusable styles in `application.css` using `@apply`
- Icons use **heroicons** only — defined in `icons.css`, not inline SVGs

```erb
<%# Good %>
<button class="btn-primary">Run Scan</button>

<%# Avoid %>
<button class="bg-blue-600 hover:bg-blue-700 text-white font-medium px-4 py-2 rounded">Run Scan</button>
```

### JavaScript / Stimulus

- Chart configurations go in `app/javascript/config/chartConfig.js`
- Use shared config functions (e.g., `getGaugeChartConfig()`) — no duplicate chart code
- ASR color scale must match between `scores_helper.rb` and `chartConfig.js`

## Security Conventions

- **Never commit secrets** — use environment variables
- **Always `Shellwords.escape`** for shell interpolation
- **Encrypted fields** must be accessed within a tenant scope:
  ```ruby
  ActsAsTenant.with_tenant(company) { target.json_config }
  ```
- **Don't use `.pluck`** on encrypted fields — use `.select(:field).map(&:field)` instead
- **Non-deterministic encryption** means `saved_change_to_<encrypted_field>?` always returns `true` — compare decrypted values instead

## Database Conventions

- Keep migrations small and reversible
- Add a comment explaining non-obvious migrations
- Partial indexes are preferred for scoped queries (see `add_partial_index_for_active_reports`)
- Background jobs must explicitly scope tenant context with `ActsAsTenant.with_tenant`

## Pull Requests

- PR title must follow Conventional Commits format (enforced by CI)
- Keep PRs focused — ideally under ~300 lines of diff
- Target `main` branch
- Two approvals required for changes touching core services, background jobs, migrations, or security-sensitive code
