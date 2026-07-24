mod TestJson {

    use Examples.Json.{JsonValue, parseJson}

    @Test
    def testNull(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JNull), parseJson("null"))

    @Test
    def testBool(): Unit \ Assert = {
        Assert.assertEq(expected = Ok(JsonValue.JBool(true)), parseJson("true"));
        Assert.assertEq(expected = Ok(JsonValue.JBool(false)), parseJson(" false "))
    }

    @Test
    def testNumberInt(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JNumber(42.0)), parseJson("42"))

    @Test
    def testNumberNegFrac(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JNumber(-3.14)), parseJson("-3.14"))

    @Test
    def testNumberExp(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JNumber(1000.0)), parseJson("1e3"))

    @Test
    def testStringSimple(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JString("hi")), parseJson("\"hi\""))

    @Test
    def testStringEscapes(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JString("a\"b\\c\nd")),
            parseJson("\"a\\\"b\\\\c\\nd\"")
        )

    @Test
    def testStringUnicode(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JString("A")),
            parseJson("\"\\u0041\"")
        )

    @Test
    def testArray(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JArray(
                JsonValue.JNumber(1.0) :: JsonValue.JNumber(2.0) :: JsonValue.JNumber(3.0) :: Nil
            )),
            parseJson("[1, 2, 3]")
        )

    @Test
    def testEmptyArray(): Unit \ Assert =
        Assert.assertEq(expected = Ok(JsonValue.JArray(Nil)), parseJson("[]"))

    @Test
    def testObject(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JObject(
                ("a", JsonValue.JNumber(1.0)) :: ("b", JsonValue.JBool(true)) :: Nil
            )),
            parseJson("{\"a\": 1, \"b\": true}")
        )

    @Test
    def testNested(): Unit \ Assert =
        Assert.assertEq(
            expected = Ok(JsonValue.JObject(
                ("xs", JsonValue.JArray(
                    JsonValue.JNull :: JsonValue.JString("z") :: Nil
                )) :: Nil
            )),
            parseJson("{\"xs\": [null, \"z\"]}")
        )

    @Test
    def testInvalid(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseJson("{bad}")))

    @Test
    def testTrailingJunk(): Unit \ Assert =
        Assert.assertTrue(Result.isErr(parseJson("true false")))

}
