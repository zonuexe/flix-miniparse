mod TestCore {

    use MiniParse.Core.{parse, parsePartial, pure, fail, initState, runParser, stateOffset}
    use MiniParse.Combinator.{
        char, digit, digits, string, satisfy, map, flatMap, andThen, eof, count, many, optional
    }

    @Test
    def testCharOk(): Unit \ Assert =
        Assert.assertEq(expected = Ok('a'), parse(char('a'), "a"))

    @Test
    def testCharFail(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(char('a'), "b")))

    @Test
    def testDigit(): Unit \ Assert =
        Assert.assertEq(expected = Ok('7'), parse(digit(), "7"))

    @Test
    def testDigits(): Unit \ Assert =
        Assert.assertEq(expected = Ok("150"), parse(digits(3), "150"))

    @Test
    def testString(): Unit \ Assert =
        Assert.assertEq(expected = Ok("foo"), parse(string("foo"), "foo"))

    @Test
    def testMap(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(42),
            parse(map(c -> Char.getNumericValue(c) |> Option.getWithDefault(0), digit()), "6")
                |> Result.map(n -> n * 7)
        )

    @Test
    def testFlatMapSequence(): Unit \ Assert = {
        let p = flatMap(a ->
            map(b -> "${a}${b}", char('b')),
            char('a')
        );
        Assert.assertEq(expected = Ok("ab"), parse(p, "ab"))
    }

    @Test
    def testAndThenEof(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(andThen(char('a'), eof()), "ab")))

    @Test
    def testPartialLeavesRemainder(): Unit \ Assert = {
        match parsePartial(char('x'), "xy") {
            case Ok((_, s)) => Assert.assertEq(expected = 1, stateOffset(s))
            case Err(_)     => Assert.fail("expected success")
        }
    }

    @Test
    def testCount(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('1' :: '2' :: '3' :: Nil),
            parse(count(3, digit()), "123")
        )

    @Test
    def testMany(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('a' :: 'a' :: 'a' :: Nil),
            parse(many(char('a')), "aaa")
        )

    @Test
    def testOptionalPresent(): Unit \ Assert =
        Assert.assertEq(expected = Ok(Some('x')), parse(optional(char('x')), "x"))

    @Test
    def testOptionalAbsent(): Unit \ Assert =
        Assert.assertEq(expected = Ok(None), parse(optional(char('x')), ""))

    @Test
    def testSatisfy(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok('Z'),
            parse(satisfy(Char.isUpperCase, "upper"), "Z")
        )

    @Test
    def testPure(): Unit \ Assert =
        Assert.assertEq(expected = Ok(123), parse(pure(123), ""))

    @Test
    def testFail(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parse(fail("nope"), "x")))

}
