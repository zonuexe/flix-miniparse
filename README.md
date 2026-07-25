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
- **Panic-mode recovery** and unified diagnostics

## Use as a Flix dependency

```toml
# flix.toml
[dependencies]
"github:zonuexe/flix-miniparse" = "0.3.0"
```

Prefer **`MiniParse.*` only**. Modules under `Examples.*` (in this repository’s `test/`) are teaching demos, not a stable API.

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

```text
  MiniParse.Parsec  |  MiniParse.PEG  |  MiniParse.Suspend
           \        |        /                  |
            Combinator + Core              CoParser driver
                     |                          |
         Stream · Recover · Packrat · ErrorFormat
```

## Documentation

| Doc | For |
| --- | --- |
| **[docs/](docs/README.md)** | Guides (overview, recovery, suspend, design) |
| **[CHANGELOG.md](CHANGELOG.md)** | Release history |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | Clone, develop, test, package this repo |

## Exploring the labs (this repository)

The package tour and example grammars live in the **source tree**, not in the published fpkg:

```bash
flix run    # guided tour of Examples.*
flix test
```

| Lab | Idea |
| --- | --- |
| Postal / JSON / Expr | Core → recursion → precedence |
| Keyword / MiniLang / CoLang | `if` vs `ifa`; pure vs suspendable mini language |
| LangCompare | MiniLang vs CoLang AST/run parity |
| RecoverLab / CoRecoverLab | Panic-mode recovery (pure vs Co) |
| Packrat / LeftRec | Memoization; Warth-style growth |
| Stream / Suspend / CostCompare | Restart vs continuation cost |

Tooling setup (Nix, JDK, CI, packaging): see **[CONTRIBUTING.md](CONTRIBUTING.md)**.

## License

Copyright contributors; licensed under the Apache License, Version 2.0. See [`LICENSE.md`](LICENSE.md).
