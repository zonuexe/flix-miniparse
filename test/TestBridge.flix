mod TestBridge {

    use MiniParse.Core.{parse, pure}
    use MiniParse.Combinator.{digit, char, many, map, charsToString, andThen}
    use MiniParse.Parsec.{orElse, attempt}
    use MiniParse.Suspend.{
        string => coString, digits => coDigits, char => coChar, orElse => coOrElse,
        andThen => coAndThen, andThenL, eof, parseChunks
    }
    use MiniParse.Bridge.{
        toParser, fromParser, parseCo, coViaPure, pureViaCo, readToEnd
    }

    ///////////////////////////////////////////////////////////////////////////
    // CoParser → pure Parser
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testToParserString(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("hi"),
            parse(toParser(coString("hi")), "hi")
        )

    @Test
    def testToParserDigits(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("150"),
            parseCo(coDigits(3), "150")
        )

    @Test
    def testToParserDeepOrElse(): Unit \ Assert = {
        // Left "ab" fails after consuming 'a' on "ac"; right "ac" wins.
        let co = coOrElse(coString("ab"), coString("ac"));
        Assert.assertEq(expected = Ok("ac"), parse(toParser(co), "ac"))
    }

    @Test
    def testToParserComposeWithPure(): Unit \ Assert = {
        // CoParser digit then pure combinator chain via toParser + andThen
        let p = andThen(toParser(coChar('x')), digit());
        Assert.assertEq(expected = Ok('5'), parse(p, "x5"))
    }

    @Test
    def testCoViaPureMatchesChunks(): Unit \ Assert = {
        let co = coOrElse(coString("abc"), coString("abx"));
        Assert.assertEq(
            expected = parseChunks(co, "ab" :: "x" :: Nil),
            coViaPure(co, "abx")
        )
    }

    ///////////////////////////////////////////////////////////////////////////
    // pure Parser → CoParser
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testFromParserDigit(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('7'),
            pureViaCo(digit(), "7")
        )

    @Test
    def testFromParserManyDigits(): Unit \ Assert = {
        let p = map(charsToString, many(digit()));
        Assert.assertEq(expected = Ok("42"), pureViaCo(p, "42"))
    }

    @Test
    def testFromParserOrElse(): Unit \ Assert = {
        let p = orElse(attempt(andThen(char('a'), char('b'))), char('a'));
        // "a" alone: first fails after consume without attempt would fail;
        // with attempt, Ok('a')
        Assert.assertEq(expected = Ok('a'), pureViaCo(p, "a"))
    }

    @Test
    def testFromParserViaChunks(): Unit \ Assert = {
        let p = map(charsToString, many(digit()));
        // fromParser waits until EOF; chunks + close
        Assert.assertEq(
            expected = Ok("99"),
            parseChunks(fromParser(p), "9" :: "9" :: Nil)
        )
    }

    @Test
    def testReadToEnd(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("xyz"),
            parseChunks(readToEnd(), "xy" :: "z" :: Nil)
        )

    ///////////////////////////////////////////////////////////////////////////
    // Round-trip style checks (not full identity)
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testPureThenCoThenPureDigits(): Unit \ Assert = {
        let p = map(charsToString, many(digit()));
        // pure → co → pure embedding
        let p2 = toParser(fromParser(p));
        Assert.assertEq(expected = Ok("123"), parse(p2, "123"))
    }

}
