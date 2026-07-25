mod TestCoLang {

    use Examples.MiniLang.{Expr, Stmt}
    use Examples.CoLang.{
        Word, parseProgram, parseProgramChunks, parseWord, runSource, runSourceChunks
    }
    use MiniParse.Bridge.{parseCo, toParser}
    use MiniParse.Core.{parse}

    @Test
    def testWordIf(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WIf), parseWord("if"))

    @Test
    def testWordIfa(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WIdent("ifa")), parseWord("ifa"))

    @Test
    def testWordLet(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WLet), parseWord("let"))

    @Test
    def testWordPrint(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WPrint), parseWord("print"))

    @Test
    def testWordWhile(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Word.WWhile), parseWord("while"))

    @Test
    def testLetPrintAst(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(
                Stmt.Let("ifa", Expr.Lit(2)) ::
                Stmt.Print(Expr.Var("ifa")) :: Nil
            ),
            parseProgram("let ifa = 2; print ifa;")
        )

    @Test
    def testIfThenElseAst(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(
                Stmt.If(
                    Expr.Var("x"),
                    Stmt.Print(Expr.Var("a")),
                    Stmt.Print(Expr.Var("b"))
                ) :: Nil
            ),
            parseProgram("if x then print a; else print b;")
        )

    @Test
    def testChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Stmt.Let("x", Expr.Lit(1)) :: Nil),
            parseProgramChunks("let x" :: " = 1;" :: Nil)
        )

    @Test
    def testIfaNotKeyword(): Unit \ Assert =
        // Must not parse as `if` + leftover `a = 1;`
        Assert.assertEq(
            expected = Ok(Stmt.Let("ifa", Expr.Lit(1)) :: Nil),
            parseProgram("let ifa = 1;")
        )

    @Test
    def testLetPrintRun(): Unit \ Assert =
        match runSource("let x = 1 + 2; print x * 3;") {
            case Ok(Ok((_env, out))) =>
                Assert.assertEq(expected = 9 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testPrecedence(): Unit \ Assert =
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
    def testBlock(): Unit \ Assert =
        match runSource("{ let a = 2; let b = 3; print a + b; }") {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 5 :: Nil, out)
            case _ =>
                Assert.fail("expected success")
        }

    @Test
    def testWhileSum(): Unit \ Assert =
        match runSource(
            "let i = 1; let s = 0; while i <= 5 do { let s = s + i; let i = i + 1; } print s;"
        ) {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 15 :: Nil, out)
            case other =>
                Assert.fail("expected 15, got ${other}")
        }

    @Test
    def testWhileChunks(): Unit \ Assert =
        // Suspension mid-program; resume without restarting the whole parse.
        match runSourceChunks(
            "let i = 1; let s = 0; wh" ::
            "ile i <= 3 do { let s = s + i; let i = i + 1; } pr" ::
            "int s;" :: Nil
        ) {
            case Ok(Ok((_, out))) =>
                Assert.assertEq(expected = 6 :: Nil, out)
            case other =>
                Assert.fail("expected 6, got ${other}")
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
    def testBridgeParseCo(): Unit \ Assert =
        // CoParser program embedded as pure parse via Bridge.
        match parseCo(Examples.CoLang.program(), "let x = 1 + 2; print x;") {
            case Ok(stmts) =>
                match Examples.MiniLang.runProgram(stmts) {
                    case Ok((_, out)) =>
                        Assert.assertEq(expected = 3 :: Nil, out)
                    case Err(_) =>
                        Assert.fail("runtime")
                }
            case Err(_) =>
                Assert.fail("parseCo")
        }

    @Test
    def testBridgeToParser(): Unit \ Assert =
        match parse(toParser(Examples.CoLang.program()), "print 2 * 3 + 1;") {
            case Ok(stmts) =>
                match Examples.MiniLang.runProgram(stmts) {
                    case Ok((_, out)) =>
                        Assert.assertEq(expected = 7 :: Nil, out)
                    case Err(_) =>
                        Assert.fail("runtime")
                }
            case Err(_) =>
                Assert.fail("toParser parse")
        }

    @Test
    def testParseFail(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseProgram("let = 1;")))

}
