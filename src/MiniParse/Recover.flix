///
/// Error recovery helpers for pure `Parser`s (educational + practical).
///
/// Typical use: parse a sequence of items (statements, declarations). When one
/// fails, **resynchronize** to a delimiter (`;`, `}`, …), record the soft error,
/// and continue so later items still parse.
///
/// ```text
/// manySkipping(stmt, resync(";"))
///   "let x = 1; let = 2; print x;"
///     →  Ok ( [Let x; Print x] , [soft error on second let] )
/// ```
///
/// Recovery is panic-mode: choose sync tokens carefully. Deep backtracking is
/// unchanged; this layer sits on top of ordinary parsers.
///
mod MiniParse.Recover {

    use MiniParse.Core.{
        Parser, ParseError, State, Position,
        runParser, mkParser,
        stateInput, statePos, stateOffset, initState,
        advancePosition, initialPosition
    }
    use MiniParse.Combinator.{andThen}

    ///////////////////////////////////////////////////////////////////////////
    // Result shape
    ///////////////////////////////////////////////////////////////////////////

    /// A primary value plus zero or more soft errors collected during recovery.
    pub enum WithErrors[a] with Eq, ToString {
        case WithErrors(a, List[ParseError])
    }

    pub def valueOf(w: WithErrors[a]): a = match w {
        case WithErrors.WithErrors(x, _) => x
    }

    pub def errorsOf(w: WithErrors[a]): List[ParseError] = match w {
        case WithErrors.WithErrors(_, es) => es
    }

    pub def isClean(w: WithErrors[a]): Bool =
        List.isEmpty(errorsOf(w))

    pub def clean(x: a): WithErrors[a] =
        WithErrors.WithErrors(x, Nil)

    pub def mapValue(f: a -> b, w: WithErrors[a]): WithErrors[b] = match w {
        case WithErrors.WithErrors(x, es) => WithErrors.WithErrors(f(x), es)
    }

    /// Full-input parse that may succeed with soft errors (leftover still hard-fails).
    pub def parseWithErrors(p: Parser[WithErrors[a]], input: String): Result[ParseError, WithErrors[a]] =
        match runParser(p, initState(input)) {
            case Ok((w, s1)) =>
                if (stateOffset(s1) >= String.length(stateInput(s1)))
                    Ok(w)
                else
                    Err(ParseError.Error(statePos(s1), "end of input" :: Nil))
            case Err(e) => Err(e)
        }

    ///////////////////////////////////////////////////////////////////////////
    // Sync / skip (offset scan — clear progress, no combinator edge cases)
    ///////////////////////////////////////////////////////////////////////////

    def charIn(c: Char, s: String): Bool = {
        def loop(i: Int32): Bool =
            match String.nth(i, s) {
                case None    => false
                case Some(d) => if (d == c) true else loop(i + 1)
            };
        loop(0)
    }

    /// Rebuild `Position` at absolute `off` by rescanning from the start.
    def positionAt(input: String, off: Int32): Position = {
        let n = String.length(input);
        let target = if (off < 0) 0 else if (off > n) n else off;
        def loop(i: Int32, pos: Position): Position =
            if (i >= target)
                pos
            else
                match String.nth(i, input) {
                    case None    => pos
                    case Some(c) => loop(i + 1, advancePosition(c, pos))
                };
        loop(0, initialPosition())
    }

    def seekState(s: State, newOff: Int32): State =
        State.State(stateInput(s), positionAt(stateInput(s), newOff))

    /// Skip zero or more characters **not** in `chars`. Stops before a sync char or EOF.
    pub def skipUntilOneOf(chars: String): Parser[Unit] =
        mkParser(s0 -> {
            let input = stateInput(s0);
            let n = String.length(input);
            def find(i: Int32): Int32 =
                if (i >= n)
                    n
                else
                    match String.nth(i, input) {
                        case None => n
                        case Some(c) =>
                            if (charIn(c, chars)) i else find(i + 1)
                    };
            let end = find(stateOffset(s0));
            Ok(((), seekState(s0, end)))
        })

    /// Skip through the first character in `chars` (consumes it), or to EOF.
    pub def skipPastOneOf(chars: String): Parser[Unit] =
        mkParser(s0 -> {
            let input = stateInput(s0);
            let n = String.length(input);
            def find(i: Int32): Int32 =
                if (i >= n)
                    n
                else
                    match String.nth(i, input) {
                        case None => n
                        case Some(c) =>
                            if (charIn(c, chars)) i + 1 else find(i + 1)
                    };
            let end = find(stateOffset(s0));
            Ok(((), seekState(s0, end)))
        })

    /// Consume exactly one character if possible.
    pub def skipOne(): Parser[Unit] =
        mkParser(s0 -> {
            let input = stateInput(s0);
            let off = stateOffset(s0);
            if (off >= String.length(input))
                Ok(((), s0))
            else
                Ok(((), seekState(s0, off + 1)))
        })

