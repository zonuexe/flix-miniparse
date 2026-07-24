///
/// Shared combinators built on `MiniParse.Core`.
///
mod MiniParse.Combinator {

    use MiniParse.Core.{
        Parser, State, Position, ParseError,
        runParser, pure, fail, mkParser,
        stateOffset, advancePosition
    }

    ///////////////////////////////////////////////////////////////////////////
    // Functor / Monad
    ///////////////////////////////////////////////////////////////////////////

    pub def map(f: a -> b, p: Parser[a]): Parser[b] =
        mkParser(s -> match runParser(p, s) {
            case Ok((x, s1)) => Ok((f(x), s1))
            case Err(e)      => Err(e)
        })

    pub def flatMap(f: a -> Parser[b], p: Parser[a]): Parser[b] =
        mkParser(s -> match runParser(p, s) {
            case Ok((x, s1)) => runParser(f(x), s1)
            case Err(e)      => Err(e)
        })

    /// Defer building a parser until it is run (breaks recursive construction cycles).
    pub def delay(thunk: Unit -> Parser[a]): Parser[a] =
        mkParser(s -> runParser(thunk(), s))

    /// Sequence: run `p` then `q`, keep both results.
    pub def product(p: Parser[a], q: Parser[b]): Parser[(a, b)] =
        flatMap(x -> map(y -> (x, y), q), p)

    /// Run `p` then `q`, keep only `q`'s result (`*>`).
    pub def andThen(p: Parser[a], q: Parser[b]): Parser[b] =
        flatMap(_ -> q, p)

    /// Run `p` then `q`, keep only `p`'s result (`<*`).
    pub def andThenL(p: Parser[a], q: Parser[b]): Parser[a] =
        flatMap(x -> map(_ -> x, q), p)

    ///////////////////////////////////////////////////////////////////////////
    // Character-level primitives
    ///////////////////////////////////////////////////////////////////////////

    /// Succeed with the next character if `pred` holds.
    pub def satisfy(pred: Char -> Bool, label: String): Parser[Char] =
        mkParser(s -> match s {
            case State.State(input, pos) =>
                let off = match pos {
                    case Position.Position(o, _l, _c) => o
                };
                match String.nth(off, input) {
                    case None =>
                        Err(ParseError.Error(pos, label :: Nil))
                    case Some(c) =>
                        if (pred(c)) {
                            let pos1 = advancePosition(c, pos);
                            Ok((c, State.State(input, pos1)))
                        } else
                            Err(ParseError.Error(pos, label :: Nil))
                }
        })

    /// Match an exact character.
    pub def char(expected: Char): Parser[Char] =
        satisfy(c -> c == expected, Char.toString(expected))

    /// Match an ASCII digit (`0`–`9`).
    pub def digit(): Parser[Char] =
        satisfy(Char.isAsciiDigit, "digit")

    /// Match an ASCII letter (`A`–`Z`, `a`–`z`).
    pub def letter(): Parser[Char] =
        satisfy(c -> Char.isAscii(c) and Char.isLetter(c), "letter")

    /// Letter or digit (ASCII letter or digit).
    pub def alphaNum(): Parser[Char] =
        satisfy(c -> (Char.isAscii(c) and Char.isLetter(c)) or Char.isAsciiDigit(c), "alphanumeric")

    /// Match end of input.
    pub def eof(): Parser[Unit] =
        mkParser(s -> match s {
            case State.State(input, pos) =>
                let off = match pos {
                    case Position.Position(o, _l, _c) => o
                };
                if (off >= String.length(input))
                    Ok(((), s))
                else
                    Err(ParseError.Error(pos, "end of input" :: Nil))
        })

    /// Match a non-empty literal string, character by character.
    pub def string(lit: String): Parser[String] = {
        let n = String.length(lit);
        def loop(i: Int32): Parser[String] =
            if (i >= n)
                pure(lit)
            else
                match String.nth(i, lit) {
                    case None    => fail("string")
                    case Some(c) => andThen(char(c), loop(i + 1))
                };
        if (n == 0)
            pure("")
        else
            loop(0)
    }

    ///////////////////////////////////////////////////////////////////////////
    // Repetition
    ///////////////////////////////////////////////////////////////////////////

    /// Apply `p` exactly `n` times; collect results in a list.
    pub def count(n: Int32, p: Parser[a]): Parser[List[a]] =
        if (n <= 0)
            pure(Nil)
        else
            flatMap(x -> map(xs -> x :: xs, count(n - 1, p)), p)

