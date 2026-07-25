///
/// Lab: debugging parsers without monad transformers.
///
/// Guide: `docs/debug.md`.
///
/// ## What this shows
///
/// 1. **`label` / `inContext`** on ordinary `Parser` — better expected messages
///    when a pure grammar fails (everyday tool).
/// 2. **`TParser` + `span`** — enter/ok/fail trail that survives failure
///    (Writer-like log, no `WriterT`).
///
/// Tiny grammar: `sum := number ('+' number)*` where `number` is digits.
///
mod Examples.DebugLab {

    use MiniParse.Core.{Parser, ParseError, parse}
    use MiniParse.Combinator.{digit, char, many, many1, map, flatMap, andThen}
    use MiniParse.ErrorFormat.formatError
    use MiniParse.Debug.{
        label, inContext,
        TParser, TraceEvent, lift, span, spanP, pure,
        parseTraced, formatTraced, failedSpans
    }

    ///////////////////////////////////////////////////////////////////////////
    // Pure Parser with better labels
    ///////////////////////////////////////////////////////////////////////////

    pub def numberP(): Parser[Int32] =
        label("number", map(digitsToInt, many1(digit())))

    def digitsToInt(cs: List[Char]): Int32 =
        List.foldLeft(
            (acc, c) -> acc * 10 + Char.getNumericValue(c) |> Option.getWithDefault(0),
            0,
            cs
        )

    /// `number (+ number)*` with rule names on failure.
    pub def sumP(): Parser[Int32] = {
        let plusNum = andThen(char('+'), numberP());
        inContext("sum",
            flatMap(n0 ->
                map(ns -> List.foldLeft((a, b) -> a + b, n0, ns),
                    many(plusNum)),
                numberP()
            )
        )
    }

    pub def parseSumLabeled(input: String): Result[ParseError, Int32] =
        parse(sumP(), input)

    ///////////////////////////////////////////////////////////////////////////
    // Traced grammar (TParser)
    ///////////////////////////////////////////////////////////////////////////

    pub def numberT(): TParser[Int32] =
        span("number", lift(numberP()))

    pub def sumT(): TParser[Int32] = {
        let plusNum =
            span("plusNumber",
                MiniParse.Debug.andThen(spanP("+", char('+')), numberT())
            );
        span("sum",
            MiniParse.Debug.flatMap(n0 ->
                MiniParse.Debug.map(
                    ns -> List.foldLeft((a, b) -> a + b, n0, ns),
                    manyT(plusNum)
                ),
                numberT()
            )
        )
    }

    /// Local `many` for `TParser` (PEG-style: try one more or succeed with Nil).
    def manyT(p: TParser[a]): TParser[List[a]] =
        MiniParse.Debug.orElse(
            MiniParse.Debug.flatMap(
                x -> MiniParse.Debug.map(xs -> x :: xs, manyT(p)),
                p
            ),
            pure(Nil)
        )

    pub def parseSumTraced(
        input: String
    ): (List[TraceEvent], Result[ParseError, Int32]) =
        parseTraced(sumT(), input)

    ///////////////////////////////////////////////////////////////////////////
    // Reports
    ///////////////////////////////////////////////////////////////////////////

    pub def reportLabeled(input: String): String =
        match parseSumLabeled(input) {
            case Ok(n)  => "labeled: Ok(${n})"
            case Err(e) => "labeled: Err\n" + formatError(input, e)
        }

    pub def reportTraced(input: String): String = {
        let (ev, r) = parseSumTraced(input);
        formatTraced(input, ev, r)
    }

    /// Side-by-side for demos and tests.
    pub def report(input: String): String =
        "input: `${input}`\n\n" +
            reportLabeled(input) + "\n\n" +
            "---\n\n" +
            reportTraced(input)

    pub def sampleOk(): String = "12+3+40"

    pub def sampleFail(): String = "12+x"

    /// Failed span names for the broken sample (for tests).
    pub def sampleFailFailedSpans(): List[String] = {
        let (ev, _) = parseSumTraced(sampleFail());
        failedSpans(ev)
    }

}
