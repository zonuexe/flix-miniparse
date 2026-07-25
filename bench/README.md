# parser-bench (in-repo)

Microbenchmarks comparing **this** package (`miniparse`) to sibling
[`flix-parsec`](https://github.com/stephentetley/flix-parsec).

This is a **nested Flix project** (`bench/flix.toml`). It does not affect the
published fpkg or root `flix test`.

## Expected layout

```text
repo/flix/
├── flix-miniparse/          # this repository
│   └── bench/               # ← you are here
└── flix-parsec/             # clone alongside for comparison
```

## Setup

From the repo root (with Flix 0.75.1+ / JDK 21, e.g. `nix develop`):

```bash
bash bench/scripts/install-local-deps.sh
cd bench
export JAVA_OPTS="${JAVA_OPTS:-} -Xss8m"
flix run
```

`install-local-deps.sh` builds the parent package and `../flix-parsec`, then
copies fpkgs into `bench/lib/github/...`.

`flix-parsec` is loaded with `security = "unrestricted"` (unchecked casts / Java collator).

## Tasks

| Task | Input | Both libraries |
| --- | --- | --- |
| `digits` | `n` × digit `1` | exact `n` digits |
| `many-a` | `n` × `a` | `many(char('a'))` |
| `skip-till` | `(n-1)` × `A` + `Z` | skip until `Z` |
| `lines` | `n` × `x\\n` | consume lines |
| `csv-ones` | `1,1,...,1` (capped) | `sepBy` digit |

Columns also include **miniparse-co** (`CoParser`) for `digits` / `many-a`.

## Reading results

- **ns/iter** — mean wall-clock after warmup (`System.nanoTime`); not JMH.
- **total-ns** — sum of timed iterations (excludes warmup).
- **ok** — last iteration succeeded.
- Iteration results are accumulated so pure parsers are not dead-code-eliminated.
- Tune `warmup` / `iters` / sizes in `Main.flix`.

### Caveats

1. flix-parsec recursive combinators may `StackOverflowError` without a larger stack (`-Xss8m`).
2. flix-parsec `skipManyTill` + `char` needs `tryParse` on the end parser (consume-then-fail; no rewind in `flatMapOr`). The bench does this.
3. Small pure loops must black-hole results or Flix/JVM can optimize them away.

On **small** inputs (32–128), pure miniparse is typically much faster than flix-parsec’s 2-CPS overhead. That measures combinator cost, not large-file throughput.
