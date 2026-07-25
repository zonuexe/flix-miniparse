///
/// Microbenchmark: miniparse vs flix-parsec (local fpkgs under bench/lib).
///
/// From repository root:
/// ```bash
/// bash bench/scripts/install-local-deps.sh
/// cd bench && JAVA_OPTS='-Xss8m' flix run
/// ```
///
def main(): Unit \ IO = {
    println("parser-bench: miniparse vs flix-parsec");
    println("note: wall-clock means; run several times / raise iters for stable numbers");
    println("");

    // Modest defaults so `flix run` finishes quickly. Edit here for real profiling.
    // If flix-parsec StackOverflowError appears, re-run with a larger JVM stack, e.g.:
    //   JAVA_OPTS='-Xss8m' flix run
    let warmup = 5;
    let iters = 50;
    let sizes = Tasks.defaultSizes();

    println("warmup=${warmup}  iters=${iters}  sizes=${sizes}");
    println("");

    let rows = Tasks.runSuite(warmup, iters, sizes);
    println(Bench.formatTable(rows));

    println("");
    println("legend:");
    println("  miniparse     pure MiniParse.Core.Parser");
    println("  miniparse-co  MiniParse.Suspend.CoParser (whole string as one chunk)");
    println("  flix-parsec   FlixParsec GenParser (2-CPS)");
    println("  ns/iter       mean wall time after warmup (System.nanoTime)");
    println("  total-ns      sum of timed iterations (not including warmup)");
    println("  ok            last iteration parsed successfully");
    ()
}
