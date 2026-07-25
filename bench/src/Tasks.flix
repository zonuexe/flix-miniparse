///
/// Equivalent micro-tasks on **miniparse** and **flix-parsec**.
///
/// | Task | Input | Work |
/// | --- | --- | --- |
/// | `digits` | `n` digits (`1` repeated) | parse exactly `n` digits |
/// | `many-a` | `n` × `a` | `many(char('a'))` |
/// | `skip-till` | `(n-1)` × `A` + `Z` | skip until `Z`, take next char |
/// | `lines` | `n` lines of `x\\n` | skip each line (char until newline) |
/// | `csv-ints` | `0,1,2,...,n-1` | sepBy digit/int by comma |
///
mod Tasks {

    use Bench.{Sample, runSample}
    use MiniParse.Core.{parse, pure}
    use MiniParse.Combinator.{
        map, andThen, char, digit, digits, many, manyTill, anyChar,
        endOfLine, sepBy
    }
    use Applicative.{point}
    use Monad.{>>=}

    ///////////////////////////////////////////////////////////////////////////
    // Inputs
    ///////////////////////////////////////////////////////////////////////////

    pub def inputDigits(n: Int32): String =
        String.repeat(n, "1")

    pub def inputManyA(n: Int32): String =
        String.repeat(n, "a")

    pub def inputSkipTill(n: Int32): String =
        if (n <= 1)
            "Z"
        else
            String.repeat(n - 1, "A") + "Z"

    pub def inputLines(n: Int32): String =
        String.repeat(n, "x\n")

    /// `0,1,2,...,n-1` (single digits only when n <= 10 — use n of values 0..9 repeated).
    /// For fairness we use `n` single digits separated by commas: `1,1,1,...`.
    pub def inputCsvOnes(n: Int32): String =
        if (n <= 0)
            ""
        else if (n == 1)
            "1"
        else
            "1" + String.repeat(n - 1, ",1")

    ///////////////////////////////////////////////////////////////////////////
    // miniparse (pure Parser)
    ///////////////////////////////////////////////////////////////////////////

    def miniDigitsOk(n: Int32, s: String): Bool =
        match parse(digits(n), s) {
            case Ok(_)  => true
            case Err(_) => false
        }

    def miniManyAOk(s: String): Bool =
        match parse(many(char('a')), s) {
            case Ok(_)  => true
            case Err(_) => false
        }

