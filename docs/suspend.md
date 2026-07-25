# Suspendable parsers (`CoParser`)

How **coroutine-style** parsing fits next to pure `Parser`s, and what to use when.

Related code:

| Piece | Role |
| --- | --- |
| [`MiniParse.Suspend`](../src/MiniParse/Suspend.flix) | Free `CoParser`, deep `orElse`, driver |
| [`MiniParse.Stream`](../src/MiniParse/Stream.flix) | Restart-style chunking over pure parsers |
| [`MiniParse.Bridge`](../src/MiniParse/Bridge.flix) | Embeddings between the two stacks |
| [`Examples.CostCompare`](../test/Examples/CostCompare.flix) | Scan-cost lab (restart vs continue) |

---

## Two ways to wait for input

| Layer | On short input | Resume |
| --- | --- | --- |
| **Stream** | `Await` + **restart** the pure parser from a cursor | Re-run the whole `Parser` on the buffer |
| **Suspend** | `Await(Suspended(k, pos))` | Call the stored **continuation** (`Read` / `Peek`) |

Stream is an adapter: pure combinators stay pure. Suspend reifies the parse as a **free program** over character reads so the driver can pause mid-token.

For one-character chunks of length `n`, CostCompare shows roughly:

- Stream `charVisits` ≈ \(n(n+1)/2\) (triangular rescan)
- Suspend `charVisits` ≈ \(n\) (each char consumed about once)

---

## Free program shape

```text
CoParser[a]
  Pure / Fail
  Read   (Option[Char] -> CoParser[a])    // consume or EOF
  Peek   (Option[Char] -> CoParser[a])    // no consume
  Choice / Branch                         // deep orElse + suspend across choice
  (+ delay via Peek for recursive grammars)
```

Interpretation uses an immutable buffer snapshot so **failed alternatives can rewind** (including after suspension) — that is “deep `orElse`”.

This is intentionally an **ADT free monad**, not Flix algebraic effects / handlers. Reasons that fit this project:

1. **Portable teaching model** — same idea as free parsers in other languages; no effect row required to read the code.
2. **Explicit driver** — `pump` / `feed` / `close` make Await visible in types (`Outcome`).
3. **Deep backtrack** — choice frames (`Branch`) hold committed character logs; encoding that cleanly as a user-land handler is possible but heavier for a lab library.

A future “handler-style” port would map `Read`/`Fail`/`Choice` to operations and handle them with a coroutine-like handler; the **API surface** for combinators could stay similar. That experiment is optional, not required to use Suspend today.

---

## Combinators

Suspend mirrors most of pure `Combinator`: lists (`many`, `sepBy`, `manyTill`, …), folding (`chainl1`, `chainr1`), lexical helpers (`ws`, `lexeme`, `symbol`, `between`), character classes.

Char-level lookahead:

| API | Role |
| --- | --- |
| `peek` | Next char or EOF, no consume |
| `notFollowedByPred` | Negative lookahead on a char predicate |
| `keyword` / `ident` | Boundary-aware word tokens (`if` vs `ifa`) |

**Parser-level** `lookAhead` / `notFollowedBy` (arbitrary sub-`CoParser`) are **not** on the Suspend public surface in the same form as pure `Combinator`. Encoding general lookahead bind in the free ADT needs either existentials or type erasure (`unchecked_cast`), which would push dependents toward `security = "unrestricted"`. Prefer:

- char-level `Peek` / `notFollowedByPred` for keywords and operators;
- or `Bridge.toParser` / `parseCo` when the whole input is already buffered and pure `Combinator.lookAhead` is enough.

---

## Bridge

```flix
// CoParser as pure Parser (full remainder, eof asserted)
MiniParse.Bridge.toParser(co)
MiniParse.Bridge.parseCo(co, input)

// Pure parser after buffering all chars under CoParser
MiniParse.Bridge.fromParser(pureParser)
MiniParse.Bridge.pureViaCo(pureParser, input)
```

Use Bridge when composing Suspend with Parsec/PEG stacks or when running a pure grammar through a Co-shaped driver.

---

## Recovery

Panic-mode recovery (`MiniParse.Recover`) targets **pure** `Parser` statement lists. It does not yet drive `CoParser` across soft errors. See [recovery.md](recovery.md).

---

## Learning path

1. Parse a string with pure `Combinator` and `Core.parse`.
2. Feed the same grammar through `Stream.parseChunks` with tiny chunks — watch restarts.
3. Rebuild a small grammar on `CoParser` (`SuspendDemo`, `CoLang`) — watch `Await` mid-token.
4. Run `CostCompare` for the quantitative contrast.
5. Read `attempt` / `Choice` / `Branch` in `Suspend.flix` for deep backtrack under suspension.