    /// Zero or more; always succeeds.
    pub def many(p: Parser[a]): Parser[List[a]] =
        mkParser(s0 -> {
            def loop(s: State, acc: List[a]): Result[ParseError, (List[a], State)] =
                match runParser(p, s) {
                    case Ok((x, s1)) =>
                        // Progress guard: refuse infinite loops on empty matches.
                        if (stateOffset(s1) == stateOffset(s))
                            Ok((List.reverse(acc), s))
                        else
                            loop(s1, x :: acc)
                    case Err(_) =>
                        Ok((List.reverse(acc), s))
                };
            loop(s0, Nil)
        })

    /// One or more.
    pub def some(p: Parser[a]): Parser[List[a]] =
        flatMap(x -> map(xs -> x :: xs, many(p)), p)

    /// Optional parser: `None` on failure without consuming (via non-consuming fail).
    ///
    /// If `p` fails after consuming input, the failure is propagated (Parsec-like).
    /// Use `Core.rollback` / Parsec `try` when optional backtrack is needed.
    pub def optional(p: Parser[a]): Parser[Option[a]] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok((x, s1)) => Ok((Some(x), s1))
                case Err(e) =>
                    if (positionOffset(parseErrorPos(e)) == stateOffset(s0))
                        Ok((None, s0))
                    else
                        Err(e)
            }
        )

    def positionOffset(p: Position): Int32 = match p {
        case Position.Position(offset, _line, _column) => offset
    }

    def parseErrorPos(e: ParseError): Position = match e {
        case ParseError.Error(pos, _expected) => pos
    }

    ///////////////////////////////////////////////////////////////////////////
    // Helpers
    ///////////////////////////////////////////////////////////////////////////

    /// Parse `n` digits into a string.
    pub def digits(n: Int32): Parser[String] =
        map(charsToString, count(n, digit()))

    pub def charsToString(cs: List[Char]): String =
        List.join("", List.map(Char.toString, cs))

    ///////////////////////////////////////////////////////////////////////////
    // Lexical helpers (JSON / general)
    ///////////////////////////////////////////////////////////////////////////

    /// One whitespace character (space, tab, CR, LF).
    pub def spaceChar(): Parser[Char] =
        satisfy(c -> c == ' ' or c == '\t' or c == '\n' or c == '\r', "whitespace")

    /// Zero or more whitespace characters.
    pub def ws(): Parser[Unit] =
        map(_ -> (), many(spaceChar()))

    /// Run `p` then skip trailing whitespace.
    pub def lexeme(p: Parser[a]): Parser[a] =
        andThenL(p, ws())

    /// Match a literal string as a token (with trailing whitespace).
    pub def symbol(lit: String): Parser[String] =
        lexeme(string(lit))

    /// `open_ p close_` — discard delimiters, keep `p`.
    pub def between(open_: Parser[a], close_: Parser[b], p: Parser[c]): Parser[c] =
        andThen(open_, andThenL(p, close_))

    /// Zero or more `p` separated by `sep`.
    pub def sepBy(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        MiniParse.Parsec.orElse(sepBy1(p, sep), pure(Nil))

    /// One or more `p` separated by `sep`.
    pub def sepBy1(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        flatMap(x ->
            map(xs -> x :: xs, many(andThen(sep, p))),
            p
        )

    /// Fold a left-associative binary operator (for Step 2 arithmetic).
    pub def chainl1(p: Parser[a], op: Parser[(a, a) -> a]): Parser[a] =
        flatMap(x ->
            map(fs -> List.foldLeft((acc, f) -> f(acc), x, fs),
                many(flatMap(f -> map(y -> (acc -> f(acc, y)), p), op))),
            p
        )

    /// Fold a right-associative binary operator.
    pub def chainr1(p: Parser[a], op: Parser[(a, a) -> a]): Parser[a] =
        flatMap(x ->
            MiniParse.Parsec.orElse(
                flatMap(f -> map(y -> f(x, y), chainr1(p, op)), op),
                pure(x)
            ),
            p
        )

    ///////////////////////////////////////////////////////////////////////////
    // More character primitives
    ///////////////////////////////////////////////////////////////////////////

    /// Any single character.
    pub def anyChar(): Parser[Char] =
        satisfy(_ -> true, "any character")

    /// Character from the set `cs` (each code unit is one candidate).
    pub def oneOf(cs: String): Parser[Char] =
        satisfy(c -> charIn(c, cs), "one of `${cs}`")

    /// Character not in the set `cs`.
    pub def noneOf(cs: String): Parser[Char] =
        satisfy(c -> not charIn(c, cs), "none of `${cs}`")

    def charIn(c: Char, s: String): Bool = {
        def loop(i: Int32): Bool =
            match String.nth(i, s) {
                case None    => false
                case Some(d) => if (d == c) true else loop(i + 1)
            };
        loop(0)
    }

    /// ASCII hex digit.
    pub def hexDigit(): Parser[Char] =
        satisfy(Char.isHexDigit, "hex digit")

    /// End of line: `\n`, `\r\n`, or `\r`.
    pub def endOfLine(): Parser[Unit] =
        MiniParse.Parsec.orElse(
            map(_ -> (), string("\r\n")),
            MiniParse.Parsec.orElse(
                map(_ -> (), char('\n')),
                map(_ -> (), char('\r'))
            )
        )

    /// Zero or more characters matching `pred`, as a string.
    pub def takeWhile(pred: Char -> Bool): Parser[String] =
        map(charsToString, many(satisfy(pred, "takeWhile")))

    /// One or more characters matching `pred`, as a string.
    pub def takeWhile1(pred: Char -> Bool): Parser[String] =
        map(charsToString, some(satisfy(pred, "takeWhile1")))

    ///////////////////////////////////////////////////////////////////////////
    // Lookahead, skip, replace
    ///////////////////////////////////////////////////////////////////////////

    /// Run `p` without consuming input on success (positive lookahead).
    pub def lookAhead(p: Parser[a]): Parser[a] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok((x, _)) => Ok((x, s0))
                case Err(e)     => Err(e)
            }
        )

    /// Succeed with `()` if `p` fails; never consume (negative lookahead).
    pub def notFollowedBy(p: Parser[a]): Parser[Unit] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok(_) =>
                    Err(ParseError.Error(
                        match s0 { case State.State(_, pos) => pos },
                        "notFollowedBy" :: Nil
                    ))
                case Err(_) =>
                    Ok(((), s0))
            }
        )

    /// Discard the value of `p`.
    pub def void(p: Parser[a]): Parser[Unit] =
        map(_ -> (), p)

    /// Run `p` and replace its value with `x`.
    pub def replace(x: b, p: Parser[a]): Parser[b] =
        map(_ -> x, p)

    /// `optional(p)` with a default when absent (non-consuming fail only).
    pub def option(default: a, p: Parser[a]): Parser[a] =
        map(o -> match o {
            case Some(x) => x
            case None    => default
        }, optional(p))

    /// Zero or more, discarding results.
    pub def skipMany(p: Parser[a]): Parser[Unit] =
        void(many(p))

    /// One or more, discarding results.
    pub def skipSome(p: Parser[a]): Parser[Unit] =
        void(some(p))

    /// Keep applying `p` until `end` succeeds; `end` is consumed. Collect `p`s.
    pub def manyTill(p: Parser[a], end: Parser[b]): Parser[List[a]] =
        mkParser(s0 -> {
            def loop(s: State, acc: List[a]): Result[ParseError, (List[a], State)] =
                match runParser(end, s) {
                    case Ok((_, s1)) =>
                        Ok((List.reverse(acc), s1))
                    case Err(_) =>
                        match runParser(p, s) {
                            case Ok((x, s1)) =>
                                if (stateOffset(s1) == stateOffset(s))
                                    // empty match would loop forever
                                    Err(ParseError.Error(
                                        match s { case State.State(_, pos) => pos },
                                        "manyTill stuck" :: Nil
                                    ))
                                else
                                    loop(s1, x :: acc)
                            case Err(e) => Err(e)
                        }
                };
            loop(s0, Nil)
        })

    /// Zero or more `p` each terminated by `sep` (`p sep`)* .
    pub def endBy(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        many(andThenL(p, sep))

    /// One or more `p` each terminated by `sep`.
    pub def endBy1(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        some(andThenL(p, sep))

    /// Zero or more `p` separated and optionally ended by `sep`.
    ///
    /// `p (sep p)* sep?` or empty.
    pub def sepEndBy(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        MiniParse.Parsec.orElse(sepEndBy1(p, sep), pure(Nil))

    /// One or more `p` separated and optionally ended by `sep`.
    pub def sepEndBy1(p: Parser[a], sep: Parser[b]): Parser[List[a]] =
        flatMap(x ->
            flatMap(xs ->
                map(_ -> x :: xs, optional(sep)),
                many(andThen(sep, p))),
            p
        )

    /// Succeed only if `pred` holds on `p`'s result (same position on failure).
    pub def filter(pred: a -> Bool, label: String, p: Parser[a]): Parser[a] =
        flatMap(x ->
            if (pred(x)) pure(x) else fail(label),
            p
        )

    /// Alias of `some` (Parsec naming).
    pub def many1(p: Parser[a]): Parser[List[a]] =
        some(p)

}
