mod TestStream {

    use MiniParse.Stream.{
        open, feed, close, step, push, parseChunks, drive, looksLikeNeedInput,
        StreamState, Step, DriveEvent, offset, buffer, compact, isClosed
    }
    use MiniParse.Combinator.{digits, char, string}
    use MiniParse.Core.{parse}
    use Examples.StreamDemo.{
        parsePostalChunks, parseJsonChunks, drivePostal, stepDigits3, countAwaits
    }
    use Examples.PostalCode.{PostalCode}
    use Examples.Json.{JsonValue}

    ///////////////////////////////////////////////////////////////////////////
    // Buffer plumbing
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testFeedAppends(): Unit \ Assert = {
        let s = feed("cd", feed("ab", open()));
        Assert.assertEq(expected = "abcd", buffer(s));
        Assert.assertTrue(not isClosed(s))
    }

    @Test
    def testClose(): Unit \ Assert =
        Assert.assertTrue(isClosed(close(open())))

    @Test
    def testCompact(): Unit \ Assert = {
        match push(char('a'), "ab", open()) {
            case Step.Done(_, s1) =>
                let s2 = compact(s1);
                Assert.assertEq(expected = "b", buffer(s2));
                Assert.assertEq(expected = 0, offset(s2))
            case _ => Assert.fail("expected Done")
        }
    }

    ///////////////////////////////////////////////////////////////////////////
    // step / Await
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testAwaitWhenShort(): Unit \ Assert =
        match push(digits(3), "12", open()) {
            case Step.Await(_) => ()
            case other => Assert.fail("expected Await, got ${other}")
        }

    @Test
    def testDoneWhenEnough(): Unit \ Assert =
        match push(digits(3), "123", open()) {
            case Step.Done(x, _) => Assert.assertEq(expected = "123", x)
            case other => Assert.fail("expected Done, got ${other}")
        }

    @Test
    def testFailAfterClose(): Unit \ Assert =
        match step(digits(3), close(feed("12", open()))) {
            case Step.Fail(_) => ()
            case other => Assert.fail("expected Fail after close, got ${other}")
        }

    @Test
    def testHardFailNotAwait(): Unit \ Assert =
        // 'x' is not a digit — real failure even if stream open.
        match push(digits(3), "x12", open()) {
            case Step.Fail(_) => ()
            case other => Assert.fail("expected Fail, got ${other}")
        }

    @Test
    def testStepDigitsAcrossChunks(): Unit \ Assert =
        Assert.assertEq(expected = Ok("150"), stepDigits3("1" :: "5" :: "0" :: Nil))

    ///////////////////////////////////////////////////////////////////////////
    // parseChunks drivers
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testPostalChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(PostalCode.PostalCode("150", "0002")),
            parsePostalChunks("15" :: "0-00" :: "02" :: Nil)
        )

    @Test
    def testPostalChunksWithMark(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(PostalCode.PostalCode("150", "0002")),
            parsePostalChunks("〒15" :: "0-" :: "0002" :: Nil)
        )

    @Test
    def testJsonChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JArray(
                JsonValue.JNumber(1.0) :: JsonValue.JNumber(2.0) :: Nil
            )),
            parseJsonChunks("[" :: "1, " :: "2]" :: Nil)
        )

    @Test
    def testJsonObjectChunks(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JObject(
                ("a", JsonValue.JBool(true)) :: Nil
            )),
            parseJsonChunks("{\"a\":" :: " true}" :: Nil)
        )

    @Test
    def testIncompleteAfterCloseFails(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseChunks(digits(3), "12" :: Nil)))

    ///////////////////////////////////////////////////////////////////////////
    // drive trace
    ///////////////////////////////////////////////////////////////////////////

    @Test
    def testDriveSeesAwait(): Unit \ Assert = {
        let (res, ev) = drivePostal("15" :: "0-0002" :: Nil);
        Assert.assertTrue(Result.isOk(res));
        Assert.assertTrue(List.exists(e -> match e {
            case DriveEvent.GotAwait => true
            case _                   => false
        }, ev))
    }

    @Test
    def testCountAwaitsPositive(): Unit \ Assert =
        Assert.assertTrue(countAwaits(digits(4), "1" :: "2" :: "3" :: "4" :: Nil) >= 1)

}
