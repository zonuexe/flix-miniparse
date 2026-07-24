# miniparse overview

Short map of the **library** (`MiniParse.*`) versus **labs** (`Examples.*`).

Repository: [zonuexe/flix-miniparse](https://github.com/zonuexe/flix-miniparse)  
Package name (`flix.toml`): `miniparse`  
License: Apache-2.0

## What this is

An educational implementation of parser combinators in [Flix](https://flix.dev/):

- learn the **difference** between Parsec-style predictive parsing and PEG-style automatic backtracking
- see **packrat** memoization, **streaming**, and **coroutine suspension** as separate layers
- run small end-to-end grammars (JSON, arithmetic, a tiny language)

It is **not** a production-ready replacement for industrial parser generators.

## Library modules

```text
MiniParse
├── Core          Parser[a], State, Position, ParseError
├── Combinator    map, flatMap, satisfy, many, sepBy, chainl1, …
├── Parsec        orElse (no auto-rewind), attempt
├── PEG           choice, andPredicate, notPredicate
├── Packrat       Table / Cell / newTable (Region + MutMap)
├── ErrorFormat   formatError (line + caret)
├── Stream        feed / close / step → Done | Fail | Await  (restart)
└── Suspend       CoParser free monad, deep orElse, Peek/keyword
```

### Typical pure pipeline

```flix
use MiniParse.Core.{parse}
use MiniParse.Combinator.{char, many, map}
use MiniParse.Parsec.{orElse}

def digits(): MiniParse.Core.Parser[String] =
    map(MiniParse.Combinator.charsToString, many(MiniParse.Combinator.digit()))

// parse(digits(), "12345")
```

### Streaming (restart-style)

```flix
use MiniParse.Stream.{open, feed, close, step, parseChunks}
// parseChunks(parser, "ab" :: "c" :: Nil)
```

### Suspendable (continuation-style)

```flix
use MiniParse.Suspend.{string, orElse, parseChunks, keyword, ident}
// orElse(keyword("if"), ident)  — deep rewind on failure
```

## Labs (`Examples.*`)

| Module | Topic |
| --- | --- |
| `PostalCode` | Linear core smoke test |
| `Json` | Recursion, whitespace, escapes |
| `Expr` / `Keyword` | Precedence; Parsec `attempt` vs PEG `!` |
| `Packrat` / `LeftRec` | Exponential vs memo; Warth growth |
| `MiniLang` | `let` / `print` / `if` on pure parsers |
| `StreamDemo` / `SuspendDemo` | Chunked postal / JSON; CoParser postal |
| `CoLang` | MiniLang fragment on `CoParser` |
| `CostCompare` | charVisits: Stream ~ n²/2 vs Suspend ~ n |

Run everything with `flix run` (see `src/Main.flix`).

## Design depth

Architecture, roadmap history, and rationale: [design-doc.md](design-doc.md).

## Versioning

This package is educational. The `0.y.z` series may change module layouts and APIs without a long deprecation cycle. Pin a git commit or tag when depending on it.
