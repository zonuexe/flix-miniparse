mod TestSuspend {

    use MiniParse.Suspend.{
        pure, char, digit, digits, string, andThen, map, flatMap, eof,
        start, startWith, feed, close, pump, parseChunks, drive, countSuspends,
        Outcome, Event, Suspended
    }
    use MiniParse.Core.{initialPosition}
    use Examples.SuspendDemo.{
        Postal, postal, parsePostalChunks, drivePostal, manualFeedCount, threeDigits
    }

    ///////////////////////////////////////////////////////////////////////////
    // Basic CoParser
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testString(): Unit \ Assert =
        Assert.assertEq(expected = Ok("hi"), parseChunks(string("hi"), "hi" :: Nil))

    @Test
    def testDigits(): Unit \ Assert =
        Assert.assertEq(expected = Ok("150"), parseChunks(digits(3), "150" :: Nil))

    @Test
    def testAndThen(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(('a', 'b')),
            parseChunks(
                flatMap(x -> map(y -> (x, y), char('b')), char('a')),
                "ab" :: Nil
            )
        )

    ///////////////////////////////////////////////////////////////////////////
    // True suspension
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testAwaitMidString(): Unit \ Assert =
        match startWith(string("abc"), "ab") {
            case Outcome.Await(_) => ()
            case other => Assert.fail("expected Await, got ${other}")
        }

    @Test
    def testResumeAfterAwait(): Unit \ Assert =
        match startWith(string("abc"), "ab") {
            case Outcome.Await(s) =>
                match feed("c", s) {
                    case Outcome.Done(x, rest) =>
                        Assert.assertEq(expected = "abc", x);
                        Assert.assertTrue(String.isEmpty(rest))
                    case other => Assert.fail("expected Done, got ${other}")
                }
            case other => Assert.fail("expected Await first, got ${other}")
        }

    @Test
    def testCloseEof(): Unit \ Assert =
        match startWith(andThen(char('a'), eof()), "a") {
            case Outcome.Done(_, _) => ()
            case Outcome.Await(s) =>
                match close(s) {
                    case Outcome.Done(_, _) => ()
                    case other => Assert.fail("expected Done after close, got ${other}")
                }
            case other => Assert.fail("unexpected ${other}")
        }

    @Test
    def testFailDoesNotAwait(): Unit \ Assert =
        match startWith(char('a'), "x") {
            case Outcome.Fail(_) => ()
            case other => Assert.fail("expected Fail, got ${other}")
        }

    @Test
    def testDigitsAcrossChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok("150"),
            parseChunks(digits(3), "1" :: "5" :: "0" :: Nil)
        )

    @Test
    def testCountSuspends(): Unit \ Assert =
        Assert.assertTrue(countSuspends(digits(3), "1" :: "5" :: "0" :: Nil) >= 1)

    ///////////////////////////////////////////////////////////////////////////
    // Postal demo
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testPostalChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(Postal.Postal("150", "0002")),
            parsePostalChunks("15" :: "0-" :: "0002" :: Nil)
        )

    @Test
    def testPostalDrive(): Unit \ Assert = {
        let (res, ev) = drivePostal("150" :: "-" :: "0002" :: Nil);
        Assert.assertEq(expected = Ok(Postal.Postal("150", "0002")), res);
        Assert.assertTrue(List.exists(e -> match e {
            case Event.Completed => true
            case _               => false
        }, ev))
    }

    @Test
    def testManualFeedSuspendCount(): Unit \ Assert =
        match manualFeedCount("15" :: "0-00" :: "02" :: Nil) {
            case Ok((Postal.Postal("150", "0002"), n)) =>
                Assert.assertTrue(n >= 1)
            case other =>
                Assert.fail("unexpected ${other}")
        }

    @Test
    def testIncompleteFailsAfterClose(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseChunks(digits(3), "12" :: Nil)))

}
