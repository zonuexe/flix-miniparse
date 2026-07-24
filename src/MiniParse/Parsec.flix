///
/// Parsec-style front-end: predictive parsing with *explicit* backtracking.
///
/// `orElse` does **not** retry the second alternative if the first failed after
/// consuming input. Wrap with `attempt` (Parsec's `try`) when backtracking is
/// intended.
///
mod MiniParse.Parsec {

    use MiniParse.Core.{
        Parser, ParseError, State,
        runParser, mkParser, mergeError, stateOffset, statePos, parseErrorPos, parseErrorExpected
    }

    /// Choice without automatic backtrack (LL(1)-like).
    ///
    /// If `p1` fails **after consuming input**, `p2` is not tried.
    pub def orElse(p1: Parser[a], p2: Parser[a]): Parser[a] =
        mkParser(s0 ->
            match runParser(p1, s0) {
                case Ok(v) => Ok(v)
                case Err(e1) =>
                    if (positionOffset(parseErrorPos(e1)) > stateOffset(s0))
                        // Consumed: commit to this failure (no backtrack).
                        Err(e1)
                    else
                        match runParser(p2, s0) {
                            case Ok(v)   => Ok(v)
                            case Err(e2) => Err(mergeError(e1, e2))
                        }
            }
        )

    /// Explicit backtracking wrapper (Parsec's `try`).
    ///
    /// On failure, rewrites the error position to the start of `p` so that
    /// `orElse` will consider the next alternative. The original expectation
    /// labels are preserved for error messages.
    pub def attempt(p: Parser[a]): Parser[a] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok(v)  => Ok(v)
                case Err(e) =>
                    Err(ParseError.Error(statePos(s0), parseErrorExpected(e)))
            }
        )

    /// Left-associative multi-way choice (still no automatic backtrack).
    pub def choice(ps: List[Parser[a]]): Parser[a] = match ps {
        case Nil         => MiniParse.Core.fail("empty choice")
        case p :: Nil    => p
        case p :: q :: r => orElse(p, choice(q :: r))
    }

    def positionOffset(p: MiniParse.Core.Position): Int32 =
        MiniParse.Core.positionOffset(p)

}
