/// Demo entry point for Step 0 (postal-code parser).
def main(): Unit \ IO = {
    use Examples.PostalCode.{parsePostalCode, format};

    let samples = "150-0002" :: "〒150-0002" :: "150-000" :: "hello" :: Nil;
    foreach (s <- samples) {
        match parsePostalCode(s) {
            case Ok(pc) => println("OK  `${s}` -> ${format(pc)}")
            case Err(e) => println("ERR `${s}` -> ${e}")
        }
    }
}
