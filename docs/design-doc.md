# flix-miniparse Design

Educational parser-combinator library for [Flix](https://flix.dev/).

This document records purpose, architecture, module layout, and the implementation roadmap.

## 1. Purpose and positioning

| Aspect | Choice |
| --- | --- |
| **Goal** | Learn how parser combinators work internally by implementing them from scratch. |
| **Focus** | Contrast **Parsec-style predictive parsing** (explicit backtracking via `try`) with **PEG-style automatic backtracking** (ordered choice, predicates, optional packrat memoization). |
| **Audience** | Educational / DIY — not a production parser framework. |
| **Host language** | **Flix** — algebraic data types, a strong type system, and the effect / `Region` system for controlled local mutability. |

The project is a laboratory: shared core machinery, two front-end APIs, and small languages used as verification targets.

## 2. Architecture

A **three-layer** design: one core engine, shared combinators, and two front-end APIs with different backtracking policies.

```text
┌────────────────────────────────────────────────────────┐
│              Front-end API / DSL modules               │
│  ┌──────────────────────┐    ┌──────────────────────┐  │
│  │   MiniParse.Parsec   │    │    MiniParse.PEG     │  │
│  │ (predictive / try)   │    │ (auto-backtrack)     │  │
│  └──────────┬───────────┘    └──────────┬───────────┘  │
└─────────────┼───────────────────────────┼──────────────┘
              ▼                           ▼
┌────────────────────────────────────────────────────────┐
│         Core combinators (shared primitives)           │
│   map, flatMap, satisfy, sequence, rollback, …         │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│     Core engine (state, errors, memoization)           │
│   Position / rollback state / furthest-error tracker   │
└────────────────────────────────────────────────────────┘
```

### 2.1 Core engine (`MiniParse.Core`)

Responsibilities:

1. **Position and rollback**  
   Track input position and restore a previous state safely (`rollback`).

2. **Furthest-error tracking**  
   On failure, record the **farthest** position reached and what was expected there. Especially important for usable errors under PEG-style automatic backtracking.

3. **Memoization (packrat support)**  
   Cache parse results for PEG runs. Use Flix **`Region`** with internal mutability (`MutMap`) behind an interface that is pure from the outside.

### 2.2 Front-end behavioral differences

| Module | Backtracking policy | Main combinators / features |
| --- | --- | --- |
| **`MiniParse.Parsec`** | **Explicit (LL(1)-like).** After consuming input, failure does not automatically retry an alternative. | Predictive / deterministic style; explicit rewind via `try(p)`. |
| **`MiniParse.PEG`** | **Automatic (implicit).** Failed alternatives restore state and try the next branch. | Ordered choice `choice` (`/`), `andPredicate` (`&`), `notPredicate` (`!`), `memoize`. |

## 3. Module and directory layout

```text
Main.flix             // flix run tour (not shipped in fpkg)
src/
  MiniParse/
    Core.flix         // Parser type, position, furthest-error tracking
    Combinator.flix   // map, flatMap, satisfy, and other shared operators
    Parsec.flix       // Parsec-style API (try-required model)
    PEG.flix          // PEG-style API (auto-backtrack & predicates)
test/
  Examples/           // Labs / demos (not shipped in fpkg)
  ...                 // Unit and integration tests
docs/
  design-doc.md       // This document
```

### 3.1 Code sketch

Illustrative only; concrete types will evolve during implementation.

```flix
mod MiniParse.Core {
    /// Parser as a function over input state.
    pub enum Parser[a] // (State) -> Result[(a, State), ParseError]

    /// Restore the input position if `p` fails after consuming input.
    pub def rollback(p: Parser[a]): Parser[a] = ???
}

mod MiniParse.Parsec {
    /// Choice without automatic backtrack: if `p1` fails after consuming
    /// input, do not fall through to `p2`.
    pub def orElse(p1: Parser[a], p2: Parser[a]): Parser[a] = ???

    /// Explicit backtrack wrapper.
    pub def try(p: Parser[a]): Parser[a] = MiniParse.Core.rollback(p)
}

mod MiniParse.PEG {
    /// Ordered choice with automatic rewind (PEG `/`).
    pub def choice(p1: Parser[a], p2: Parser[a]): Parser[a] =
        MiniParse.Parsec.orElse(MiniParse.Parsec.try(p1), p2)

    /// Negative lookahead (`!p`): succeed without consuming if `p` fails.
    pub def notPredicate(p: Parser[a]): Parser[Unit] = ???
}
```

## 4. Implementation roadmap

Progressive steps: implement features, then validate with a concrete target.

### Step 0 — Smoke test (postal code parser)

| | |
| --- | --- |
| **Goal** | Implement basics: `char`, `digit`, `string`, `map`, `flatMap`, `satisfy`. |
| **Target** | Strings of the form `〒150-0002` or `150-0002`. |
| **Why** | Linear, no choice/backtracking. Shared path for both Parsec and PEG APIs. |

### Step 1 — Combinators (JSON parser)

| | |
| --- | --- |
| **Goal** | Recursion, whitespace, escaped strings; map into a Flix ADT (`JsonValue`). |
| **Target** | A full JSON subset/parser. |
| **Why** | Mostly LL(1)-friendly; both modules should express a clean grammar. |

### Step 2 — Philosophy comparison (arithmetic or mini-language)

| | |
| --- | --- |
| **Goal** | Compare backtracking and lookahead. |
| **Targets** | Precedence/associativity (`1 + 2 * 3`); identifiers vs keywords (`if` vs `ifa`). |
| **Checks** | Stress of placing `try` under Parsec vs automatic backtrack and `!` under PEG. |

## 5. Implementation status

| Step | Status | Notes |
| --- | --- | --- |
| **0** | Done | Core + combinators; postal-code smoke test |
| **1** | Done | Parsec/PEG fronts; recursive JSON |
| **2** | Done | Arithmetic precedence; `if` / `ifa` philosophy comparison |
| **3** | Done | Packrat (`MiniParse.Packrat` + `Examples.Packrat`); `ErrorFormat` |
| **4** | Done | MiniLang: `let` / `print` / `if`–`then`–`else` / blocks + interpreter |
| **5** | Done | Left-recursive packrat growth (Warth-style); left vs right assoc |
| **6** | Done | Streaming input: `StreamState`, `feed`/`close`, `step` → Done/Fail/Await |
| **7** | Done | Standard combinator library expansion (see below) |
| **8** | Done | Coroutine suspension: `CoParser` free monad + `Await` continuations |
| **9** | Done | CoLang fragment on CoParser; Stream vs Suspend scan-cost comparison |
| **10** | Done | MiniLang comparisons/`while`; `MiniParse.Bridge` (Parser ↔ CoParser) |
| **11** | Done | CoLang full MiniLang grammar on `CoParser`; shared AST/runtime; Bridge demo |
| **12** | Done | `Examples.LangCompare`: MiniLang vs CoLang parse/run parity table |

Optional follow-ups: publish a SemVer git tag for `github:zonuexe/flix-miniparse`,
further handler-style effects docs.

## 6. Package layout (consumer view)

| Path | Role |
| --- | --- |
| `src/MiniParse/**` | **Library** — depend on these modules (shipped in fpkg) |
| `Main.flix` | `flix run` tour (repo only; not shipped in fpkg) |
| `test/Examples/**` | Labs / demos — copy patterns, do not treat as API (not shipped) |
| `test/**` | Automated tests |
| `docs/overview.md` | Short consumer map |
| `docs/design-doc.md` | This design history |
| `CHANGELOG.md` | Release notes |
| `flix.toml` | Package `miniparse` |
| `LICENSE.md` | License text packed into the fpkg |

### Deep backtrack under suspension

`orElse(p1, p2)` = `Choice(p1, p2)`. The attempt interpreter runs `p1` on an
immutable buffer; failure retries `p2` on the **original** buffer (deep rewind).
If `p1` suspends, a `Branch` frame keeps `p2` and the character log so a later
failure still rebuilds input for `p2` (`committed ++ remaining`).

### Suspension notes (Step 8)

| Layer | On short input | Resume |
| --- | --- | --- |
| `MiniParse.Stream` | `Await` + **restart** pure `Parser` from cursor | re-run whole parser |
| `MiniParse.Suspend` | `Await(Suspended(k, pos))` | call `k(Some(c))` — **same** stack |

`CoParser` is a free program over `Read: Option[Char] -> CoParser[a]`. The driver
`pump` interprets it against a buffer; when the buffer is empty the pending
`Read` continuation is stored, not discarded.

### Standard combinators (Step 7 additions)

| Group | Combinators |
| --- | --- |
| Characters | `anyChar`, `oneOf`, `noneOf`, `hexDigit`, `endOfLine`, `takeWhile`/`takeWhile1` |
| Lookahead | `lookAhead`, `notFollowedBy` |
| Skip / value | `void`, `replace`, `option`, `skipMany`/`skipSome` |
| Lists | `manyTill`, `endBy`/`endBy1`, `sepEndBy`/`sepEndBy1`, `many1` |
| Folding | `chainr1` (with existing `chainl1`) |
| Other | `filter` |

### Streaming notes (Step 6)

- Pure `Parser`s are unchanged; streaming is an adapter layer.
- `Await` when a failure occurs at the end of an **open** buffer (need more data).
- After `close`, the same situation is a hard EOF `Fail`.
- Each `step` restarts the pure parser from the saved cursor (no call-stack suspension).
