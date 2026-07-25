///
/// Panic-mode recovery for **`CoParser`** (extension of `MiniParse.Recover`).
///
/// Reuses `WithErrors` and the same policy as pure `Recover`:
/// try item → on failure resync from the attempt start → continue.
///
/// ```text
/// runProgramSkipping(stmt, resync(";}"), source)
///   "let x = 1; let = 2; print x;"
///     →  Ok ( [Let x; Print x] , [soft error] )
/// ```
///
/// Drivers use `runCoPartial` with **eof = true** on the current remainder
/// (same contract as Bridge `toParser`). Chunked helpers **join** chunks first;
/// soft recovery without joining mid-stream is future work.
///
mod MiniParse.RecoverCo {

    use MiniParse.Core.{
        ParseError, State,
        initState, stateInput, statePos, stateOffset
    }
    use MiniParse.Suspend.{
        CoParser, pure, map, flatMap, andThen, void,
        orElse, many, oneOf, noneOf, anyChar, runCoPartial, ws
    }
    use MiniParse.Recover.{WithErrors, clean}

    ///////////////////////////////////////////////////////////////////////////
    // Sync as CoParsers
    ///////////////////////////////////////////////////////////////////////////

    /// Skip zero or more characters not in `chars` (stop before sync or EOF).
    pub def skipUntilOneOf(chars: String): CoParser[Unit] =
        void(many(noneOf(chars)))

    /// Skip through the first character in `chars`, or to EOF.
    pub def skipPastOneOf(chars: String): CoParser[Unit] =
        andThen(
            skipUntilOneOf(chars),
            orElse(void(oneOf(chars)), pure(()))
        )

    /// Consume one character if possible.
    pub def skipOne(): CoParser[Unit] =
        orElse(void(anyChar()), pure(()))

    /// Panic-mode resync token set (semicolon / brace, etc.).
    pub def resync(chars: String): CoParser[Unit] =
        skipPastOneOf(chars)

    ///////////////////////////////////////////////////////////////////////////
    // Drivers
    ///////////////////////////////////////////////////////////////////////////

    /// Zero or more `item` with panic-mode recovery; full `input` must be consumed
    /// (trailing whitespace allowed).
    pub def runManySkipping(
        item: CoParser[a],
        sync: CoParser[Unit],
        input: String
    ): Result[ParseError, WithErrors[List[a]]] = {
        def loop(
            s: State,
            acc: List[a],
            errs: List[ParseError]
        ): Result[ParseError, (WithErrors[List[a]], State)] =
            match runCoPartial(ws(), s) {
                case Err(e) =>
                    Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(e :: errs)), s))
                case Ok(((), sWs)) => {
                    let off = stateOffset(sWs);
                    let n = String.length(stateInput(sWs));
                    if (off >= n)
                        Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(errs)), sWs))
                    else
                        match runCoPartial(item, sWs) {
                            case Ok((x, s1)) =>
                                if (stateOffset(s1) == off)
                                    Ok((WithErrors.WithErrors(List.reverse(acc), List.reverse(errs)), sWs))
                                else
                                    loop(s1, x :: acc, errs)
                            case Err(e) =>
                                match runEnsureProgress(sWs, sync) {
                                    case Ok(s2) =>
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
        match loop(initState(input), Nil, Nil) {
            case Err(e) => Err(e)
            case Ok((w, sEnd)) =>
                match runCoPartial(ws(), sEnd) {
                    case Err(e) => Err(e)
                    case Ok(((), s2)) =>
                        if (stateOffset(s2) >= String.length(stateInput(s2)))
                            Ok(w)
                        else
                            Err(ParseError.Error(statePos(s2), "end of input" :: Nil))
                }
        }
    }

    /// Alias of `runManySkipping` (statement-list style naming).
    pub def runProgramSkipping(
        item: CoParser[a],
        sync: CoParser[Unit],
        input: String
    ): Result[ParseError, WithErrors[List[a]]] =
        runManySkipping(item, sync, input)

    /// Join `chunks` then `runProgramSkipping` (see module docs).
    pub def runProgramSkippingChunks(
        item: CoParser[a],
        sync: CoParser[Unit],
        chunks: List[String]
    ): Result[ParseError, WithErrors[List[a]]] =
        runProgramSkipping(item, sync, List.join("", chunks))

    /// Single-item recover on a full string (success must consume all input).
    pub def runRecover(
        p: CoParser[a],
        sync: CoParser[Unit],
        fallback: a,
        input: String
    ): Result[ParseError, WithErrors[a]] = {
        let s0 = initState(input);
        match runCoPartial(p, s0) {
            case Ok((x, s1)) =>
                finishClean(clean(x), s1)
            case Err(e) =>
                match runEnsureProgress(s0, sync) {
                    case Ok(s2) =>
                        finishClean(WithErrors.WithErrors(fallback, e :: Nil), s2)
                    case Err(_) =>
                        Ok(WithErrors.WithErrors(fallback, e :: Nil))
                }
        }
    }

    def finishClean(w: WithErrors[a], s: State): Result[ParseError, WithErrors[a]] =
        match runCoPartial(ws(), s) {
            case Err(e) => Err(e)
            case Ok(((), s2)) =>
                if (stateOffset(s2) >= String.length(stateInput(s2)))
                    Ok(w)
                else
                    Err(ParseError.Error(statePos(s2), "end of input" :: Nil))
        }

    /// Run `sync` from `s0`; if offset does not advance, `skipOne` then `sync`.
    def runEnsureProgress(s0: State, sync: CoParser[Unit]): Result[ParseError, State] = {
        let off0 = stateOffset(s0);
        match runCoPartial(sync, s0) {
            case Ok(((), s1)) =>
                if (stateOffset(s1) > off0)
                    Ok(s1)
                else
                    match runCoPartial(andThen(skipOne(), sync), s0) {
                        case Ok(((), s2)) => Ok(s2)
                        case Err(e) => Err(e)
                    }
            case Err(_) =>
                match runCoPartial(andThen(skipOne(), sync), s0) {
                    case Ok(((), s2)) => Ok(s2)
                    case Err(e) => Err(e)
                }
        }
    }

}
