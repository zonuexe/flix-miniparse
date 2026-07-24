mod TestPackrat {

    use Examples.Packrat.{Stats, parseNaive, parseMemo, memoIsFaster}
    use MiniParse.ErrorFormat.{formatError}
    use MiniParse.Core.{ParseError, Position}

    @Test
    def testNaiveSingleA(): Unit \ Assert =
        match parseNaive("a") {
            case Ok(Stats.Stats(1, c)) =>
                Assert.assertTrue(c >= 1)
            case _ =>
                Assert.fail("expected Ok value 1")
        }

    @Test
    def testMemoSingleA(): Unit \ Assert =
        match parseMemo("a") {
            case Ok(Stats.Stats(1, c)) =>
                Assert.assertTrue(c >= 1)
            case _ =>
                Assert.fail("expected Ok value 1")
        }

    @Test
    def testNaiveTriple(): Unit \ Assert =
        match parseNaive("aaa") {
            case Ok(Stats.Stats(3, c)) =>
                Assert.assertTrue(c >= 3)
            case _ =>
                Assert.fail("expected Ok")
        }

    @Test
    def testMemoTripleValue(): Unit \ Assert =
        match parseMemo("aaa") {
            case Ok(Stats.Stats(3, _)) => ()
            case _ => Assert.fail("expected Ok value 3")
        }

    @Test
    def testMemoFewerEntries(): Unit \ Assert =
        // On "aaaa", naive should do more work than memoized.
        Assert.assertTrue(memoIsFaster("aaaa"))

    @Test
    def testMemoLinearish(): Unit \ Assert =
        match (parseMemo("aa"), parseMemo("aaaa")) {
            case (Ok(Stats.Stats(2, c2)), Ok(Stats.Stats(4, c4))) =>
                // Packrat: body entries grow roughly with n, not exponentially.
                // Require c4 to be less than naive explosion bound (e.g. < 50).
                Assert.assertTrue(c4 < 50 and c2 < c4 + 5)
            case _ =>
                Assert.fail("expected Ok")
        }

    @Test
    def testEmptyFails(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseMemo("")))

    @Test
    def testFormatError(): Unit \ Assert = {
        let err = ParseError.Error(Position.Position(4, 1, 5), "digit" :: Nil);
        let msg = formatError("150-x002", err);
        Assert.assertTrue(String.contains(substr = "line 1", msg));
        Assert.assertTrue(String.contains(substr = "digit", msg));
        Assert.assertTrue(String.contains(substr = "^", msg))
    }

}
