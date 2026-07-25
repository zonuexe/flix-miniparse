///
/// Shared timing harness (wall-clock via `System.nanoTime`).
///
/// Results of each iteration are accumulated so pure work is not DCE'd.
///
mod Bench {

    import java.lang.System

    pub enum Sample with ToString {
        case Sample(
            String, // library
            String, // task
            Int32,  // size
            Bool,   // last-run success
            Int64,  // mean nanoseconds per iteration
            Int64,  // total nanoseconds
            Int32   // iterations
        )
    }

    pub def nowNs(): Int64 \ IO = System.nanoTime()

    /// Warm up, then measure mean ns/iter. Accumulators keep `thunk` live.
    pub def measure(
        warmup: Int32,
        iters: Int32,
        thunk: Unit -> Bool \ ef
    ): (Bool, Int64, Int64) \ {ef, IO} = {
        def go(i: Int32, last: Bool, hits: Int32): (Bool, Int32) \ ef =
            if (i <= 0)
                (last, hits)
            else {
                let ok = thunk();
                go(i - 1, ok, hits + (if (ok) 1 else 0))
            };
        let (_, h0) = go(warmup, false, 0);
        let t0 = nowNs();
        let (ok, h1) = go(iters, false, h0);
        let t1 = nowNs();
        // Escape hits so the warm loop is not eliminated either.
        let ok2 = ok and (h1 >= 0);
        let total = t1 - t0;
        let n = Int32.toInt64(iters);
        let mean =
            if (n <= 0i64)
                0i64
            else
                total / n;
        (ok2, mean, total)
    }

    pub def runSample(
        lib: String,
        task: String,
        size: Int32,
        warmup: Int32,
        iters: Int32,
        thunk: Unit -> Bool \ ef
    ): Sample \ {ef, IO} = {
        let (ok, mean, total) = measure(warmup, iters, thunk);
        Sample.Sample(lib, task, size, ok, mean, total, iters)
    }

    pub def formatHeader(): String =
        pad(12, "library") + " | " +
        pad(14, "task") + " | " +
        pad(8, "size") + " | " +
        pad(4, "ok") + " | " +
        pad(12, "ns/iter") + " | " +
        pad(12, "total-ns") + " | iters"

    pub def formatSep(): String =
        String.repeat(12, "-") + "-+-" +
        String.repeat(14, "-") + "-+-" +
        String.repeat(8, "-") + "-+-" +
        String.repeat(4, "-") + "-+-" +
        String.repeat(12, "-") + "-+-" +
        String.repeat(12, "-") + "-+-" +
        String.repeat(6, "-")

    pub def formatSample(s: Sample): String = match s {
        case Sample.Sample(lib, task, size, ok, mean, total, iters) =>
            pad(12, lib) + " | " +
            pad(14, task) + " | " +
            pad(8, "${size}") + " | " +
            pad(4, if (ok) "Y" else "N") + " | " +
            pad(12, "${mean}") + " | " +
            pad(12, "${total}") + " | ${iters}"
    }

    pub def formatTable(rows: List[Sample]): String =
        List.join("\n", formatHeader() :: formatSep() :: List.map(formatSample, rows))

    def pad(width: Int32, s: String): String = {
        let n = String.length(s);
        if (n >= width)
            String.slice(start = 0, end = width, s)
        else
            s + String.repeat(width - n, " ")
    }

}
