/// Demo: Step 0 postal codes + Step 1 JSON.
def main(): Unit \ IO = {
    use Examples.PostalCode.{parsePostalCode, format};
    use Examples.Json.{parseJson};

    println("== Postal codes ==");
    let posts = "150-0002" :: "〒150-0002" :: "150-000" :: Nil;
    foreach (s <- posts) {
        match parsePostalCode(s) {
            case Ok(pc) => println("OK  `${s}` -> ${format(pc)}")
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    };

    println("");
    println("== JSON ==");
    let samples =
        "null" ::
        "true" ::
        "42" ::
        "\"hi\\n\"" ::
        "[1, 2, 3]" ::
        "{\"a\": 1, \"b\": [null, false]}" ::
        "{bad}" ::
        Nil;
    foreach (s <- samples) {
        match parseJson(s) {
            case Ok(v)  => println("OK  `${s}` -> ${v}")
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    }
}
