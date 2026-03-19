---

## PR Title Format

**IMPORTANT**: Your PR title must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>
```

### Examples:
- `feat(probes): add new security probe`
- `fix(reports): correct scan count calculation`
- `docs(readme): update installation steps`
- `chore(deps): update gem dependencies`

### Breaking Change Examples:
- `feat(api)!: remove deprecated endpoints`
- `fix(auth)!: change authentication flow`
- `breaking(database): migrate to new schema`

### Commit Types Reference

| Type | Release | Description |
|------|---------|-------------|
| `breaking` | **Major** | Incompatible API or behavior changes |
| `feat` | **Minor** | New features or capabilities |
| `fix` | **Patch** | Bug fixes |
| `security` | **Patch** | Security-related fixes |
| `perf` | **Patch** | Performance improvements |
| `revert` | **Patch** | Reverts a previous commit |
| `chore(deps)` | **Patch** | Dependency updates (scope must be `deps`) |
| `refactor` | None | Code restructuring without behavior change |
| `docs` | None | Documentation only |
| `test` | None | Adding or fixing tests |
| `ci` | None | CI/CD configuration |
| `style` | None | Code style/formatting |
| `chore` | None | Maintenance tasks (without `deps` scope) |

**Note**: Breaking changes trigger a **major** version bump. Indicate them by either:
- Adding `!` after the type/scope: `feat!:` or `fix(scope)!:`
- Using the `breaking` type: `breaking:`
- Adding `BREAKING CHANGE:` in the commit footer
