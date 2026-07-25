///
/// Debug helpers for pure `Parser` without a monad-transformer stack.
///
/// ## Two layers
///
/// 1. **Lightweight** (stay on `Parser[a]`):
///    - `getPos` — current position, no consume
///    - `label` — Parsec-style `<?>` (rewrite expected on failure)
///    - `inContext` — prefix expected labels with a rule name
///
/// 2. **Traced** (`TParser[a]`):
///    - Same monadic shape as `Parser`, but every run returns a `List[TraceEvent]`
///      **even on failure** (Writer-like, without stacking transformers)
///    - `span(name, p)` records enter / ok / fail around a sub-parser
///    - `lift` embeds an ordinary `Parser`
///    - `orElse` always backtracks (PEG-style) so failed alternatives stay in the log
///
/// Prefer `label` / better expecteds for everyday diagnostics; reach for `TParser`
/// when you need a step-by-step enter/exit trail of which rules ran.
///
mod MiniParse.Debug {

    use MiniParse.Core.{
        Parser, ParseError, State, Position,
        runParser, mkParser,
        initState, statePos, stateOffset, stateInput,
        parseErrorPos, parseErrorExpected, mergeError,
        positionLine, positionColumn
    }

    ///////////////////////////////////////////////////////////////////////////
    // Lightweight helpers on pure Parser
    ///////////////////////////////////////////////////////////////////////////

    /// Current source position; does not consume input.
    pub def getPos(): Parser[Position] =
        mkParser(s -> Ok((statePos(s), s)))

    /// On failure, replace expected labels with `name` (Parsec `<?>`).
    ///
    /// Furthest-error position from `p` is kept.
    pub def label(name: String, p: Parser[a]): Parser[a] =
        mkParser(s -> match runParser(p, s) {
            case Ok(v)  => Ok(v)
            case Err(e) =>
                Err(ParseError.Error(parseErrorPos(e), name :: Nil))
        })

    /// On failure, prefix each expected label with `ctx: ` (rule context).
    pub def inContext(ctx: String, p: Parser[a]): Parser[a] =
        mkParser(s -> match runParser(p, s) {
            case Ok(v)  => Ok(v)
            case Err(e) =>
                let exps = List.map(x -> "${ctx}: ${x}", parseErrorExpected(e));
                Err(ParseError.Error(parseErrorPos(e), exps))
        })

    ///////////////////////////////////////////////////////////////////////////
    // Trace events + TParser
    ///////////////////////////////////////////////////////////////////////////

    /// One step in a traced parse (chronological order in the event list).
    pub enum TraceEvent with Eq, ToString {
        case Enter(String, Position),
        case Ok(String, Position),
        case Fail(String, Position, List[String])
    }

    /// Instrumented parser: always yields a trace alongside the usual result.
    pub enum TParser[a] {
        case TParser(State -> (List[TraceEvent], Result[ParseError, (a, State)]))
    }

    pub def runTParser(
        p: TParser[a],
        s: State
    ): (List[TraceEvent], Result[ParseError, (a, State)]) =
        match p {
            case TParser.TParser(f) => f(s)
        }

    /// Low-level constructor.
    pub def mkTParser(
        f: State -> (List[TraceEvent], Result[ParseError, (a, State)])
    ): TParser[a] =
        TParser.TParser(f)

    /// Run with full input consumption (like `Core.parse`).
    pub def parseTraced(
        p: TParser[a],
        input: String
    ): (List[TraceEvent], Result[ParseError, a]) = {
        let (ev, r) = runTParser(p, initState(input));
        match r {
            case Ok((x, s1)) =>
                let off = stateOffset(s1);
                if (off >= String.length(stateInput(s1)))
                    (ev, Ok(x))
                else {
                    let e = ParseError.Error(statePos(s1), "end of input" :: Nil);
                    let ev1 = ev ::: TraceEvent.Fail("eof", statePos(s1), "end of input" :: Nil) :: Nil;
                    (ev1, Err(e))
                }
            case Err(e) => (ev, Err(e))
        }
    }

    /// Run allowing leftover input (like `Core.parsePartial`).
    pub def parsePartialTraced(
        p: TParser[a],
        input: String
    ): (List[TraceEvent], Result[ParseError, (a, State)]) =
        runTParser(p, initState(input))

    /// Embed a pure `Parser` (empty trace for that fragment).
    pub def lift(p: Parser[a]): TParser[a] =
        mkTParser(s -> (Nil, runParser(p, s)))

    /// Record enter / ok / fail around `p` under `name`.
    ///
    /// Child events sit between enter and the matching exit event.
    pub def span(name: String, p: TParser[a]): TParser[a] =
        mkTParser(s0 -> {
            let pos0 = statePos(s0);
            let enter = TraceEvent.Enter(name, pos0);
            match runTParser(p, s0) {
                case (ev, Ok((x, s1))) =>
                    let exit = TraceEvent.Ok(name, statePos(s1));
                    (enter :: (ev ::: exit :: Nil), Ok((x, s1)))
                case (ev, Err(e)) =>
                    let exit = TraceEvent.Fail(
                        name,
                        parseErrorPos(e),
                        parseErrorExpected(e)
                    );
                    (enter :: (ev ::: exit :: Nil), Err(e))
            }
        })

