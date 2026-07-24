///
/// Streaming demos: feed parsers in chunks via `MiniParse.Stream`.
///
mod Examples.StreamDemo {

    use MiniParse.Core.{Parser, ParseError}
    use MiniParse.Stream.{
        StreamState, Step, DriveEvent,
        open, feed, close, step, push, parseChunks, drive, compact, offset, buffer
    }
    use MiniParse.Combinator.{digits, string, map}
    use Examples.PostalCode.{PostalCode, postalCode}
    use Examples.Json.{JsonValue, jsonDoc}

    /// Chunked postal code: `"15" | "0-00" | "02"`.
    pub def parsePostalChunks(chunks: List[String]): Result[ParseError, PostalCode] =
        parseChunks(postalCode(), chunks)

    /// Chunked JSON document.
    pub def parseJsonChunks(chunks: List[String]): Result[ParseError, JsonValue] =
        parseChunks(jsonDoc(), chunks)

    /// Drive with event trace (for demos / tests).
    pub def drivePostal(chunks: List[String]): (Result[ParseError, PostalCode], List[DriveEvent]) =
        drive(postalCode(), chunks)

    pub def driveJson(chunks: List[String]): (Result[ParseError, JsonValue], List[DriveEvent]) =
        drive(jsonDoc(), chunks)

    /// Manual step loop: show Await until enough digits for `digits(3)`.
    pub def stepDigits3(chunks: List[String]): Result[ParseError, String] = {
        def loop(cs: List[String], s: StreamState): Result[ParseError, String] = match cs {
            case Nil =>
                match step(digits(3), close(s)) {
                    case Step.Done(x, _) => Ok(x)
                    case Step.Fail(e)    => Err(e)
                    case Step.Await(_)   => Err(ParseError.Error(
                        MiniParse.Core.initialPosition(),
                        "end of input" :: Nil
                    ))
                }
            case c :: rest =>
                match push(digits(3), c, s) {
                    case Step.Await(s1)  => loop(rest, s1)
                    case Step.Done(x, _) => Ok(x)
                    case Step.Fail(e)    => Err(e)
                }
        };
        loop(chunks, open())
    }

    /// Count how many `Await`s appear when driving `p` over `chunks`.
    pub def countAwaits(p: Parser[a], chunks: List[String]): Int32 = {
        let (_res, ev) = drive(p, chunks);
        List.length(List.filter(e -> match e {
            case DriveEvent.GotAwait => true
            case _                   => false
        }, ev))
    }

}
