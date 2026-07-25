# Documentation

| Doc | Audience | Contents |
| --- | --- | --- |
| [tutorial.md](tutorial.md) | Beginners | Combinators intro; Parsec vs PEG walkthrough |
| [overview.md](overview.md) | Consumers / newcomers | Module map, minimal snippets, labs table |
| [design-doc.md](design-doc.md) | Contributors | Architecture, roadmap status, package layout |
| [recovery.md](recovery.md) | Learners + practical users | Panic-mode recovery, soft errors, sync tokens |
| [debug.md](debug.md) | Learners | `label` / `TParser` tracing without monad transformers |
| [suspend.md](suspend.md) | Learners | CoParser vs Stream, free monad notes, Bridge |
| [**ja/**](ja/README.md) | 日本語 | Full set of the above (`tutorial`, `overview`, `recovery`, `debug`, `suspend`, `design-doc`) |

Also useful at the repo root:

| File | Contents |
| --- | --- |
| [../README.md](../README.md) | Depend on the package, library map (consumers) |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Nix shell, `flix test` / `build-pkg`, layout (contributors) |
| [../CHANGELOG.md](../CHANGELOG.md) | Release history (Keep a Changelog) |
| [../bench/README.md](../bench/README.md) | Optional microbench vs flix-parsec |

## Suggested reading order

1. Root README → depend on `miniparse` and skim Parsec vs PEG
2. **tutorial** → first hands-on path (combinators, choice policies)
3. **overview** → full module map
4. **recovery** → after you have a working `stmt` list (MiniLang)
5. **debug** → when errors are opaque or you need an enter/exit rule trail
6. **suspend** → when comparing Stream vs CoParser or reading CoLang
7. **design-doc** → history and why layers were split
8. **CONTRIBUTING** → only if you clone this repo to hack on it

## Labs tied to docs

| Lab | Doc hook |
| --- | --- |
| `Examples.RecoverLab` | [recovery.md](recovery.md) |
| `Examples.DebugLab` | [debug.md](debug.md) |
| `Examples.CostCompare` / `CoLang` | [suspend.md](suspend.md) |
| `Examples.LangCompare` | overview (pure vs CoParser parity) |
