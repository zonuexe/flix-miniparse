# flix-miniparse

[![Build and Test](https://github.com/zonuexe/flix-miniparse/actions/workflows/build-and-test.yaml/badge.svg)](https://github.com/zonuexe/flix-miniparse/actions/workflows/build-and-test.yaml)

**Educational** parser-combinator library for [Flix](https://flix.dev/).

| | |
| --- | --- |
| **Package** (`flix.toml`) | `miniparse` |
| **Flix** | 0.75.1+ |
| **License** | [Apache-2.0](LICENSE.md) |
| **Status** | Lab / learning project — not production middleware |

Implement combinators from scratch and **compare**:

- **Parsec-style** predictive parsing (explicit `attempt` / try)
- **PEG-style** automatic backtracking (ordered choice, `&` / `!`)
- **Packrat** memoization, **streaming**, and **coroutine** suspension

## Quick start

### Development shell

```bash
nix develop          # or: direnv allow
flix check
flix test
flix run             # guided tour of Examples.*
```

Without Nix: JDK 21+ and [Flix 0.75.1](https://github.com/flix/flix/releases).

### Depend from another Flix project

```toml
# flix.toml
[dependencies]
"github:zonuexe/flix-miniparse" = "0.3.0"
```

Prefer **`MiniParse.*`** only — treat `Examples.*` as sample code.

### Minimal pure parse

```flix
use MiniParse.Core.{parse}
use MiniParse.Combinator.{digit, many, map, charsToString}

def digits(): MiniParse.Core.Parser[String] =
    map(charsToString, many(digit()))

// parse(digits(), "4242")  ==>  Ok("4242")
```

## Library map

| Module | Purpose |
| --- | --- |
| [`MiniParse.Core`](src/MiniParse/Core.flix) | `Parser`, state, errors, `parse` |
| [`MiniParse.Combinator`](src/MiniParse/Combinator.flix) | Shared combinators |
| [`MiniParse.Parsec`](src/MiniParse/Parsec.flix) | Explicit backtracking |
| [`MiniParse.PEG`](src/MiniParse/PEG.flix) | Auto backtrack + predicates |
| [`MiniParse.Packrat`](src/MiniParse/Packrat.flix) | Memo tables (`Region`) |
| [`MiniParse.ErrorFormat`](src/MiniParse/ErrorFormat.flix) | Pretty diagnostics |
| [`MiniParse.Recover`](src/MiniParse/Recover.flix) | Panic-mode recovery (pure) |
| [`MiniParse.RecoverCo`](src/MiniParse/RecoverCo.flix) | Panic-mode recovery (`CoParser`) |
| [`MiniParse.Stream`](src/MiniParse/Stream.flix) | Chunked input (restart `Await`) |
| [`MiniParse.Suspend`](src/MiniParse/Suspend.flix) | `CoParser` + deep `orElse` |
| [`MiniParse.Bridge`](src/MiniParse/Bridge.flix) | `CoParser` ↔ pure `Parser` |

More detail: **[docs/](docs/README.md)** (overview, recovery, suspend, design) · history: **[CHANGELOG.md](CHANGELOG.md)**.

```text
  MiniParse.Parsec  |  MiniParse.PEG  |  MiniParse.Suspend
           \        |        /                  |
            Combinator + Core              CoParser driver
                     |                          |
         Stream · Recover · Packrat · ErrorFormat
```

## Examples (labs)

Modules under `Examples.*` are **teaching demos**, not a stable API:

| Lab | Idea |
| --- | --- |
| Postal / JSON / Expr | Core → recursion → precedence |
| Keyword / MiniLang / CoLang | `if` vs `ifa`; pure vs suspendable mini language |
| LangCompare | MiniLang vs CoLang AST/run parity table |
| RecoverLab / CoRecoverLab | Panic-mode recovery (pure vs Co) |
| Packrat / LeftRec | Memoization; Warth-style growth |
| Stream / Suspend / CostCompare | Restart vs continuation cost |

```bash
flix run    # prints a tour of the labs
```

## Project layout

```text
flix-miniparse/
├── flix.toml              # package manifest (name: miniparse)
├── flake.nix              # reproducible Flix + JDK 21 shell
├── Main.flix              # flix run tour
├── src/
│   └── MiniParse/         # library (published in fpkg)
├── test/
│   ├── Examples/          # labs / demos (not shipped in fpkg)
│   └── Test*.flix         # flix test
├── bench/                 # nested project: vs flix-parsec microbench
├── docs/
│   ├── README.md          # docs index
│   ├── overview.md        # API map for consumers
│   ├── recovery.md        # panic-mode recovery guide
│   ├── suspend.md         # CoParser / Stream notes
│   └── design-doc.md      # architecture & roadmap
├── CHANGELOG.md
├── LICENSE
└── LICENSE.md             # copy for flix build-pkg
```

## Development

| Command | Purpose |
| --- | --- |
| `nix develop` | Enter shell with `flix` and JDK 21 |
| `flix check` | Type-check |
| `flix test` | Run unit tests |
| `flix run` | Demo tour |
| `flix build-pkg` | Build `artifact/flix-miniparse.fpkg` (library only) |
| `bash scripts/check-fpkg.sh` | Guard fpkg has no `Main` / `Examples` |
| `bash bench/scripts/install-local-deps.sh` then `cd bench && JAVA_OPTS=-Xss8m flix run` | Microbench vs sibling `flix-parsec` (see [bench/README.md](bench/README.md)) |

CI: [`.github/workflows/build-and-test.yaml`](.github/workflows/build-and-test.yaml) (JDK 21, Flix from `flix.toml`).

## License

Copyright contributors; licensed under the Apache License, Version 2.0. See [`LICENSE.md`](LICENSE.md) file.
