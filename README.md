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

**Step 0 done** — core engine, shared combinators, and a postal-code smoke test (`150-0002` / `〒150-0002`). See the [roadmap](docs/design-doc.md#4-implementation-roadmap).

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
    Combinator.flix        # map, flatMap, satisfy, char, digit, …
  Examples.flix
  Examples/
    PostalCode.flix        # Step 0 smoke test
  Main.flix                # demo
test/
  TestCore.flix
  TestPostalCode.flix
docs/design-doc.md
flake.nix
```

## License

Apache License 2.0. See [`LICENSE`](LICENSE).
