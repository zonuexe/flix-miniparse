mod TestCombinators {

    use MiniParse.Core.{parse}
    use MiniParse.Combinator.{
        char, digit, string, map, andThen, andThenL, flatMap,
        anyChar, oneOf, noneOf, hexDigit, endOfLine, takeWhile, takeWhile1,
        lookAhead, notFollowedBy, void, replace, option, skipMany,
        manyTill, endBy, sepEndBy, filter, many1, chainr1
    }

    ///////////////////////////////////////////////////////////////////////////
    // Characters
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testAnyChar(): Unit \ Assert =
        Assert.assertEq(expected = Ok('z'), parse(anyChar(), "z"))

    @Test
    def testOneOf(): Unit \ Assert =
        Assert.assertEq(expected = Ok('b'), parse(oneOf("abc"), "b"))

    @Test
    def testOneOfFail(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(oneOf("abc"), "x")))

    @Test
    def testNoneOf(): Unit \ Assert =
        Assert.assertEq(expected = Ok('x'), parse(noneOf("abc"), "x"))

    @Test
    def testHexDigit(): Unit \ Assert =
        Assert.assertEq(expected = Ok('f'), parse(hexDigit(), "f"))

    @Test
    def testEndOfLineLF(): Unit \ Assert =
        Assert.assertEq(expected = Ok(()), parse(endOfLine(), "\n"))

    @Test
    def testEndOfLineCRLF(): Unit \ Assert =
        Assert.assertEq(expected = Ok(()), parse(endOfLine(), "\r\n"))

    @Test
    def testTakeWhile(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("aa"),
            parse(andThenL(takeWhile(c -> c == 'a'), char('b')), "aab")
        )

    @Test
    def testTakeWhile1(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("12"),
            parse(andThenL(takeWhile1(Char.isAsciiDigit), char('x')), "12x")
        )

    ///////////////////////////////////////////////////////////////////////////
    // Lookahead / skip / option
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testLookAheadNoConsume(): Unit \ Assert = {
        let p = flatMap(x -> map(y -> (x, y), char('a')), lookAhead(char('a')));
        Assert.assertEq(expected = Ok(('a', 'a')), parse(p, "a"))
    }

    @Test
    def testNotFollowedBy(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('a'),
            parse(andThenL(char('a'), notFollowedBy(char('b'))), "a")
        )

    @Test
    def testNotFollowedByFail(): Unit \ Assert =
        Assert.assertTrue(
            Result.isErr(parse(andThenL(char('a'), notFollowedBy(char('b'))), "ab"))
        )

    @Test
    def testReplace(): Unit \ Assert =
        Assert.assertEq(expected = Ok(99), parse(replace(99, string("hi")), "hi"))

    @Test
    def testVoid(): Unit \ Assert =
        Assert.assertEq(expected = Ok(()), parse(void(digit()), "5"))

    @Test
    def testOptionDefault(): Unit \ Assert =
        Assert.assertEq(expected = Ok('x'), parse(option('x', char('a')), ""))

    @Test
    def testOptionPresent(): Unit \ Assert =
        Assert.assertEq(expected = Ok('a'), parse(option('x', char('a')), "a"))

    @Test
    def testSkipMany(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('b'),
            parse(andThen(skipMany(char('a')), char('b')), "aaab")
        )

    ///////////////////////////////////////////////////////////////////////////
    // manyTill / sepEndBy / endBy / chainr1 / filter
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testManyTill(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('a' :: 'b' :: 'c' :: Nil),
            parse(manyTill(anyChar(), char(';')), "abc;")
        )

    @Test
    def testSepEndByTrailing(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("1" :: "2" :: "3" :: Nil),
            parse(
                sepEndBy(map(Char.toString, digit()), char(',')),
                "1,2,3,"
            )
        )

    @Test
    def testSepEndByNoTrailing(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("1" :: "2" :: Nil),
            parse(
                sepEndBy(map(Char.toString, digit()), char(',')),
                "1,2"
            )
        )

    @Test
    def testEndBy(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("a" :: "b" :: Nil),
            parse(endBy(map(Char.toString, oneOf("ab")), char(';')), "a;b;")
        )

    @Test
    def testChainr1(): Unit \ Assert = {
        // right-assoc: 1-(2-3) = 1-(-1) = 2 with integer subtraction
        let num = map(c -> Char.getNumericValue(c) |> Option.getWithDefault(0), digit());
        let op = replace((x, y) -> x - y, char('-'));
        Assert.assertEq(expected = Ok(2), parse(chainr1(num, op), "1-2-3"))
    }

    @Test
    def testFilter(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('5'),
            parse(filter(c -> c >= '5', "big digit", digit()), "5")
        )

    @Test
    def testFilterFail(): Unit \ Assert =
        Assert.assertTrue(
            Result.isErr(parse(filter(c -> c >= '5', "big digit", digit()), "3"))
        )

    @Test
    def testMany1(): Unit \ Assert =
        Assert.assertEq(expected = Ok('a' :: 'a' :: Nil), parse(many1(char('a')), "aa"))

}
