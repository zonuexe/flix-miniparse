mod TestRecoverCo {

    use MiniParse.Recover.{valueOf, errorsOf, isClean, WithErrors}
    use MiniParse.RecoverCo.{
        skipPastOneOf, resync, runManySkipping, runProgramSkipping,
        runProgramSkippingChunks, runRecover
    }
    use MiniParse.Suspend.{digit, string, parseChunks, andThen}
    use Examples.CoRecoverLab.{
        parseResilient, parseResilientChunks, parseStrict, runResilient, report
    }
    use Examples.RecoverLab.{sampleBroken, sampleClean, parseResilient => pureResilient}
    use Examples.MiniLang.{Stmt, Expr}

    ///////////////////////////////////////////////////////////////////////////
    // Sync CoParsers
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testSkipPastSemi(): Unit \ Assert =
        match parseChunks(andThen(skipPastOneOf(";"), digit()), "ab;9" :: Nil) {
            case Ok('9') => ()
            case other => Assert.fail("${other}")
        }

    @Test
    def testResync(): Unit \ Assert =
        match parseChunks(andThen(resync(";"), digit()), ";7" :: Nil) {
            case Ok('7') => ()
            case other => Assert.fail("${other}")
        }

    ///////////////////////////////////////////////////////////////////////////
    // Drivers
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testManySkippingDigits(): Unit \ Assert =
        match runManySkipping(digit(), resync("x"), "123") {
            case Ok(w) =>
                Assert.assertTrue(isClean(w));
                Assert.assertEq(expected = '1' :: '2' :: '3' :: Nil, valueOf(w))
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testManySkippingWithJunk(): Unit \ Assert =
        match runManySkipping(digit(), resync(";"), "1z;2") {
            case Ok(w) =>
                Assert.assertEq(expected = '1' :: '2' :: Nil, valueOf(w));
                Assert.assertEq(expected = 1, List.length(errorsOf(w)))
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testRunRecoverFallback(): Unit \ Assert =
        match runRecover(string("ok"), skipPastOneOf(";"), "BAD", "nope;") {
            case Ok(WithErrors.WithErrors("BAD", _ :: Nil)) => ()
            case other => Assert.fail("${other}")
        }

    ///////////////////////////////////////////////////////////////////////////
    // CoLang lab
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testStrictFailsOnBroken(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseStrict(sampleBroken())))

    @Test
    def testResilientKeepsNeighbors(): Unit \ Assert =
        match parseResilient(sampleBroken()) {
            case Ok(w) => {
                Assert.assertEq(expected = 2, List.length(valueOf(w)));
                Assert.assertEq(expected = 1, List.length(errorsOf(w)));
                match valueOf(w) {
                    case Stmt.Let("x", Expr.Lit(1)) :: Stmt.Print(Expr.Var("x")) :: Nil => ()
                    case other => Assert.fail("stmts: ${other}")
                }
            }
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testResilientClean(): Unit \ Assert =
        match parseResilient(sampleClean()) {
            case Ok(w) =>
                Assert.assertTrue(isClean(w));
                Assert.assertEq(expected = 3, List.length(valueOf(w)))
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testResilientRunPrintsX(): Unit \ Assert =
        match runResilient(sampleBroken()) {
            case Ok((w, Ok((_, out)))) =>
                Assert.assertEq(expected = 1, List.length(errorsOf(w)));
                Assert.assertEq(expected = 1 :: Nil, out)
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testChunksJoinRecovery(): Unit \ Assert =
        match parseResilientChunks(
            "let x = 1;\nle" :: "t = 2;\npri" :: "nt x;\n" :: Nil
        ) {
            case Ok(w) =>
                Assert.assertEq(expected = 2, List.length(valueOf(w)));
                Assert.assertEq(expected = 1, List.length(errorsOf(w)))
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testPureAndCoAgreeOnBroken(): Unit \ Assert =
        match (pureResilient(sampleBroken()), parseResilient(sampleBroken())) {
            case (Ok(pw), Ok(cw)) =>
                Assert.assertEq(expected = valueOf(pw), valueOf(cw));
                Assert.assertEq(expected = List.length(errorsOf(pw)), List.length(errorsOf(cw)))
            case other =>
                Assert.fail("${other}")
        }

    @Test
    def testReportNonEmpty(): Unit \ Assert =
        Assert.assertTrue(String.length(report(sampleBroken())) > 20)

}
