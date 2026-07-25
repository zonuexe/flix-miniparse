///
/// Lab: panic-mode recovery on **CoLang** (`CoParser`) statement lists.
///
/// Same sample and policy as `Examples.RecoverLab`, but items are `CoLang.stmt`
/// and recovery is driven by `MiniParse.RecoverCo`.
///
/// Guide: `docs/recovery.md` (section “CoParser recovery”).
///
mod Examples.CoRecoverLab {

    use MiniParse.Core.{ParseError}
    use MiniParse.Recover.{WithErrors, valueOf, errorsOf, isClean}
    use MiniParse.RecoverCo.{resync, runProgramSkipping, runProgramSkippingChunks}
    use MiniParse.ErrorFormat.{formatError, formatErrors}
    use MiniParse.Suspend.{parseChunks}
    use Examples.CoLang.{stmt, parseProgram}
    use Examples.MiniLang.{Stmt, runProgram, RuntimeError, Env}
    use Examples.RecoverLab.{sampleBroken, sampleClean}

    pub def stmtSync(): MiniParse.Suspend.CoParser[Unit] =
        resync(";}")

    pub def parseResilient(input: String): Result[ParseError, WithErrors[List[Stmt]]] =
        runProgramSkipping(stmt(), stmtSync(), input)

    pub def parseResilientChunks(chunks: List[String]): Result[ParseError, WithErrors[List[Stmt]]] =
        runProgramSkippingChunks(stmt(), stmtSync(), chunks)

    /// Strict CoLang parse (fails on first bad statement / leftover).
    pub def parseStrict(input: String): Result[ParseError, List[Stmt]] =
        parseProgram(input)

    pub def runResilient(
        input: String
    ): Result[ParseError, (WithErrors[List[Stmt]], Result[RuntimeError, (Env, List[Int32])])] =
        match parseResilient(input) {
            case Err(e) => Err(e)
            case Ok(w)  => Ok((w, runProgram(valueOf(w))))
        }

    /// Side-by-side pure RecoverLab vs Co RecoverCo on the same source.
    pub def report(input: String): String = {
        let pureR = match Examples.RecoverLab.parseResilient(input) {
            case Ok(w) =>
                "pure Recover:  Ok (${List.length(valueOf(w))} stmt(s), ${List.length(errorsOf(w))} soft)"
            case Err(e) =>
                "pure Recover:  hard Err\n" + formatError(input, e)
        };
        let coR = match parseResilient(input) {
            case Ok(w) =>
                "Co RecoverCo:  Ok (${List.length(valueOf(w))} stmt(s), ${List.length(errorsOf(w))} soft)"
            case Err(e) =>
                "Co RecoverCo:  hard Err\n" + formatError(input, e)
        };
        let detail = match parseResilient(input) {
            case Ok(w) =>
                if (isClean(w))
                    "soft errors: none"
                else
                    "soft errors:\n" + formatErrors(input, errorsOf(w))
            case Err(_) =>
                ""
        };
        pureR + "\n" + coR + (if (String.isEmpty(detail)) "" else "\n" + detail)
    }

    pub def reportSample(): String =
        report(sampleBroken())

}
