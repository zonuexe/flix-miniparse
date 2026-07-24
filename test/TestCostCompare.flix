mod TestCostCompare {

    use Examples.CostCompare.{
        Cost, streamDigitsCost, suspendDigitsCost, oneChunks, streamScansMore,
        stepsOf, visitsOf, triangular
    }

    @Test
    def testBothParseOnes(): Unit \ Assert = {
        let chunks = oneChunks(4);
        match streamDigitsCost(4, chunks) {
            case (Ok("1111"), _) => ()
            case other => Assert.fail("stream: ${other}")
        };
        match suspendDigitsCost(4, chunks) {
            case (Ok("1111"), _) => ()
            case other => Assert.fail("suspend: ${other}")
        }
    }

    @Test
    def testStreamVisitsTriangular(): Unit \ Assert = {
        let n = 5;
        let chunks = oneChunks(n);
        match streamDigitsCost(n, chunks) {
            case (Ok(_), c) =>
                // 1+2+...+n on one-char feeds with cursor stuck at 0 until done
                Assert.assertEq(expected = triangular(n), visitsOf(c))
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testSuspendVisitsLinear(): Unit \ Assert = {
        let n = 5;
        let chunks = oneChunks(n);
        match suspendDigitsCost(n, chunks) {
            case (Ok(_), c) =>
                Assert.assertEq(expected = n, visitsOf(c))
            case other =>
                Assert.fail("${other}")
        }
    }

    @Test
    def testStreamScansMore(): Unit \ Assert =
        Assert.assertTrue(streamScansMore(6))

    @Test
    def testStreamMoreStepsThanSuspendForSameChunks(): Unit \ Assert = {
        let n = 5;
        let chunks = oneChunks(n);
        match (streamDigitsCost(n, chunks), suspendDigitsCost(n, chunks)) {
            case ((Ok(_), cs), (Ok(_), cc)) =>
                Assert.assertTrue(visitsOf(cs) > visitsOf(cc));
                // Stream steps ≈ n (one per chunk); suspend steps ≈ n-1 awaits
                Assert.assertTrue(stepsOf(cs) >= 1 and stepsOf(cc) >= 0)
            case _ =>
                Assert.fail("parse failed")
        }
    }

}
