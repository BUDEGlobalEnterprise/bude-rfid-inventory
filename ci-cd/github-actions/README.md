# GitHub Actions

Live workflow files live in [`/.github/workflows/`](../../.github/workflows/) at the repo root — GitHub only discovers workflows from that path.

| Workflow | File | Trigger |
|---|---|---|
| Flutter CI | `flutter-ci.yml` | Push/PR touching `mobile-app/**` |
| Backend CI | `backend-ci.yml` | Push/PR touching `backend/**` |

When adding a new workflow, place it in `.github/workflows/` and add a row to the table above.
