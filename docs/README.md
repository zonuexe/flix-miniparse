# Documentation

| Doc | Audience | Contents |
| --- | --- | --- |
| [overview.md](overview.md) | Consumers / newcomers | Module map, minimal snippets, labs table |
| [design-doc.md](design-doc.md) | Contributors | Architecture, roadmap status, package layout |
| [recovery.md](recovery.md) | Learners + practical users | Panic-mode recovery, soft errors, sync tokens |
| [suspend.md](suspend.md) | Learners | CoParser vs Stream, free monad notes, Bridge |

Also useful at the repo root:

| File | Contents |
| --- | --- |
| [../README.md](../README.md) | Quick start, dependency pin, library table |
| [../CHANGELOG.md](../CHANGELOG.md) | Release history (Keep a Changelog) |
| [../bench/README.md](../bench/README.md) | Optional microbench vs flix-parsec |

## Suggested reading order

1. Root README → install and `flix run`
2. **overview** → where each module sits
3. **recovery** → after you have a working `stmt` list (MiniLang)
4. **suspend** → when comparing Stream vs CoParser or reading CoLang
5. **design-doc** → history and why layers were split

## Labs tied to docs

| Lab | Doc hook |
| --- | --- |
| `Examples.RecoverLab` | [recovery.md](recovery.md) |
| `Examples.CostCompare` / `CoLang` | [suspend.md](suspend.md) |
| `Examples.LangCompare` | overview (pure vs CoParser parity) |
