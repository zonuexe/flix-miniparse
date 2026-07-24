# flix-miniparse

An **educational** parser-combinator library for [Flix](https://flix.dev/) (`miniparse` package).

The goal is not production parsing, but to implement combinators from scratch and compare two styles:

- **Parsec-style** predictive parsing (explicit backtracking via `try`)
- **PEG-style** automatic backtracking (ordered choice, `&` / `!` predicates, optional packrat memoization)

Built on Flix ADTs, the type system, and `Region` for packrat-style local mutability.

## Architecture (summary)

```text
Front-end:  MiniParse.Parsec  |  MiniParse.PEG
                    \              /
                     Core combinators
                            |
                     Core engine (state, errors, memo)
```

| Module | Backtracking |
| --- | --- |
| `MiniParse.Parsec` | Explicit — after consuming input, failure does not auto-retry; use `try` |
| `MiniParse.PEG` | Automatic — failed alternatives rewind; ordered choice and predicates |

Full design, module layout, and roadmap: **[docs/design-doc.md](docs/design-doc.md)**.

## Status

- **Step 0 done** — core engine, shared combinators, postal-code smoke test
- **Step 1 done** — `MiniParse.Parsec` / `MiniParse.PEG`, recursive JSON parser
- **Step 2 done** — arithmetic precedence; keyword vs identifier (`if` / `ifa`)
- **Step 3 done** — packrat memoization (`Region` + `MutMap`) and error pretty-printing
- **Step 4 done** — MiniLang (`let` / `print` / `if` / blocks) integrating expr + keyword boundaries
- **Step 5 done** — left-recursive packrat growth (`E <- E+n / n` vs right-recursive)
- **Step 6 done** — streaming / chunked input (`MiniParse.Stream`: feed, Await, drive)
- **Step 7 done** — expanded standard combinators (`oneOf`, `manyTill`, `sepEndBy`, `chainr1`, …)
- **Step 8 done** — coroutine suspension (`MiniParse.Suspend` / `CoParser` free monad)

See the [roadmap](docs/design-doc.md#4-implementation-roadmap).

## Development

Requires [Nix](https://nixos.org/) with flakes (or Flix 0.75.1+ and JDK 21).

```bash
nix develop   # or: direnv allow
flix check
flix test
flix run
```

## Layout

```text
src/
  MiniParse.flix           # parent module
  MiniParse/
    Core.flix              # Parser, State, Position, errors
    Combinator.flix        # map, flatMap, satisfy, ws, sepBy, …
    Parsec.flix            # orElse, attempt (explicit try)
    PEG.flix               # choice, & / ! predicates
    Packrat.flix           # Region + MutMap memoize helpers
    ErrorFormat.flix       # caret-style error messages
    Stream.flix            # chunked input (restart-style)
    Suspend.flix           # CoParser coroutine suspension
  Examples/
    PostalCode.flix        # Step 0
    Json.flix              # Step 1
    Expr.flix / Keyword.flix  # Step 2
    Packrat.flix           # Step 3 exponential vs memo
    MiniLang.flix          # Step 4 tiny language
    LeftRec.flix           # Step 5 left-recursive packrat
    StreamDemo.flix        # Step 6 chunked postal / JSON
    SuspendDemo.flix       # Step 8 true suspension
  Main.flix
test/ …
docs/design-doc.md
flake.nix
```

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
