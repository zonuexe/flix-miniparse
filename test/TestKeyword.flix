mod TestKeyword {

    use Examples.Keyword.{
        Token, parseNaiveParsec, parseParsec, parsePeg
    }

    ///////////////////////////////////////////////////////////////////////////
    // Naive Parsec trap
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testNaiveIfOk(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.KwIf), parseNaiveParsec("if"))

    @Test
    def testNaiveIfaFails(): Unit \ Assert =
        // Classic gotcha: "if" consumes, eof fails, ident never tried.
        Assert.assertTrue(Result.isErr(parseNaiveParsec("ifa")))

    ///////////////////////////////////////////////////////////////////////////
    // Parsec with attempt + boundary
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testParsecIf(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.KwIf), parseParsec("if"))

    @Test
    def testParsecIfa(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.Ident("ifa")), parseParsec("ifa"))

    @Test
    def testParsecFoo(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.Ident("foo")), parseParsec("foo"))

    @Test
    def testParsecIfSpace(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.KwIf), parseParsec("  if  "))

    ///////////////////////////////////////////////////////////////////////////
    // PEG: choice + notPredicate
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testPegIf(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.KwIf), parsePeg("if"))

    @Test
    def testPegIfa(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Token.Ident("ifa")), parsePeg("ifa"))

    @Test
    def testPegIf1(): Unit \ Assert =
        // '1' is alphanumeric → not a keyword boundary after "if"
        Assert.assertEq(expected = Ok(Token.Ident("if1")), parsePeg("if1"))

    @Test
    def testPegBothAgreeOnIfa(): Unit \ Assert =
        Assert.assertEq(expected = parseParsec("ifa"), parsePeg("ifa"))

}