    /// Convenience: `span(name, lift(p))`.
    pub def spanP(name: String, p: Parser[a]): TParser[a] =
        span(name, lift(p))

    ///////////////////////////////////////////////////////////////////////////
    // TParser combinators (minimal set)
    ///////////////////////////////////////////////////////////////////////////

    pub def pure(x: a): TParser[a] =
        lift(MiniParse.Core.pure(x))

    pub def fail(expected: String): TParser[a] =
        lift(MiniParse.Core.fail(expected))

    pub def map(f: a -> b, p: TParser[a]): TParser[b] =
        mkTParser(s -> match runTParser(p, s) {
            case (ev, Ok((x, s1))) => (ev, Ok((f(x), s1)))
            case (ev, Err(e))      => (ev, Err(e))
        })

    pub def flatMap(f: a -> TParser[b], p: TParser[a]): TParser[b] =
        mkTParser(s -> match runTParser(p, s) {
            case (ev1, Ok((x, s1))) =>
                match runTParser(f(x), s1) {
                    case (ev2, r) => (ev1 ::: ev2, r)
                }
            case (ev1, Err(e)) => (ev1, Err(e))
        })

    pub def andThen(p: TParser[a], q: TParser[b]): TParser[b] =
        flatMap(_ -> q, p)

    pub def andThenL(p: TParser[a], q: TParser[b]): TParser[a] =
        flatMap(x -> map(_ -> x, q), p)

    pub def product(p: TParser[a], q: TParser[b]): TParser[(a, b)] =
        flatMap(x -> map(y -> (x, y), q), p)

    /// Ordered choice with **automatic** backtrack (PEG-style).
    ///
    /// Failed left-branch events are kept, then right-branch events follow.
    /// Useful when debugging which alternative was tried.
    pub def orElse(p1: TParser[a], p2: TParser[a]): TParser[a] =
        mkTParser(s0 -> {
            let (t1, r1) = runTParser(p1, s0);
            match r1 {
                case Ok(v) => (t1, Ok(v))
                case Err(e1) => {
                    let (t2, r2) = runTParser(p2, s0);
                    match r2 {
                        case Ok(v)   => (t1 ::: t2, Ok(v))
                        case Err(e2) => (t1 ::: t2, Err(mergeError(e1, e2)))
                    }
                }
            }
        })

    pub def choice(ps: List[TParser[a]]): TParser[a] = match ps {
        case Nil         => fail("empty choice")
        case p :: Nil    => p
        case p :: q :: r => orElse(p, choice(q :: r))
    }

    /// Rewrite expected labels on failure (same idea as `label` on `Parser`).
    pub def tlabel(name: String, p: TParser[a]): TParser[a] =
        mkTParser(s -> match runTParser(p, s) {
            case (ev, Ok(v))  => (ev, Ok(v))
            case (ev, Err(e)) =>
                (ev, Err(ParseError.Error(parseErrorPos(e), name :: Nil)))
        })

    ///////////////////////////////////////////////////////////////////////////
    // Formatting
    ///////////////////////////////////////////////////////////////////////////

    def posStr(p: Position): String =
        "${positionLine(p)}:${positionColumn(p)}"

    /// One event per line (`→` enter, `← ok` / `← fail`).
    pub def formatTrace(events: List[TraceEvent]): String =
        List.join("\n", List.map(formatEvent, events))

    pub def formatEvent(e: TraceEvent): String = match e {
        case TraceEvent.Enter(name, pos) =>
            "→ ${name} @ ${posStr(pos)}"
        case TraceEvent.Ok(name, pos) =>
            "← ${name} ok @ ${posStr(pos)}"
        case TraceEvent.Fail(name, pos, expected) =>
            let exp = match expected {
                case Nil => "(unknown)"
                case xs  => List.join(" or ", xs)
            };
            "← ${name} fail @ ${posStr(pos)} expected ${exp}"
    }

    /// Trace block + success value or formatted hard error.
    pub def formatTraced(
        input: String,
        events: List[TraceEvent],
        result: Result[ParseError, a]
    ): String with ToString[a] = {
        let body = match result {
            case Ok(x)  => "result: Ok(${x})"
            case Err(e) => "result: Err\n" + MiniParse.ErrorFormat.formatError(input, e)
        };
        let tr = match events {
            case Nil => "(no trace events)"
            case _   => formatTrace(events)
        };
        "trace:\n${tr}\n\n${body}"
    }

    /// Drop all `Enter`/`Ok` and keep only failures (quick scan).
    pub def failuresOnly(events: List[TraceEvent]): List[TraceEvent] =
        List.filter(e -> match e {
            case TraceEvent.Fail(_, _, _) => true
            case _                        => false
        }, events)

    /// Names of spans that recorded `Fail` (order preserved).
    pub def failedSpans(events: List[TraceEvent]): List[String] =
        List.flatMap(e -> match e {
            case TraceEvent.Fail(name, _, _) => name :: Nil
            case _                           => Nil
        }, events)

}
