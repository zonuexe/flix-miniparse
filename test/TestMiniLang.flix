mod TestMiniLang {

    use Examples.MiniLang.{
        Expr, Stmt, parseProgram, runProgram, runSource, evalExpr
    }

    @Test
    def testLetPrint(): Unit \ Assert =
        match runSource("let x = 1 + 2; print x * 3;") {
            case Ok(Ok((_env, out))) =>
                Assert.assertEq(expected = 9 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testIfThen(): Unit \ Assert =
        match runSource("if 1 then print 10; else print 20;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 10 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testIfElse(): Unit \ Assert =
        match runSource("if 0 then print 10; else print 20;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 20 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testBlock(): Unit \ Assert =
        match runSource("{ let a = 2; let b = 3; print a + b; }") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 5 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testIfaIsIdent(): Unit \ Assert =
        // `ifa` must not be parsed as keyword `if`.
        match runSource("let ifa = 7; print ifa;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 7 :: Nil, out)
            case _ =>
                Assert.fail("expected ifa as identifier")
        }

    @Test
    def testNestedIf(): Unit \ Assert =
        match runSource(
            "let x = 1; if x then { if 0 then print 1; else print 2; } else print 3;"
        ) {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 2 :: Nil, out)
            case _ =>
                Assert.fail("expected nested if")
        }

    @Test
    def testUnbound(): Unit \ Assert =
        match runSource("print z;") {
            case Ok(Err(_)) => ()
            case _          => Assert.fail("expected runtime unbound")
        }

    @Test
    def testParseFail(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseProgram("let = 1;")))

    @Test
    def testEvalVar(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(5),
            evalExpr(Expr.Add(Expr.Var("x"), Expr.Lit(2)), Map#{ "x" => 3 })
        )

    @Test
    def testPrecedenceInLang(): Unit \ Assert =
        match runSource("print 1 + 2 * 3;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 7 :: Nil, out)
            case _ =>
                Assert.fail("expected 7")
        }

    @Test
    def testComparison(): Unit \ Assert =
        match runSource("print 1 + 2 == 3; print 2 < 1; print 5 >= 5;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 1 :: 0 :: 1 :: Nil, out)
            case _ =>
                Assert.fail("expected comparison results")
        }

    @Test
    def testComparisonBindsLooserThanArith(): Unit \ Assert =
        // 1 + 2 == 3  is  (1+2) == 3, not 1 + (2 == 3)
        match runSource("print 1 + 2 == 3;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 1 :: Nil, out)
            case _ =>
                Assert.fail("expected 1")
        }

    @Test
    def testWhileSum(): Unit \ Assert =
        // sum 1..5
        match runSource(
            "let i = 1; let s = 0; while i <= 5 do { let s = s + i; let i = i + 1; } print s;"
        ) {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 15 :: Nil, out)
            case other =>
                Assert.fail("expected 15, got ${other}")
        }

    @Test
    def testWhileFalseNeverRuns(): Unit \ Assert =
        match runSource("let x = 0; while 0 do let x = 1; print x;") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 0 :: Nil, out)
            case _ =>
                Assert.fail("expected 0")
        }

    @Test
    def testWhileLoopLimit(): Unit \ Assert =
        match runSource("while 1 do { }") {
            case Ok(Err(Examples.MiniLang.RuntimeError.LoopLimit)) => ()
            case other => Assert.fail("expected LoopLimit, got ${other}")
        }

}
