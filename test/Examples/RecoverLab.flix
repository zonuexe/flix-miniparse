///
/// Lab: panic-mode recovery on MiniLang statement lists.
///
/// Guide: `docs/recovery.md`.
///
/// **Without recovery** one bad statement aborts the whole program.
/// **With recovery** we resync on `;` (and whitespace), keep later statements,
/// and collect soft `ParseError`s for diagnostics.
///
/// ```text
/// let x = 1;
/// let = 2;          ← bad (missing name)
/// print x;
/// ```
///
/// Resilient parse → stmts [Let x; Print x] + one soft error near the second `let`.
///
mod Examples.RecoverLab {

    use MiniParse.Core.{Parser, ParseError}
    use MiniParse.Recover.{
        WithErrors, manySkipping, programSkipping, parseWithErrors,
        resync, valueOf, errorsOf, isClean
    }
    use MiniParse.ErrorFormat.{formatError, formatErrors}
    use Examples.MiniLang.{Stmt, parseProgram, stmt, runProgram, RuntimeError, Env}

    /// Sync tokens for MiniLang-ish statements: semicolon (and close-brace for blocks).
    pub def stmtSync(): Parser[Unit] =
        resync(";}")

    /// Statement list with panic-mode recovery (no leading/trailing ws wrapper).
    pub def stmtsRecovering(): Parser[WithErrors[List[Stmt]]] =
        manySkipping(stmt(), stmtSync())

    /// Full program: optional surrounding whitespace + recovering statements.
    pub def programRecovering(): Parser[WithErrors[List[Stmt]]] =
        programSkipping(stmt(), stmtSync())

    pub def parseResilient(input: String): Result[ParseError, WithErrors[List[Stmt]]] =
        parseWithErrors(programRecovering(), input)

    /// Strict parse (existing MiniLang) for contrast.
    pub def parseStrict(input: String): Result[ParseError, List[Stmt]] =
        parseProgram(input)

    /// Run resilient parse then interpret successful statements only.
    pub def runResilient(
        input: String
    ): Result[ParseError, (WithErrors[List[Stmt]], Result[RuntimeError, (Env, List[Int32])])] =
        match parseResilient(input) {
            case Err(e) => Err(e)
            case Ok(w) =>
                Ok((w, runProgram(valueOf(w))))
        }

    /// Multi-line sample used in demos and tests.
    pub def sampleBroken(): String =
        "let x = 1;\n" +
        "let = 2;\n" +
        "print x;\n"

    /// Clean sample (all statements ok).
    pub def sampleClean(): String =
        "let x = 1;\n" +
        "let y = 2;\n" +
        "print x + y;\n"

    /// Human report: strict vs resilient side by side.
    pub def report(input: String): String = {
        let strict = match parseStrict(input) {
            case Ok(ss) =>
                "strict:   Ok (${List.length(ss)} stmt(s))"
            case Err(e) =>
                "strict:   Err\n" + formatError(input, e)
        };
        let soft = match parseResilient(input) {
            case Err(e) =>
                "resilient: hard Err\n" + formatError(input, e)
            case Ok(w) => {
                let n = List.length(valueOf(w));
                let es = errorsOf(w);
                if (isClean(w))
                    "resilient: Ok (${n} stmt(s), clean)"
                else
                    "resilient: Ok (${n} stmt(s), ${List.length(es)} soft error(s))\n" +
                        formatErrors(input, es)
            }
        };
        strict + "\n\n" + soft
    }

    pub def reportSample(): String =
        report(sampleBroken())

}