    def miniSkipTillOk(s: String): Bool = {
        let p = andThen(
            manyTill(anyChar(), char('Z')),
            pure(())
        );
        match parse(p, s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def miniLinesOk(s: String): Bool = {
        // Consume each line: chars until newline (inclusive via endOfLine).
        let line = andThen(manyTill(anyChar(), endOfLine()), pure(()));
        match parse(many(line), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def miniCsvOk(s: String): Bool = {
        let one = map(_ -> (), digit());
        match parse(sepBy(one, char(',')), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // miniparse CoParser
    ///////////////////////////////////////////////////////////////////////////

    def miniCoDigitsOk(n: Int32, s: String): Bool =
        match MiniParse.Suspend.parseChunks(MiniParse.Suspend.digits(n), s :: Nil) {
            case Ok(_)  => true
            case Err(_) => false
        }

    def miniCoManyAOk(s: String): Bool =
        match MiniParse.Suspend.parseChunks(
            MiniParse.Suspend.many(MiniParse.Suspend.char('a')),
            s :: Nil
        ) {
            case Ok(_)  => true
            case Err(_) => false
        }

    ///////////////////////////////////////////////////////////////////////////
    // flix-parsec
    ///////////////////////////////////////////////////////////////////////////

    def parsecDigitsOk(n: Int32, s: String): Bool = {
        use FlixParsec.Char.{digit => pDigit};
        use FlixParsec.Combinators.{count};
        use FlixParsec.GenParser.{parsesString};
        match parsesString(count(n, pDigit()), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def parsecManyAOk(s: String): Bool = {
        use FlixParsec.Char.{char => pChar};
        use FlixParsec.Combinators.{many => pMany};
        use FlixParsec.GenParser.{parsesString};
        match parsesString(pMany(pChar('a')), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def parsecSkipTillOk(s: String): Bool = {
        use FlixParsec.Char.{char => pChar, anyChar => pAny};
        use FlixParsec.Combinators.{skipManyTill};
        use FlixParsec.GenParser.{parsesString};
        use FlixParsec.Internal.ParserMonad.{tryParse};
        // `satisfy`/`char` consume before failing; `skipManyTill` uses flatMapOr
        // without rewind — wrap the end parser in tryParse (Parsec `try`).
        match parsesString(skipManyTill(pAny(), tryParse(pChar('Z'))), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def parsecLinesOk(s: String): Bool = {
        use FlixParsec.Char.{anyChar => pAny, newline};
        use FlixParsec.Combinators.{skipManyTill, many => pMany};
        use FlixParsec.GenParser.{parsesString};
        let line = skipManyTill(pAny(), newline());
        match parsesString(pMany(line), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    def parsecCsvOk(s: String): Bool = {
        use FlixParsec.Char.{char => pChar, digit => pDigit};
        use FlixParsec.Combinators.{sepBy};
        use FlixParsec.GenParser.{parsesString};
        use Applicative.{point};
        use Monad.{>>=};
        let one = pDigit() >>= (_ -> point(()));
        match parsesString(sepBy(one, pChar(',')), s) {
            case Ok(_)  => true
            case Err(_) => false
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // Suite
    ///////////////////////////////////////////////////////////////////////////

    /// Default sizes (keep total runtime modest; raise for serious profiling).
    ///
    /// Note: flix-parsec's recursive combinators (`count` / `many` / `skipManyTill`)
    /// can `StackOverflowError` on large `n` under default JVM stack; prefer
    /// `-Xss8m` (see README) before pushing sizes into the thousands.
    pub def defaultSizes(): List[Int32] =
        32 :: 64 :: 128 :: Nil

    pub def runSuite(
        warmup: Int32,
        iters: Int32,
        sizes: List[Int32]
    ): List[Sample] \ IO = {
        def forSize(n: Int32, acc: List[Sample]): List[Sample] \ IO = {
            let d = inputDigits(n);
            let a = inputManyA(n);
            let sk = inputSkipTill(n);
            let ln = inputLines(n);
            let csv = inputCsvOnes(Int32.min(n, 500)); // cap csv width
            let csvN = Int32.min(n, 500);

            let r1 = runSample("miniparse", "digits", n, warmup, iters, _ -> miniDigitsOk(n, d));
            let r2 = runSample("flix-parsec", "digits", n, warmup, iters, _ -> parsecDigitsOk(n, d));
            let r3 = runSample("miniparse-co", "digits", n, warmup, iters, _ -> miniCoDigitsOk(n, d));

            let r4 = runSample("miniparse", "many-a", n, warmup, iters, _ -> miniManyAOk(a));
            let r5 = runSample("flix-parsec", "many-a", n, warmup, iters, _ -> parsecManyAOk(a));
            let r6 = runSample("miniparse-co", "many-a", n, warmup, iters, _ -> miniCoManyAOk(a));

            let r7 = runSample("miniparse", "skip-till", n, warmup, iters, _ -> miniSkipTillOk(sk));
            let r8 = runSample("flix-parsec", "skip-till", n, warmup, iters, _ -> parsecSkipTillOk(sk));

            let r9 = runSample("miniparse", "lines", n, warmup, iters, _ -> miniLinesOk(ln));
            let r10 = runSample("flix-parsec", "lines", n, warmup, iters, _ -> parsecLinesOk(ln));

            let r11 = runSample("miniparse", "csv-ones", csvN, warmup, iters, _ -> miniCsvOk(csv));
            let r12 = runSample("flix-parsec", "csv-ones", csvN, warmup, iters, _ -> parsecCsvOk(csv));

            r12 :: r11 :: r10 :: r9 :: r8 :: r7 :: r6 :: r5 :: r4 :: r3 :: r2 :: r1 :: acc
        };
        List.reverse(List.foldLeft((acc, n) -> forSize(n, acc), Nil, sizes))
    }

}
