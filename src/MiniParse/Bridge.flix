///
/// Bridge between pure `Parser` and suspendable `CoParser`.
///
/// ```text
///   CoParser  ──toParser──►  Parser   (remainder of State is fully available)
///   Parser    ──fromParser─►  CoParser (buffer until EOF, then run pure parse)
/// ```
///
/// ## Semantics (important)
///
/// ### `toParser` (Co → pure)
/// Interprets the free `Read`/`Choice` program against the pure buffer with
/// `eof = true`. Suspension (`Await`) becomes a hard end-of-input error.
/// Deep backtracking `orElse` still works. The resulting `Parser` composes
/// with `MiniParse.Combinator` / Parsec / PEG.
///
/// ### `fromParser` (pure → Co)
/// A pure `Parser` is a black-box function of a finished string slice; it has
/// no per-character suspension points. Embedding it as a `CoParser` therefore:
/// 1. reads **all** characters until EOF into a string, then
/// 2. runs the pure parser on that string.
///
/// Mid-chunk suspension only happens while gathering characters, not inside
/// the pure parser's own control flow.
///
mod MiniParse.Bridge {

    use MiniParse.Core.{
        Parser, ParseError, State, parse, parsePartial, parseErrorExpected
    }
    use MiniParse.Suspend.{
        CoParser, pure => cPure, fail => cFail, map, flatMap
    }

    ///////////////////////////////////////////////////////////////////////////
    // CoParser → pure Parser
    ///////////////////////////////////////////////////////////////////////////

    /// See `MiniParse.Suspend.toParser`.
    pub def toParser(p: CoParser[a]): Parser[a] =
        MiniParse.Suspend.toParser(p)

    /// `Core.parse(toParser(p), input)`.
    pub def parseCo(p: CoParser[a], input: String): Result[ParseError, a] =
        MiniParse.Suspend.runCo(p, input)

    /// Partial pure run of a CoParser.
    pub def parseCoPartial(p: CoParser[a], s: State): Result[ParseError, (a, State)] =
        MiniParse.Suspend.runCoPartial(p, s)

    ///////////////////////////////////////////////////////////////////////////
    // pure Parser → CoParser
    ///////////////////////////////////////////////////////////////////////////

    /// Read every character until EOF, then run pure `p` on the collected string.
    pub def fromParser(p: Parser[a]): CoParser[a] =
        flatMap(s -> match parse(p, s) {
            case Ok(x) => cPure(x)
            case Err(e) =>
                match parseErrorExpected(e) {
                    case h :: _ => cFail(h)
                    case Nil    => cFail("parse error")
                }
        }, readToEnd())

    /// Like `fromParser`, but uses `parsePartial` and ignores trailing unread
    /// input inside the pure parser (still requires CoParser EOF to finish gathering).
    pub def fromParserPartial(p: Parser[a]): CoParser[a] =
        flatMap(s -> match parsePartial(p, s) {
            case Ok((x, _)) => cPure(x)
            case Err(e) =>
                match parseErrorExpected(e) {
                    case h :: _ => cFail(h)
                    case Nil    => cFail("parse error")
                }
        }, readToEnd())

    /// Drain the CoParser input stream into a `String` (stops at EOF).
    pub def readToEnd(): CoParser[String] =
        CoParser.Read(mc -> match mc {
            case None =>
                CoParser.Pure("")
            case Some(c) =>
                map(rest -> Char.toString(c) + rest, readToEnd())
        })

    ///////////////////////////////////////////////////////////////////////////
    // Round-trip helpers (educational checks)
    ///////////////////////////////////////////////////////////////////////////

    /// Pure parse of `input` after compiling `co` with `toParser`.
    pub def coViaPure(co: CoParser[a], input: String): Result[ParseError, a] =
        parse(toParser(co), input)

    /// CoParser path: gather full input then run pure `p` (via `fromParser`).
    pub def pureViaCo(p: Parser[a], input: String): Result[ParseError, a] =
        MiniParse.Suspend.runCo(fromParser(p), input)

}
