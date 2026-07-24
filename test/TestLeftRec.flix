mod TestLeftRec {

    use Examples.LeftRec.{
        Expr, parseLeft, parseRight, isLeftAssoc123, isRightAssoc123
    }

    @Test
    def testLeftSingle(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Expr.Lit(42)), parseLeft("42"))

    @Test
    def testLeftBinary(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Expr.Add(Expr.Lit(1), Expr.Lit(2))),
            parseLeft("1+2")
        )

    @Test
    def testLeftAssoc(): Unit \ Assert =
        match parseLeft("1+2+3") {
            case Ok(e) => Assert.assertTrue(isLeftAssoc123(e))
            case Err(_) => Assert.fail("expected left-assoc parse")
        }

    @Test
    def testRightAssoc(): Unit \ Assert =
        match parseRight("1+2+3") {
            case Ok(e) => Assert.assertTrue(isRightAssoc123(e))
            case Err(_) => Assert.fail("expected right-assoc parse")
        }

    @Test
    def testLeftVsRightDiffer(): Unit \ Assert =
        Assert.assertTrue(parseLeft("1+2+3") != parseRight("1+2+3"))

    @Test
    def testLeftLonger(): Unit \ Assert =
        match parseLeft("10+20+30") {
            case Ok(Expr.Add(Expr.Add(Expr.Lit(10), Expr.Lit(20)), Expr.Lit(30))) => ()
            case other => Assert.fail("unexpected: ${other}")
        }

    @Test
    def testLeftRejectsTrailing(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseLeft("1+2+")))

    @Test
    def testLeftRejectsEmpty(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseLeft("")))

}
