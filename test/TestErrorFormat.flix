mod TestErrorFormat {

    use MiniParse.Core.{ParseError, Position, parse}
    use MiniParse.Combinator.{digit, digits}
    use MiniParse.ErrorFormat.{
        formatError, formatNeedInput, formatResult, formatStreamStep,
        formatSuspendOutcome, dedupe, lineAt
    }
    use MiniParse.Stream.{open, feed, step, close}
    use MiniParse.Suspend.{startWith, string}

    @Test
    def testFormatErrorCaret(): Unit \ Assert = {
        let err = ParseError.Error(Position.Position(4, 1, 5), "digit" :: Nil);
        let msg = formatError("150-x002", err);
        Assert.assertTrue(String.contains(substr = "parse error", msg));
        Assert.assertTrue(String.contains(substr = "line 1", msg));
        Assert.assertTrue(String.contains(substr = "digit", msg));
        Assert.assertTrue(String.contains(substr = "^", msg))
    }

    @Test
    def testFormatErrorDedupeExpected(): Unit \ Assert = {
        let err = ParseError.Error(
            Position.Position(0, 1, 1),
            "digit" :: "digit" :: "letter" :: "digit" :: Nil
        );
        let msg = formatError("x", err);
        Assert.assertTrue(String.contains(substr = "expected: digit or letter", msg))
    }

    @Test
    def testFormatNeedInput(): Unit \ Assert = {
        let msg = formatNeedInput("12", Position.Position(2, 1, 3));
        Assert.assertTrue(String.contains(substr = "incomplete input", msg));
        Assert.assertTrue(String.contains(substr = "more input", msg));
        Assert.assertTrue(String.contains(substr = "^", msg))
    }

    @Test
    def testFormatResultErr(): Unit \ Assert =
        Assert.assertTrue(
            String.contains(
                substr = "parse error",
                formatResult("xy", parse(digit(), "xy"))
            )
        )

    @Test
    def testFormatResultOk(): Unit \ Assert =
        Assert.assertEq(expected = "ok", formatResult("5", parse(digit(), "5")))

    @Test
    def testFormatStreamAwait(): Unit \ Assert = {
        let st = step(digits(3), feed("12", open()));
        let msg = formatStreamStep("12", st);
        Assert.assertTrue(String.contains(substr = "incomplete input", msg))
    }

    @Test
    def testFormatStreamFail(): Unit \ Assert = {
        let st = step(digit(), feed("x", open()));
        let msg = formatStreamStep("x", st);
        Assert.assertTrue(String.contains(substr = "parse error", msg))
    }

    @Test
    def testFormatSuspendAwait(): Unit \ Assert = {
        let o = startWith(string("abc"), "ab");
        let msg = formatSuspendOutcome("ab", o);
        Assert.assertTrue(String.contains(substr = "incomplete input", msg))
    }

    @Test
    def testFormatSuspendFail(): Unit \ Assert = {
        let o = startWith(string("ab"), "ax");
        let msg = formatSuspendOutcome("ax", o);
        Assert.assertTrue(String.contains(substr = "parse error", msg))
    }

    @Test
    def testDedupe(): Unit \ Assert =
        Assert.assertEq(
            expected = "a" :: "b" :: Nil,
            dedupe("a" :: "b" :: "a" :: "b" :: Nil)
        )

    @Test
    def testLineAt(): Unit \ Assert =
        Assert.assertEq(expected = "second", lineAt("first\nsecond\nthird", 2))

}