    /// Panic-mode resync: `skipPastOneOf`, forcing at least one character when stuck.
    ///
    /// Always run recovery from the **start of the failed attempt** (not the
    /// furthest-error label). PEG/Parsec `attempt` rewrites error positions to
    /// the attempt start, which would otherwise make position-based recovery
    /// nibble one character at a time.
    pub def resync(chars: String): Parser[Unit] =
        mkParser(s0 -> {
            let off0 = stateOffset(s0);
            match runParser(skipPastOneOf(chars), s0) {
                case Ok(((), s1)) =>
                    if (stateOffset(s1) > off0)
                        Ok(((), s1))
                    else
                        runParser(andThen(skipOne(), skipPastOneOf(chars)), s0)
                case Err(_) =>
                    runParser(andThen(skipOne(), skipPastOneOf(chars)), s0)
            }
        })

    ///////////////////////////////////////////////////////////////////////////
    // Single-item recovery
    ///////////////////////////////////////////////////////////////////////////

    /// Run `p`. On success: value with no soft errors.
    /// On failure: run `sync` from the attempt start, yield `fallback`, record error.
    pub def recover(
        p: Parser[a],
        sync: Parser[Unit],
        fallback: a
    ): Parser[WithErrors[a]] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok((x, s1)) =>
                    Ok((clean(x), s1))
                case Err(e) =>
                    match runParser(ensureProgress(s0, sync), s0) {
                        case Ok(((), s2)) =>
                            Ok((WithErrors.WithErrors(fallback, e :: Nil), s2))
                        case Err(_) =>
                            Ok((WithErrors.WithErrors(fallback, e :: Nil), s0))
                    }
            }
        )

    /// Like `recover` but omit a value on failure (`None` + soft error).
    pub def recoverSkip(
        p: Parser[a],
        sync: Parser[Unit]
    ): Parser[WithErrors[Option[a]]] =
        mkParser(s0 ->
            match runParser(p, s0) {
                case Ok((x, s1)) =>
                    Ok((clean(Some(x)), s1))
                case Err(e) =>
                    match runParser(ensureProgress(s0, sync), s0) {
                        case Ok(((), s2)) =>
                            Ok((WithErrors.WithErrors(None, e :: Nil), s2))
                        case Err(_) =>
                            Ok((WithErrors.WithErrors(None, e :: Nil), s0))
                    }
            }
        )

    /// Run `sync`; if it does not advance past `s0`, force one character.
    def ensureProgress(s0: State, sync: Parser[Unit]): Parser[Unit] =
        mkParser(s -> {
            let off0 = stateOffset(s0);
            match runParser(sync, s) {
                case Ok(((), s1)) =>
                    if (stateOffset(s1) > off0)
                        Ok(((), s1))
                    else
                        runParser(skipOne(), s)
                case Err(_) =>
                    runParser(skipOne(), s)
            }
        })

    ///////////////////////////////////////////////////////////////////////////
    // Sequences
    ///////////////////////////////////////////////////////////////////////////

    /// Zero or more `p`, skipping failed items after `sync` (panic-mode).
    ///
    /// Leading whitespace is skipped before each attempt (statement lists often
    /// leave newlines after recovery). Stops at EOF. Only successful `p` values
    /// are kept; failures contribute soft errors. Sync always starts at the
    /// failed attempt's start position (after that leading whitespace).
    pub def manySkipping(
        p: Parser[a],
        sync: Parser[Unit]
    ): Parser[WithErrors[List[a]]] =
        mkParser(s0 -> {
            use MiniParse.Combinator.{ws};
            def loop(
                s: State,
                acc: List[a],
                errs: List[ParseError]
            ): Result[ParseError, (WithErrors[List[a]], State)] =
                match runParser(ws(), s) {
                    case Err(e) =>
                        // Should not happen for `ws`; treat as hard stop.
                        Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(e :: errs)), s))
                    case Ok(((), sWs)) => {
                        let input = stateInput(sWs);
                        let off = stateOffset(sWs);
                        if (off >= String.length(input))
                            Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(errs)), sWs))
                        else
                            match runParser(p, sWs) {
                                case Ok((x, s1)) =>
                                    if (stateOffset(s1) == off)
                                        Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(errs)), sWs))
                                    else
                                        loop(s1, x :: acc, errs)
                                case Err(e) =>
                                    match runParser(ensureProgress(sWs, sync), sWs) {
                                        case Ok(((), s2)) =>
                                            if (stateOffset(s2) <= off)
                                                Ok((WithErrors.WithErrors(
                                                    List.reverse(acc),
                                                    List.reverse(e :: errs)
                                                ), s2))
                                            else
                                                loop(s2, acc, e :: errs)
                                        case Err(_) =>
                                            Ok((WithErrors.WithErrors(
                                                List.reverse(acc),
                                                List.reverse(e :: errs)
                                            ), sWs))
                                    }
                            }
                    }
                };
            loop(s0, Nil, Nil)
        })

    /// `ws` then `manySkipping`, then trailing `ws` (statement-list style).
    pub def programSkipping(
        item: Parser[a],
        sync: Parser[Unit]
    ): Parser[WithErrors[List[a]]] = {
        use MiniParse.Combinator.{ws};
        andThen(ws(), andThenL(manySkipping(item, sync), ws()))
    }

    // Local import for andThenL without pulling whole Combinator into every use site above.
    def andThenL(p: Parser[a], q: Parser[b]): Parser[a] =
        MiniParse.Combinator.andThenL(p, q)

}
