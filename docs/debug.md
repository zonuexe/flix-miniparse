# Debugging parsers

How to inspect parse behavior in miniparse **without** a monad-transformer stack (`WriterT`, `StateT`, …).

Lab: [`Examples.DebugLab`](../test/Examples/DebugLab.flix). API: [`MiniParse.Debug`](../src/MiniParse/Debug.flix).

## Why not `WriterT` over Parsec?

Pure `Parser[a]` is a fixed function:

```text
State → Result[ParseError, (a, State)]
```

There is no slot to “stack” a writer or IO effect inside that type. That keeps Core/Parsec/PEG/Recover simple and pure. Debugging uses **small pure tools** on top instead.

## Everyday: better expected labels

Most “where did it fail?” questions are answered by **naming rules** and reading `ErrorFormat` output.

| Helper | Role |
| --- | --- |
| `label(name, p)` | Parsec-style `<?>` — on failure, expected becomes `name` |
| `inContext(ctx, p)` | Prefix each expected with `ctx: …` |
| `getPos()` | Current `Position` without consuming input |

```flix
use MiniParse.Debug.{label, inContext}
use MiniParse.Combinator.{digit, many1, map}

def number(): Parser[Int32] =
    label("number", map(digitsToInt, many1(digit())))

def sum(): Parser[Int32] =
    inContext("sum", /* number (+ number)* */)
```

Failed parse of `"12+x"` then reports something like expected `number` (or `sum: number`) instead of only `digit`.

Also useful without Debug:

- `parsePartial` — how far the cursor moved
- `ErrorFormat.formatError` — line/column + caret
- `Recover` multi-errors — several soft failures after resync

## Step trail: `TParser` + `span`

When you need **which rules ran** (including failed alternatives), use a parallel parser type that always returns a log:

```text
TParser[a]  ≈  State → (List[TraceEvent], Result[ParseError, (a, State)])
```

This is Writer-like **as a return value**, not as a transformer under `Parser`.

| API | Role |
| --- | --- |
| `lift(p)` | Embed ordinary `Parser` (no events) |
| `span(name, p)` | Enter / ok / fail around `p` (child events nested between) |
| `spanP(name, p)` | `span(name, lift(p))` |
| `parseTraced` / `parsePartialTraced` | Run and get `(events, result)` |
| `orElse` / `choice` | PEG-style backtrack; **failed left branch stays in the log** |
| `formatTrace` / `formatTraced` | Human-readable dump |
| `failedSpans` | Names of spans that recorded `Fail` |

Example shape (see DebugLab):

```flix
def numberT(): TParser[Int32] =
    span("number", lift(numberP()))

def sumT(): TParser[Int32] =
    span("sum", /* flatMap numberT and many (+ numberT) */)

let (events, result) = parseTraced(sumT(), "12+x");
// events include Enter/Fail for number after '+', etc.
```

Typical log lines:

```text
→ sum @ 1:1
→ number @ 1:1
← number ok @ 1:3
→ plusNumber @ 1:3
→ + @ 1:3
← + ok @ 1:4
→ number @ 1:4
← number fail @ 1:4 expected number
…
```

### When to use which

| Goal | Prefer |
| --- | --- |
| Clear error messages for users/learners | `label` / `inContext` |
| “Did this alternative run?” | `TParser` + `span` + `orElse` |
| Cursor / leftover input | `parsePartial` + `getPos` |
| Soft multi-errors | `Recover` |
| Streaming feed points | `Stream.drive` events |

You do **not** need to rewrite a whole production grammar as `TParser`. Instrument a **small suspected fragment**, or wrap key nonterminals with `span` only while debugging.

## Design notes

- `TParser.orElse` always backtracks so failed alternatives appear in the trace (debug-friendly; not identical to Parsec commit semantics).
- Core `Parser` stays pure and effect-free; no `println` inside the library type.
- CoParser free ADTs could grow a `Log` constructor later; pure `TParser` covers the common lab case without changing Suspend.

## See also

- [tutorial.md](tutorial.md) — combinators and choice policies
- [recovery.md](recovery.md) — panic-mode multi-error diagnostics
- [suspend.md](suspend.md) — free `CoParser` (related “effect as data” idea)
