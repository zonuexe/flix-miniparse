///
/// Step B: cost of **restart-style** streaming vs **coroutine** suspension.
///
/// Same grammar: `digits(n)` over a list of 1-character chunks.
///
/// | Metric | Stream (pure Parser) | Suspend (CoParser) |
/// | --- | --- | --- |
/// | `steps` | each `step` re-runs the whole parser from the cursor | each resume continues a continuation |
/// | `charVisits` | on every step, all buffered unread chars are re-examined | each input char is consumed about once (no prefix re-scan) |
///
/// For input length `n` fed one char at a time, Stream's `charVisits` is
/// roughly `1+2+...+n = n(n+1)/2`, while Suspend's is about `n`.
///
mod Examples.CostCompare {

    use MiniParse.Core.{Parser, ParseError, runParser, stateOffset}
    use MiniParse.Combinator.{digits => pDigits}
    use MiniParse.Stream.{
        open, feed, close, step, Step, buffer, offset, StreamState
    }
    use MiniParse.Suspend.{
        CoParser, digits => cDigits, start, startWith, feed => cFeed, close => cClose,
        Outcome, Suspended, parseChunks
    }

    pub enum Cost with Eq, ToString {
        case Cost(
            Int32, // steps: interpreter entries (restarts or resumes)
            Int32  // charVisits: how many character peeks/consumes
        )
    }

    pub def stepsOf(c: Cost): Int32 = match c {
        case Cost.Cost(s, _) => s
    }

    pub def visitsOf(c: Cost): Int32 = match c {
        case Cost.Cost(_, v) => v
    }

    ///////////////////////////////////////////////////////////////////////////
    // Stream: restart-style
    ///////////////////////////////////////////////////////////////////////////

    /// Drive pure `digits(n)` one chunk at a time; count steps and char visits.
    ///
    /// Each `step` costs `bufferLength - cursor` char visits (parser re-reads
    /// from the cursor through the end of the buffer).
    pub def streamDigitsCost(
        n: Int32,
        chunks: List[String]
    ): (Result[ParseError, String], Cost) = {
        let p = pDigits(n);
        def loop(
            cs: List[String],
            s: StreamState,
            steps: Int32,
            visits: Int32
        ): (Result[ParseError, String], Cost) = match cs {
            case Nil => {
                let s1 = close(s);
                let scan = String.length(buffer(s1)) - offset(s1);
                match step(p, s1) {
                    case Step.Done(x, s2) =>
                        if (offset(s2) >= String.length(buffer(s2)))
                            (Ok(x), Cost.Cost(steps + 1, visits + scan))
                        else
                            (Err(ParseError.Error(
                                MiniParse.Stream.cursor(s2),
                                "end of input" :: Nil
                            )), Cost.Cost(steps + 1, visits + scan))
                    case Step.Fail(e) =>
                        (Err(e), Cost.Cost(steps + 1, visits + scan))
                    case Step.Await(_) =>
                        (Err(ParseError.Error(
                            MiniParse.Stream.cursor(s1),
                            "end of input" :: Nil
                        )), Cost.Cost(steps + 1, visits + scan))
                }
            }
            case c :: rest => {
                let s1 = feed(c, s);
                let scan = String.length(buffer(s1)) - offset(s1);
                match step(p, s1) {
                    case Step.Await(s2) =>
                        loop(rest, s2, steps + 1, visits + scan)
                    case Step.Done(x, s2) =>
                        if (List.isEmpty(rest) and offset(s2) >= String.length(buffer(s2)))
                            (Ok(x), Cost.Cost(steps + 1, visits + scan))
                        else if (List.isEmpty(rest))
                            (Err(ParseError.Error(
                                MiniParse.Stream.cursor(s2),
                                "end of input" :: Nil
                            )), Cost.Cost(steps + 1, visits + scan))
                        else
                            // Early done with more chunks — treat as continue/await-ish
                            loop(rest, s2, steps + 1, visits + scan)
                    case Step.Fail(e) =>
                        (Err(e), Cost.Cost(steps + 1, visits + scan))
                }
            }
        };
        loop(chunks, open(), 0, 0)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Suspend: coroutine-style
    ///////////////////////////////////////////////////////////////////////////

    /// Drive CoParser `digits(n)`; each successful character consume counts 1 visit.
    /// `steps` counts suspension resumes + final close attempt (Await entries).
    pub def suspendDigitsCost(
        n: Int32,
        chunks: List[String]
    ): (Result[ParseError, String], Cost) = {
        let p = cDigits(n);
        // charVisits ≈ total chars in chunks for a successful linear parse
        let totalChars = List.foldLeft((acc, c) -> acc + String.length(c), 0, chunks);
        def loop(
            cs: List[String],
            o: Outcome[String],
            steps: Int32
        ): (Result[ParseError, String], Cost) = match o {
            case Outcome.Fail(e) =>
                (Err(e), Cost.Cost(steps, totalChars))
            case Outcome.Done(x, rest) =>
                if (String.isEmpty(rest) and List.isEmpty(cs))
                    (Ok(x), Cost.Cost(steps, totalChars))
                else
                    (Err(ParseError.Error(
                        MiniParse.Core.initialPosition(),
                        "end of input" :: Nil
                    )), Cost.Cost(steps, totalChars))
            case Outcome.Await(s) =>
                match cs {
                    case Nil =>
                        match cClose(s) {
                            case Outcome.Done(x, rest) =>
                                if (String.isEmpty(rest))
                                    (Ok(x), Cost.Cost(steps + 1, totalChars))
                                else
                                    (Err(ParseError.Error(
                                        MiniParse.Suspend.suspendedPos(s),
                                        "end of input" :: Nil
                                    )), Cost.Cost(steps + 1, totalChars))
                            case Outcome.Fail(e) =>
                                (Err(e), Cost.Cost(steps + 1, totalChars))
                            case Outcome.Await(_) =>
                                (Err(ParseError.Error(
                                    MiniParse.Suspend.suspendedPos(s),
                                    "end of input" :: Nil
                                )), Cost.Cost(steps + 1, totalChars))
                        }
                    case c :: rest =>
                        loop(rest, cFeed(c, s), steps + 1)
                }
        };
        match chunks {
            case Nil =>
                loop(Nil, start(p), 0)
            case c :: rest =>
                loop(rest, startWith(p, c), 0)
        }
    }

    /// Chunks `"1" :: "1" :: ...` length n (parses as n ones).
    pub def oneChunks(n: Int32): List[String] = {
        def loop(i: Int32, acc: List[String]): List[String] =
            if (i <= 0) acc else loop(i - 1, "1" :: acc);
        loop(n, Nil)
    }

    /// True when Stream re-scans strictly more characters than Suspend.
    pub def streamScansMore(n: Int32): Bool = {
        let chunks = oneChunks(n);
        match (streamDigitsCost(n, chunks), suspendDigitsCost(n, chunks)) {
            case ((Ok(_), cs), (Ok(_), cc)) =>
                visitsOf(cs) > visitsOf(cc)
            case _ =>
                false
        }
    }

    pub def triangular(n: Int32): Int32 =
        n * (n + 1) / 2

}
