///
/// Step 2: keywords vs identifiers — where Parsec and PEG philosophies diverge.
///
/// Problem: the keyword `if` is a prefix of the identifier `ifa`.
///
/// | Style | Strategy |
/// | --- | --- |
/// | **Naive Parsec** | `orElse(string("if"), ident)` — on `"ifa"`, `if` consumes input then
///   `eof` fails; because input was consumed, `orElse` never tries `ident`. |
/// | **Parsec + attempt** | Wrap the keyword in `attempt` and require a boundary. |
/// | **PEG** | Ordered choice with auto-backtrack, plus `!identChar` after the keyword. |
///
mod Examples.Keyword {

    use MiniParse.Core.{Parser, parse}
    use MiniParse.Combinator.{
        map, flatMap, andThen, andThenL, letter, alphaNum, many,
        charsToString, ws, lexeme, string
    }
    use MiniParse.Parsec.{orElse, attempt}
    use MiniParse.PEG.{choice, notPredicate}

    pub enum Token with Eq, ToString {
        case KwIf,
        case Ident(String)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Shared lexical bits
    ///////////////////////////////////////////////////////////////////////////

    def identStart(): Parser[Char] = letter()

    /// One or more identifier characters starting with a letter.
    pub def ident(): Parser[String] =
        lexeme(
            flatMap(c0 ->
                map(cs -> Char.toString(c0) + charsToString(cs),
                    many(alphaNum())),
                identStart())
        )

    def kwIfRaw(): Parser[String] = string("if")

    ///////////////////////////////////////////////////////////////////////////
    // Naive Parsec — demonstrates the classic trap
    ///////////////////////////////////////////////////////////////////////////

    /// `orElse("if", ident)` without attempt / boundary.
    ///
    /// Full parse of `"ifa"` **fails** even though `ifa` is a valid identifier:
    /// `"if"` consumes two characters, then end-of-input is required by `parse`
    /// and the second alternative is never tried.
    pub def naiveParsecToken(): Parser[Token] =
        orElse(
            map(_ -> Token.KwIf, lexeme(kwIfRaw())),
            map(Token.Ident, ident())
        )

    pub def parseNaiveParsec(input: String): Result[MiniParse.Core.ParseError, Token] =
        parse(andThen(ws(), andThenL(naiveParsecToken(), ws())), input)

    ///////////////////////////////////////////////////////////////////////////
    // Parsec with explicit attempt + boundary
    ///////////////////////////////////////////////////////////////////////////

    /// Keyword `if` only if not followed by an identifier character.
    ///
    /// Uses `attempt` so a failed boundary check rewinds and lets `ident` run.
    pub def parsecKeywordIf(): Parser[Token] =
        map(_ -> Token.KwIf,
            lexeme(
                attempt(
                    andThenL(
                        kwIfRaw(),
                        // Boundary: next char must not be alphanumeric (or EOF).
                        // Implemented by optional peek failure via attempt+alphaNum.
                        // If alphaNum succeeds, attempt fails and rewinds.
                        // We want NOT alphaNum — use attempt around a failing pattern:
                        // succeed when alphaNum fails at current pos without consume.
                        notIdentCharParsec()
                    )
                )
            )
        )

    /// Succeed without consuming when the next char is not alphanumeric.
    def notIdentCharParsec(): Parser[Unit] =
        // If alphaNum would match, fail (and with attempt outer, rewind).
        // If not, succeed.
        // We implement as: try alphaNum; if it matched we need to fail.
        // Without PEG notPredicate, use: optional(attempt(alphaNum)) then check.
        MiniParse.Core.mkParser(s0 ->
            match MiniParse.Core.runParser(alphaNum(), s0) {
                case Ok(_)  =>
                    // Would be ident char — fail *at s0* so attempt can rewind keyword.
                    Err(MiniParse.Core.ParseError.Error(
                        MiniParse.Core.statePos(s0),
                        "keyword boundary" :: Nil
                    ))
                case Err(_) =>
                    Ok(((), s0))
            }
        )

    pub def parsecToken(): Parser[Token] =
        orElse(parsecKeywordIf(), map(Token.Ident, ident()))

    pub def parseParsec(input: String): Result[MiniParse.Core.ParseError, Token] =
        parse(andThen(ws(), andThenL(parsecToken(), ws())), input)

    ///////////////////////////////////////////////////////////////////////////
    // PEG style — automatic backtrack + negative lookahead
    ///////////////////////////////////////////////////////////////////////////

    pub def pegKeywordIf(): Parser[Token] =
        map(_ -> Token.KwIf,
            lexeme(
                andThenL(kwIfRaw(), notPredicate(alphaNum()))
            )
        )

    pub def pegToken(): Parser[Token] =
        // choice auto-rewinds if keyword+boundary fails mid-way
        choice(pegKeywordIf(), map(Token.Ident, ident()))

    pub def parsePeg(input: String): Result[MiniParse.Core.ParseError, Token] =
        parse(andThen(ws(), andThenL(pegToken(), ws())), input)

}
