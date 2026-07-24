///
/// Demo: coroutine suspension vs restart-style streaming.
///
/// Grammar: Japanese-style postal code `ddd-dddd` (no 〒 for simplicity).
/// Built entirely as `CoParser` so mid-digit waits capture a true continuation.
///
mod Examples.SuspendDemo {

    use MiniParse.Core.{ParseError}
    use MiniParse.Suspend.{
        CoParser, Outcome, Event, Suspended,
        pure, map, flatMap, andThen, char, digits, start, feed, close,
        parseChunks, drive, countSuspends, startWith
    }

    pub enum Postal with Eq, ToString {
        case Postal(String, String) // area, local
    }

    /// `ddd-dddd` as a suspendable coroutine parser.
    pub def postal(): CoParser[Postal] =
        flatMap(area ->
            andThen(char('-'),
                map(local -> Postal.Postal(area, local),
                    digits(4))),
            digits(3))

    pub def parsePostalChunks(chunks: List[String]): Result[ParseError, Postal] =
        parseChunks(postal(), chunks)

    pub def drivePostal(chunks: List[String]): (Result[ParseError, Postal], List[Event]) =
        drive(postal(), chunks)

    /// Step-by-step manual feed (for tests): returns number of suspensions.
    pub def manualFeedCount(chunks: List[String]): Result[ParseError, (Postal, Int32)] = {
        def loop(cs: List[String], o: Outcome[Postal], n: Int32): Result[ParseError, (Postal, Int32)] =
            match (cs, o) {
                case (_, Outcome.Fail(e)) =>
                    Err(e)
                case (Nil, Outcome.Done(x, rest)) =>
                    if (String.isEmpty(rest)) Ok((x, n))
                    else Err(ParseError.Error(
                        MiniParse.Core.initialPosition(),
                        "end of input" :: Nil
                    ))
                case (Nil, Outcome.Await(s)) =>
                    match close(s) {
                        case Outcome.Done(x, rest) =>
                            if (String.isEmpty(rest)) Ok((x, n))
                            else Err(ParseError.Error(
                                MiniParse.Core.initialPosition(),
                                "end of input" :: Nil
                            ))
                        case Outcome.Fail(e) => Err(e)
                        case Outcome.Await(_) =>
                            Err(ParseError.Error(
                                MiniParse.Core.initialPosition(),
                                "end of input" :: Nil
                            ))
                    }
                case (c :: rest, Outcome.Await(s)) =>
                    loop(rest, feed(c, s), n + 1)
                case (_ :: _, Outcome.Done(x, rest)) =>
                    if (String.isEmpty(rest)) Ok((x, n))
                    else Err(ParseError.Error(
                        MiniParse.Core.initialPosition(),
                        "end of input" :: Nil
                    ))
            };
        loop(chunks, start(postal()), 0)
    }

    /// Fixed three-digit example used to show suspension mid-token.
    pub def threeDigits(): CoParser[String] =
        digits(3)

}
