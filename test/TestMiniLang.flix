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

}
