mod TestRecover {

    use MiniParse.Core.{parse}
    use MiniParse.Combinator.{char, digit, andThen, andThenL, string}
    use MiniParse.Recover.{
        WithErrors, skipPastOneOf, skipUntilOneOf, resync, recover, recoverSkip,
        manySkipping, parseWithErrors, valueOf, errorsOf, isClean
    }
    use Examples.RecoverLab.{
        parseResilient, parseStrict, sampleBroken, sampleClean, runResilient
    }
    use Examples.MiniLang.{Stmt, Expr}

    ///////////////////////////////////////////////////////////////////////////
    // Sync primitives
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testSkipPastSemi(): Unit \ Assert =
        match parse(andThen(skipPastOneOf(";"), digit()), "ab;9") {
            case Ok('9') => ()
            case other => Assert.fail("${other}")
        }

    @Test
    def testSkipUntilLeavesSync(): Unit \ Assert =
        match parse(andThen(skipUntilOneOf(";"), char(';')), "xy;") {
            case Ok(';') => ()
            case other => Assert.fail("${other}")
        }

    @Test
    def testResyncProgress(): Unit \ Assert =
        // Leading sync char: still consume one ';' so loops advance.
        match parse(andThen(resync(";"), digit()), ";7") {
            case Ok('7') => ()
            case other => Assert.fail("${other}")
        }

    ///////////////////////////////////////////////////////////////////////////
    // recover / manySkipping
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testRecoverFallback(): Unit \ Assert = {
        let p = recover(string("ok"), skipPastOneOf(";"), "BAD");
        match parse(andThenL(p, char('z')), "nope;z") {
            case Ok(WithErrors.WithErrors("BAD", e :: Nil)) =>
                Assert.assertTrue(List.length(e :: Nil) == 1)
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testRecoverSuccessClean(): Unit \ Assert = {
        let p = recover(string("ok"), skipPastOneOf(";"), "BAD");
        match parse(p, "ok") {
            case Ok(w) =>
                Assert.assertTrue(isClean(w));
                Assert.assertEq(expected = "ok", valueOf(w))
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testManySkippingDigits(): Unit \ Assert = {
        // digit items separated by junk until ';', sync on ';'
        // Input: 1;x;2;  — middle fails as digit, skip to next after ;
        // Actually manySkipping applies p repeatedly without separator.
        // Pattern: each "item" is digit then optional ; handled by sync only on fail.
        // Use: manySkipping(digit, skipPast ";") on "1a2b3" with sync past non-digit?
        let p = manySkipping(digit(), resync("x"));
        // "1x2x3" — digits succeed; if we had "1y2" y fails, resync past x doesn't help
        match parseWithErrors(p, "123") {
            case Ok(w) =>
                Assert.assertTrue(isClean(w));
                Assert.assertEq(expected = '1' :: '2' :: '3' :: Nil, valueOf(w))
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testManySkippingWithJunk(): Unit \ Assert = {
        // Items are single digits. On failure skip past ';'.
        // "1;z;2;" → digit 1, then ';' is not digit → error, resync past ';'
        // still at z... need better input.
        // "1z;2" → after 1, z fails digit, resync(';') skips to past ;
        let p = manySkipping(digit(), resync(";"));
        match parseWithErrors(p, "1z;2") {
            case Ok(w) =>
                Assert.assertEq(expected = '1' :: '2' :: Nil, valueOf(w));
                Assert.assertEq(expected = 1, List.length(errorsOf(w)))
            case other =>
                Assert.fail("${other}")
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // MiniLang lab
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
    def testRecoverSkipNone(): Unit \ Assert = {
        let p = recoverSkip(string("go"), skipPastOneOf(";"));
        match parse(andThenL(p, char('!')), "xx;!") {
            case Ok(WithErrors.WithErrors(None, _ :: Nil)) => ()
            case other => Assert.fail("${other}")
        }
    }

}
