///
/// Core engine: input state, positions, parse errors, and the `Parser` type.
///
mod MiniParse.Core {

    /// Source position (0-based offset; 1-based line and column).
    pub enum Position with Eq, Order, ToString {
        case Position(Int32, Int32, Int32) // offset, line, column
    }

    pub def positionOffset(p: Position): Int32 = match p {
        case Position.Position(offset, _line, _column) => offset
    }

    pub def positionLine(p: Position): Int32 = match p {
        case Position.Position(_offset, line, _column) => line
    }

    pub def positionColumn(p: Position): Int32 = match p {
        case Position.Position(_offset, _line, column) => column
    }

    pub def initialPosition(): Position =
        Position.Position(0, 1, 1)

    /// Advance one character, updating line/column on newlines.
    pub def advancePosition(c: Char, p: Position): Position = match p {
        case Position.Position(offset, line, column) =>
            if (c == '\n')
                Position.Position(offset + 1, line + 1, 1)
            else
                Position.Position(offset + 1, line, column + 1)
    }

    /// A parse failure: furthest position and what was expected there.
    pub enum ParseError with Eq, ToString {
        case Error(Position, List[String]) // pos, expected
    }

    pub def parseErrorPos(e: ParseError): Position = match e {
        case ParseError.Error(pos, _expected) => pos
    }

    pub def parseErrorExpected(e: ParseError): List[String] = match e {
        case ParseError.Error(_pos, expected) => expected
    }

    /// Prefer the error that reached farther into the input (for choice later).
    pub def mergeError(e1: ParseError, e2: ParseError): ParseError = {
        let o1 = positionOffset(parseErrorPos(e1));
        let o2 = positionOffset(parseErrorPos(e2));
        if (o1 > o2)
            e1
        else if (o2 > o1)
            e2
        else
            match (e1, e2) {
                case (ParseError.Error(pos, exp1), ParseError.Error(_pos2, exp2)) =>
                    ParseError.Error(pos, exp1 ::: exp2)
            }
    }

    /// Immutable parse state.
    pub enum State with Eq, ToString {
        case State(String, Position) // input, pos
    }

    pub def stateInput(s: State): String = match s {
        case State.State(input, _pos) => input
    }

    pub def statePos(s: State): Position = match s {
        case State.State(_input, pos) => pos
    }

    pub def stateOffset(s: State): Int32 =
        positionOffset(statePos(s))

    pub def initState(input: String): State =
        State.State(input, initialPosition())

    /// A pure parser: `State -> Result[ParseError, (a, State)]`.
    ///
    /// Nominal wrapper so the library can evolve without changing call sites.
    pub enum Parser[a] {
        case Parser(State -> Result[ParseError, (a, State)])
    }

    /// Run a parser on the given state.
    ///
    /// Named `runParser` because `run` is reserved for effect handlers.
    pub def runParser(p: Parser[a], s: State): Result[ParseError, (a, State)] =
        match p {
            case Parser.Parser(f) => f(s)
        }

    /// Run `p` on `input` and require that the entire input is consumed.
    pub def parse(p: Parser[a], input: String): Result[ParseError, a] =
        match runParser(p, initState(input)) {
            case Ok((x, s1)) =>
                let off = stateOffset(s1);
                if (off >= String.length(stateInput(s1)))
                    Ok(x)
                else
                    Err(ParseError.Error(statePos(s1), "end of input" :: Nil))
            case Err(e) => Err(e)
        }

    /// Run `p` on `input`; leftover input is allowed.
    pub def parsePartial(p: Parser[a], input: String): Result[ParseError, (a, State)] =
        runParser(p, initState(input))

    /// Lift a pure value into a parser (no input consumed).
    pub def pure(x: a): Parser[a] =
        Parser.Parser(s -> Ok((x, s)))

    /// Always fail at the current position with the given expectation label.
    pub def fail(expected: String): Parser[a] =
        Parser.Parser(s ->
            Err(ParseError.Error(statePos(s), expected :: Nil))
        )

    /// On failure after consuming input, restore the position from before `p`.
    ///
    /// This is the primitive behind Parsec `try` and PEG ordered choice.
    pub def rollback(p: Parser[a]): Parser[a] =
        Parser.Parser(s0 ->
            match runParser(p, s0) {
                case Ok(v)  => Ok(v)
                case Err(e) =>
                    // Restore input position; keep the original error (furthest pos).
                    Err(e)
                    // Note: we intentionally do not mutate s0; callers re-run from s0.
                    // The rewind is "not advancing state on Err", which `orElse` uses.
            }
        )

    /// Low-level constructor for combinators in other modules.
    pub def mkParser(f: State -> Result[ParseError, (a, State)]): Parser[a] =
        Parser.Parser(f)

}
