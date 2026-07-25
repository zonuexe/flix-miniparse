# flix-miniparse

[![Build and Test](https://github.com/zonuexe/flix-miniparse/actions/workflows/build-and-test.yaml/badge.svg)](https://github.com/zonuexe/flix-miniparse/actions/workflows/build-and-test.yaml)

**Educational** parser-combinator library for [Flix](https://flix.dev/).

| | |
| --- | --- |
| **Package** (`flix.toml`) | `miniparse` |
| **Flix** | 0.75.1+ |
| **License** | [Apache-2.0](LICENSE.md) |
| **Status** | Lab / learning project — not production middleware |

Parser combinators are small functions you compose into a grammar. This library
implements that idea from scratch in Flix so you can **see the machinery** and
**compare designs**, not only call a black-box API.

## Two styles: Parsec and PEG

miniparse ships **both** of the common combinator philosophies side by side on
one shared engine (`Core` + `Combinator`):

| Style | Module | Backtracking in a nutshell |
| --- | --- | --- |
| **[Parsec](https://en.wikipedia.org/wiki/Parsec_(parser))** | `MiniParse.Parsec` | Predictive / LL(1)-like. After a branch **consumes** input, failure does **not** automatically try the next alternative. You opt in with `attempt` (Parsec’s `try`). |
| **[PEG](https://en.wikipedia.org/wiki/Parsing_expression_grammar)** | `MiniParse.PEG` | Ordered choice (`/`) **rewinds** a failed alternative for you. Also has lookahead predicates (`&` / `!`). |

Same grammar, different failure rules — that contrast is the point of the lab.
Beyond the two fronts, the package also explores packrat memoization, streaming
input, coroutine-style suspension, and panic-mode error recovery.

Step-by-step walkthrough: **[docs/tutorial.md](docs/tutorial.md)** · 日本語: **[docs/ja/tutorial.md](docs/ja/tutorial.md)**.

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
