///
/// Human-readable diagnostics shared by pure parse, Stream, and Suspend.
///
/// | Situation | Helper |
/// | --- | --- |
/// | Hard syntax / mismatch error | `formatError` |
/// | Open stream still needs bytes | `formatNeedInput` |
/// | `Result[ParseError, _]` | `formatResult` |
/// | Stream `Step` | `formatStreamStep` |
/// | Suspend `Outcome` | `formatSuspendOutcome` |
///
mod MiniParse.ErrorFormat {

    use MiniParse.Core.{
        ParseError, Position,
        parseErrorPos, parseErrorExpected,
        positionLine, positionColumn, positionOffset
    }
    use MiniParse.Stream.{Step, buffer, cursor}
    use MiniParse.Suspend.{Outcome, suspendedPos}

    ///////////////////////////////////////////////////////////////////////////
    // Core formatters
    ///////////////////////////////////////////////////////////////////////////

    /// Format a hard parse failure against `input` (line, column, caret).
    pub def formatError(input: String, err: ParseError): String = {
        let pos = parseErrorPos(err);
        let expected = dedupe(parseErrorExpected(err));
        let expText = match expected {
            case Nil => "(unknown)"
            case xs  => List.join(" or ", xs)
        };
        header("parse error", pos) +
            "  expected: ${expText}\n" +
            snippet(input, pos)
    }

    /// Format "not enough input yet" (open stream / suspended parser).
    ///
    /// Distinct from `formatError` so demos and UIs can treat incomplete input
    /// differently from a committed syntax error.
    pub def formatNeedInput(input: String, pos: Position): String =
        header("incomplete input", pos) +
            "  expected: more input\n" +
            snippet(input, pos)

    /// Format `Ok` / `Err` uniformly.
    pub def formatResult(input: String, r: Result[ParseError, a]): String = match r {
        case Ok(_)  => "ok"
        case Err(e) => formatError(input, e)
    }

    /// Stream step with source text for Fail / Await context.
    pub def formatStreamStep(input: String, st: Step[a]): String = match st {
        case Step.Done(_, s) =>
            "done (offset ${positionOffset(cursor(s))})"
        case Step.Fail(e) =>
            formatError(input, e)
        case Step.Await(s) =>
            formatNeedInput(buffer(s), cursor(s))
    }

    /// Suspend outcome: `Done` / hard `Fail` / `Await` (need more chars).
    pub def formatSuspendOutcome(input: String, o: Outcome[a]): String = match o {
        case Outcome.Done(_, rest) =>
            if (String.isEmpty(rest))
                "done"
            else
                "done (leftover: \"${rest}\")"
        case Outcome.Fail(e) =>
            formatError(input, e)
        case Outcome.Await(s) =>
            formatNeedInput(input, suspendedPos(s))
    }

    ///////////////////////////////////////////////////////////////////////////
    // Snippet helpers
    ///////////////////////////////////////////////////////////////////////////

    def header(kind: String, pos: Position): String = {
        let line = positionLine(pos);
        let col = positionColumn(pos);
        "${kind} at line ${line}, column ${col} (offset ${positionOffset(pos)})\n"
    }

    def snippet(input: String, pos: Position): String = {
        let line = positionLine(pos);
        let col = positionColumn(pos);
        let srcLine = lineAt(input, line);
        let caret = String.repeat(Int32.max(0, col - 1), " ") + "^";
        "  | ${srcLine}\n" +
            "  | ${caret}"
    }

    /// Extract the 1-based `lineNo` line from `input` (without trailing newline).
    pub def lineAt(input: String, lineNo: Int32): String = {
        def loop(off: Int32, cur: Int32, start: Int32): String =
            match String.nth(off, input) {
                case None =>
                    String.slice(start = start, end = String.length(input), input)
                case Some('\n') =>
                    if (cur == lineNo)
                        String.slice(start = start, end = off, input)
                    else
                        loop(off + 1, cur + 1, off + 1)
                case Some(_) =>
                    loop(off + 1, cur, start)
            };
        if (lineNo < 1)
            ""
        else
            loop(0, 1, 0)
    }

    /// Stable unique expected labels (order preserved).
    pub def dedupe(xs: List[String]): List[String] = {
        def loop(rest: List[String], seen: List[String], acc: List[String]): List[String] =
            match rest {
                case Nil => List.reverse(acc)
                case h :: t =>
                    if (List.memberOf(h, seen))
                        loop(t, seen, acc)
                    else
                        loop(t, h :: seen, h :: acc)
            };
        loop(xs, Nil, Nil)
    }

}
