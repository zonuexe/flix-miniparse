# Error recovery and diagnostics

How **miniparse** separates a hard parse failure from **soft** errors collected during panic-mode recovery, and how to use that in a language-like grammar.

Related code:

| Piece | Role |
| --- | --- |
| [`MiniParse.Recover`](../src/MiniParse/Recover.flix) | `WithErrors`, `resync`, `manySkipping`, `recover` |
| [`MiniParse.ErrorFormat`](../src/MiniParse/ErrorFormat.flix) | `formatError`, `formatErrors`, `formatWithErrors` |
| [`Examples.RecoverLab`](../test/Examples/RecoverLab.flix) | Strict vs resilient MiniLang demo |

Run the lab via `flix run` (section **Recover**) or `flix test` (`TestRecover`).

---

## Why recovery exists

A strict `parse(program, input)` fails on the **first** bad statement and drops the rest of the file. That is correct for many tools (compilers that want fail-fast CI), but poor for **interactive** or **batch** feedback: users want every broken statement reported, and as much of the AST as possible kept for later phases.

Panic-mode recovery is a classical compiler technique:

1. Try to parse the next item (statement, declaration, …).
2. On failure, **record** the error, **skip** to a synchronization token (often `;` or `}`), and continue.
3. Return a partial result plus a list of soft errors.

miniparse implements that as a **layer on top of** ordinary pure `Parser`s. It does not change Parsec/PEG choice rules.

---

## Hard vs soft errors

| Kind | Type / path | Meaning |
| --- | --- | --- |
| **Hard** | `Result.Err(ParseError)` | Could not produce a usable top-level value (e.g. leftover input after recovery, or a non-recovering `parse`) |
| **Soft** | inside `WithErrors(_, List[ParseError])` | Item failed; input was resynchronized; other items may still be present |

```flix
use MiniParse.Recover.{WithErrors, valueOf, errorsOf, isClean, parseWithErrors}

// Ok(WithErrors(stmts, errs))  — top-level success; errs may be non-empty
// Err(e)                       — hard failure
```

`parseWithErrors` still requires the **entire** input to be consumed (same rule as `Core.parse`). Leftover text after the recovered list is a hard `end of input` error at the leftover position.

---

## Core API

### `WithErrors`

```flix
enum WithErrors[a] {
    case WithErrors(a, List[ParseError])
}

valueOf : WithErrors[a] -> a
errorsOf : WithErrors[a] -> List[ParseError]
isClean  : WithErrors[a] -> Bool          // errorsOf is Nil
clean    : a -> WithErrors[a]             // no soft errors
mapValue : (a -> b) -> WithErrors[a] -> WithErrors[b]
```

Soft errors are ordered in the order recovery encountered them (not necessarily source order after complex sync).

### Sync helpers

| Function | Behavior |
| --- | --- |
| `skipUntilOneOf(chars)` | Skip while next char ∉ `chars`; stop **before** a sync char or EOF |
| `skipPastOneOf(chars)` | Skip until **and including** the first char in `chars`, or to EOF |
| `skipOne()` | Advance one character if possible |
| `resync(chars)` | `skipPastOneOf`, but force at least one character if stuck |

Implementation note: sync is an **offset scan** on the input string (not `many(satisfy…)`). That keeps progress obvious and avoids edge cases around “consume-then-fail” character tests.

### Single item

```flix
// On success: clean(value)
// On failure: run sync from the attempt start, yield fallback, record one soft error
recover(p, sync, fallback): Parser[WithErrors[a]]

// Same, but failure yields None (no dummy AST node)
recoverSkip(p, sync): Parser[WithErrors[Option[a]]]
```

### Sequences (usual entry point)

```flix
// Zero or more items; failed items are omitted from the list (soft errors only)
manySkipping(item, sync): Parser[WithErrors[List[a]]]

// ws *> manySkipping(item, sync) <* ws
programSkipping(item, sync): Parser[WithErrors[List[a]]]
```

Before each item attempt, `manySkipping` runs `ws()` so recovery that lands on a newline does not treat whitespace as a failed statement (and skip the next real statement).

---

## Choosing sync tokens

Panic-mode is only as good as the **synchronization set**.

