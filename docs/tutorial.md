# Tutorial: parser combinators in miniparse

A short path from “what is a parser combinator?” to Parsec vs PEG in this package.
For module tables and advanced topics, see [overview.md](overview.md) and the other guides.

**Requirements:** Flix 0.75.1+ and a dependency on `miniparse` (see the root [README](../README.md)), or a clone of this repo with `flix test` / `flix run` ([CONTRIBUTING.md](../CONTRIBUTING.md)).

Japanese: [ja/tutorial.md](ja/tutorial.md)

---

## 1. What you are building

A **parser** turns text into a structured value (or an error). A **parser combinator**
is a small parser plus operators that build larger parsers (`map`, `andThen`, `many`,
choice, …). You write the grammar as ordinary Flix functions instead of a separate
`.y` / `.peg` file.

In miniparse the core idea is:

```text
Parser[a]  ≈  State → Result[ParseError, (a, State)]
```

`State` holds the input string and a cursor (offset + line/column). Success returns
a value and an advanced state; failure returns what was expected and where.

```flix
use MiniParse.Core.{parse}
use MiniParse.Combinator.{digit, many, map, charsToString}

def digits(): MiniParse.Core.Parser[String] =
    map(charsToString, many(digit()))

// parse(digits(), "4242")  ==>  Ok("4242")
// parse(digits(), "x")     ==>  Err(... expected digit ...)
```

Shared building blocks live in `MiniParse.Combinator`. How **choice** behaves when
something fails is the job of the front-end modules.

---

## 2. The shared stack

```text
  MiniParse.Parsec          MiniParse.PEG
         \                     /
          \                   /
           Combinator + Core
```

- **Core** — `Parser`, positions, `ParseError`, `parse` / `parsePartial`
- **Combinator** — `satisfy`, `string`, `many`, `sepBy`, `chainl1`, …
- **Parsec** / **PEG** — only the **policy** for alternatives and (for PEG) predicates

You almost always depend on `Core` + `Combinator` plus **one** of Parsec or PEG
for a given grammar (or use both deliberately to compare).

---

## 3. Parsec style: commit after consume

Background: [Parsec (parser)](https://en.wikipedia.org/wiki/Parsec_(parser)) —
Haskell’s classic combinator library; the same design shows up in many languages.

In miniparse:

```flix
use MiniParse.Parsec.{orElse, attempt}
```

**Rule of thumb:** if the left alternative of `orElse` fails **after eating input**,
the right alternative is **not** tried. That keeps parsers predictive and errors
close to the failure site, but you must mark ambiguous prefixes with `attempt`
(Parsec’s `try`).

Classic pitfall — keyword vs longer identifier:

```text
// Naive: try keyword "if", else ident
// Input: ifa
// Left branch matches "if", then fails on the leftover "a" after a committed consume
// → no fallthrough to "ident", even though "ifa" is a valid name
```

Fix under Parsec: wrap the keyword (or the consuming prefix) in `attempt` so failure
rewinds, then try `ident`. The lab `Examples.Keyword` walks through naive / Parsec /
PEG side by side.

```flix
// Sketch only — see test/Examples/Keyword.flix for a full grammar
// orElse(attempt(keyword("if")), ident())
```

---

## 4. PEG style: ordered choice rewinds

Background: [Parsing expression grammar](https://en.wikipedia.org/wiki/Parsing_expression_grammar)
(PEG) — ordered choice `e1 / e2` tries `e1`, and on failure **restores** the input
and tries `e2`. PEG also has syntactic predicates `&e` (and) and `!e` (not).

In miniparse:

```flix
use MiniParse.PEG.{choice, andPredicate, notPredicate}
```

- `choice(p1, p2)` ≈ Parsec `orElse(attempt(p1), p2)` (automatic try on the left)
- `notPredicate(p)` succeeds without consuming if `p` fails (handy for keyword boundaries:
  `string("if")` then `!identChar`)

Same `ifa` example: PEG ordered choice naturally backtracks out of a failed
`if`-keyword attempt and can accept `ifa` as an identifier, as long as the keyword
rule is written with a proper boundary (`!` after `if`).

---

## 5. When to prefer which (for learning)

| Goal | Lean toward |
| --- | --- |
| Understand **commit vs try** and LL(1)-like discipline | **Parsec** + place `attempt` yourself |
| Prefer **grammar-shaped** ordered choice and `&` / `!` | **PEG** |
| Study **memoization / left recursion** | Packrat labs (`Examples.Packrat`, `LeftRec`) after the basics |
| Chunked input / suspension cost | [suspend.md](suspend.md), `Stream` / `Suspend` / `CostCompare` |

There is no single “correct” style for every language. miniparse’s value is that
**both** sit on one `Parser` type so you can change only the choice layer.

---

## 6. Where to go next

| Next | Doc / lab |
| --- | --- |
| Module map and more snippets | [overview.md](overview.md) |
| Full architecture and roadmap | [design-doc.md](design-doc.md) |
| Keyword / `if` vs `ifa` | `Examples.Keyword`, `flix run` |
| Tiny language | `Examples.MiniLang` (pure), `Examples.CoLang` (CoParser) |
| Soft errors after a bad statement | [recovery.md](recovery.md) |
| Streaming vs coroutine parsers | [suspend.md](suspend.md) |

In this repository:

```bash
flix run    # tour of the labs
flix test
```

Happy parsing.
