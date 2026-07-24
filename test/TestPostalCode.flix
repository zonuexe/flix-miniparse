mod TestPostalCode {

    use Examples.PostalCode.{PostalCode, parsePostalCode, format}

    @Test
    def testPlain(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(PostalCode.PostalCode("150", "0002")),
            parsePostalCode("150-0002")
        )

    @Test
    def testWithMark(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(PostalCode.PostalCode("150", "0002")),
            parsePostalCode("〒150-0002")
        )

    @Test
    def testFormat(): Unit \ Assert =
        Assert.assertEq(
            expected = "150-0002",
            format(PostalCode.PostalCode("150", "0002"))
        )

    @Test
    def testTooShort(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parsePostalCode("150-000")))

    @Test
    def testMissingHyphen(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parsePostalCode("1500002")))

    @Test
    def testGarbage(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parsePostalCode("hello")))

    @Test
    def testTrailingJunk(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parsePostalCode("150-0002x")))

}