| Grammar shape | Typical sync | Risk if wrong |
| --- | --- | --- |
| Statement list (`stmt;`) | `";"` or `";}"` | Syncing on `;` only can stop inside a string/comment if those exist |
| Block-oriented | `"}"` | May skip many statements to the next brace |
| Line-oriented | `"\n"` | Windows `\r\n` — prefer scanning that includes `\n` |

**MiniLang lab** uses `resync(";}")`: statement terminator or end of block. There are no string literals, so `;` inside code is unambiguous.

Guidelines:

1. Prefer tokens that **must** appear at item boundaries in a correct program.
2. Guarantee **progress** after a failure (`resync` forces one character if the skip did not move).
3. Accept that recovery can **skip good text** after a bad item (false negatives in the AST) — that is the panic-mode tradeoff.
4. Do not expect recovery to “fix” broken syntax into a perfect tree; it is for **continuation and diagnostics**.

---

## Where recovery starts

On failure, sync runs from the **start of the failed attempt** (after leading `ws` in `manySkipping`), not from a “furthest error” label alone.

Reason: PEG-style `attempt` / `try` often **rewrites** error positions back to the attempt start so choice can try the next alternative. Furthest-error positions are still useful for **messages**, but using them as the skip origin can nibble one character at a time when labels and real consumption disagree.

`ParseError` on a soft failure is still the error returned by the item parser (merged expectations, etc.), so `formatError` remains informative.

---

## Worked example (MiniLang)

Source:

```text
let x = 1;
let = 2;
print x;
```

| Mode | Result |
| --- | --- |
| **Strict** (`Examples.MiniLang.parseProgram`) | `Err` — often surfaces as leftover input / fail at the second `let` |
| **Resilient** (`Examples.RecoverLab.parseResilient`) | `Ok` with stmts `[Let(x,1), Print(x)]` and **one** soft error on the bad `let` |
| **Run after recovery** | Interpreter runs the kept statements → print `1` |

Sketch of the resilient program parser:

```flix
use MiniParse.Recover.{programSkipping, resync, parseWithErrors}
use Examples.MiniLang.{stmt}

def programRecovering() =
    programSkipping(stmt(), resync(";}"))

def parseResilient(input: String) =
    parseWithErrors(programRecovering(), input)
```

Reporting (lab helper):

```flix
// Strict failure message
formatError(input, hardErr)

// Soft list after recovery
formatErrors(input, errorsOf(w))
// or
formatWithErrors(input, w)
```

---

## Diagnostics formatting

| Helper | Use when |
| --- | --- |
| `formatError(input, e)` | Single hard or soft error (line, column, caret, expected) |
| `formatErrors(input, es)` | Numbered list of soft errors |
| `formatWithErrors(input, w)` | `"ok (clean)"` or `"ok with N soft error(s):"` + list |
| `formatNeedInput` / stream / suspend helpers | Incomplete chunked input (not recovery) |

Soft and hard errors share the same `ParseError` shape (`Position` + expected labels). Recovery does not introduce a second error type.

---

## What recovery does *not* do

- **CoParser / Stream**: `Recover` is for pure `Parser` only. Chunked or suspendable recovery is a separate design (resume after sync across chunks).
- **Automatic insert/delete** of tokens (edit-distance repair).
- **Semantic** recovery (type errors, unbound names) — that stays in the interpreter / checker (`MiniLang.runProgram` still returns `RuntimeError`).
- **Changing** Parsec commit or PEG ordered choice; wrap completed item parsers, do not replace `orElse`.

---

## Practical checklist

1. Write a strict item parser (`stmt`) that works on good input.
2. Pick sync characters that bound items in your concrete syntax.
3. Use `programSkipping(item, resync(syncChars))` or `manySkipping` for the list.
4. Surface soft errors with `formatErrors`; keep hard `Err` for unrecoverable cases.
5. Run later phases on `valueOf(w)` only if that is safe (partial AST).
6. Add tests that assert **both** kept neighbors and soft-error count (see `TestRecover`).

---

## Learning path

1. Fail a MiniLang program strictly — read `formatError`.
2. Run the same string through `RecoverLab.report` — compare soft vs hard.
3. Change sync from `";}"` to `";"` only and see how recovery shape changes.
4. Read `manySkipping` in `Recover.flix` (ws → try item → resync → loop).

For architecture of the pure engine underneath, see [design-doc.md](design-doc.md) and [overview.md](overview.md).
