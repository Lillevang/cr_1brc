# Results

Running log of each optimization rung: what changed, what it measured, and —
more importantly — what was surprising.

**Conditions:** single dev box, WSL2, data file on native ext4, warm page
cache. Times are relative to each other, **not** comparable to the official
1brc leaderboard (different hardware, different key set). The number that
matters is the speedup vs m1, not the absolute seconds.

Iteration happens on the 10M file; the 1B time is captured only at milestone
tags. Use `hyperfine --warmup 1` for the deltas between rungs once more than
one target exists; single `time` runs are fine for the headline baseline.

## Timings

| #  | Step                        | 10M     | 1B    | Speedup vs m1 | Correct? | Notes                              |
|----|-----------------------------|---------|-------|---------------|----------|------------------------------------|
| m1 | Naive baseline              | ~0.72 s | ~74 s | 1.0×          | ✅        | `split` + `Float64` + `Hash`; single core, 99% CPU, IO-light |
| m2 | Integer temperatures        | —       | —     | —             | —        | parse to tenths as `Int64`         |
| m3 | Parse in place              | —       | —     | —             | —        | drop `split`, scan bytes           |
| m4 | Reusable read buffer / mmap | —       | —     | —             | —        |                                    |
| m5 | Custom byte-keyed map        | —       | —     | —             | —        |                                    |
| m6 | Parallelize                 | —       | —     | —             | —        | first multi-core rung              |
| m7 | SWAR / branchless           | —       | —     | —             | —        | only if profiling says scan is hot |

For each rung, record: 10M time, 1B time (at tag), speedup, and `verify.sh`
pass/fail **before** the time counts.

## Findings

The surprises, kept as they happen — this is the spine of the eventual
write-up.

- **m1, 1B scaled dead-linearly from 10M.** 0.72 s × 100 ≈ 72 s; actual was
  71.98 s user. The expectation that ~3 billion short-lived allocations from
  `split` would push GC into superlinear blowup was *wrong* — Crystal's GC
  absorbed them at steady state. Consequence: removing `split` (m3) is a
  *constant per-row overhead* win, not an *escape from a blowup*. Calibrate the
  expected gain down accordingly.
- **m1 matched the reference output byte-for-byte at 10M.** The anticipated
  float-drift / half-even-vs-half-up rounding mismatch never surfaced at this
  scale. Open question for later: whether more accumulation at 1B drifts a mean
  by 0.1 — moot once m2 makes the sum exact.

## Method notes

- Baseline correctness reference: `expected_10m.out`, diffed via `verify.sh`.
- One target per rung in `shard.yml`; build with `shards build --release <target>`.
- If a rung changes rounding to match the spec (half-up), regenerate
  `expected_10m.out` from that rung after confirming the deltas are rounding-only.
