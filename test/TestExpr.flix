mod TestExpr {

    use Examples.Expr.{Expr, parseExpr, parseEval, eval}

    @Test
    def testLit(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Expr.Lit(42)), parseExpr("42"))

    @Test
    def testAdd(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Expr.Add(Expr.Lit(1), Expr.Lit(2))),
            parseExpr("1 + 2")
        )

    @Test
    def testPrecedence(): Unit \ Assert =
        // 1 + 2 * 3  ==>  Add(1, Mul(2, 3))
        Assert.assertEq(
            expected = Ok(Expr.Add(Expr.Lit(1), Expr.Mul(Expr.Lit(2), Expr.Lit(3)))),
            parseExpr("1 + 2 * 3")
        )

    @Test
    def testPrecedenceEval(): Unit \ Assert =
        Assert.assertEq(expected = Ok(7), parseEval("1 + 2 * 3"))

    @Test
    def testLeftAssoc(): Unit \ Assert =
        // 10 - 3 - 2  ==>  Sub(Sub(10, 3), 2) = 5
        Assert.assertEq(expected = Ok(5), parseEval("10 - 3 - 2"))

    @Test
    def testParens(): Unit \ Assert =
        Assert.assertEq(expected = Ok(9), parseEval("(1 + 2) * 3"))

    @Test
    def testUnaryMinus(): Unit \ Assert =
        Assert.assertEq(expected = Ok(-4), parseEval("-4"))

    @Test
    def testUnaryAndBinary(): Unit \ Assert =
        Assert.assertEq(expected = Ok(5), parseEval("1 + -2 * -2"))

    @Test
    def testWhitespace(): Unit \ Assert =
        Assert.assertEq(expected = Ok(3), parseEval("  1+2  "))

    @Test
    def testDiv(): Unit \ Assert =
        Assert.assertEq(expected = Ok(2), parseEval("8 / 3")) // trunc toward 0? 8/3=2 in int

    @Test
    def testInvalid(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseExpr("1 +")))

}
