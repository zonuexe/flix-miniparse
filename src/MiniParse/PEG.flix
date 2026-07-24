///
/// PEG-style front-end: automatic backtracking and syntactic predicates.
///
mod MiniParse.PEG {

    use MiniParse.Core.{
        Parser, ParseError, State,
        runParser, mkParser, pure, statePos
    }
    use MiniParse.Parsec.{orElse, attempt}

    /// Ordered choice with automatic rewind (PEG `/`).
    ///
    /// Equivalent to `orElse(attempt(p1), p2)`.
    pub def choice(p1: Parser[a], p2: Parser[a]): Parser[a] =
        orElse(attempt(p1), p2)

    /// Multi-way ordered choice.
    pub def choices(ps: List[Parser[a]]): Parser[a] = match ps {
        case Nil         => MiniParse.Core.fail("empty choice")
        case p :: Nil    => p
        case p :: q :: r => choice(p, choices(q :: r))
    }

    /// Positive lookahead (`&p`): succeed with `p`'s value without consuming.
    pub def andPredicate(p: Parser[a]): Parser[a] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok((x, _s1)) => Ok((x, s0))
                case Err(e)       => Err(e)
            }
        )

    /// Negative lookahead (`!p`): succeed with `()` if `p` fails; never consume.
    pub def notPredicate(p: Parser[a]): Parser[Unit] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok(_)  =>
                    Err(ParseError.Error(statePos(s0), "negative lookahead" :: Nil))
                case Err(_) =>
                    Ok(((), s0))
            }
        )

    /// Succeed only if `p` fails (alias of `notPredicate` for readability).
    pub def notFollowedBy(p: Parser[a]): Parser[Unit] =
        notPredicate(p)

}
