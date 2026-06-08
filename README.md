# cr_1brc

A Crystal take on the [One Billion Row Challenge](https://github.com/gunnarmorling/1brc),
done as an iterative optimization exercise: start with a deliberately naive
implementation, then improve it one isolated change at a time and measure the
effect of each.

The goal here is **not** to top the leaderboard. It's to rediscover the
performance techniques from the ground up, one rung at a time, and keep an
honest record of what each change actually bought.

## The problem

Read a file of ~1,000,000,000 rows in the format `<station>;<temperature>`,
where the temperature always has exactly one fractional digit:

```
Hamburg;12.0
Bulawayo;8.9
St. John's;15.2
```

Compute the min, mean, and max temperature per station and print them sorted
by station name:

```
{Abha=-23.0/18.0/59.2, Abidjan=-16.2/26.0/67.3, ...}
```

Mean and the min/max are each rounded to one fractional digit.

## Layout

Each optimization step is its own entry file under `src/`, wired up as a named
build target in `shard.yml`. Every version coexists in the tree, so any two
rungs can be benchmarked against each other directly without checking out a
different commit.

```yaml
# shard.yml
targets:
  naive:
    main: src/naive.cr
  int:
    main: src/int.cr
  # ...one target per milestone
```

Shared, version-independent code (output formatting, the sorted print, the
stats merge) lives in `src/common.cr` and is `require`d by each increment, so
each `src/*.cr` contains only the delta for that rung.

Milestones are tagged in git (`m1-naive`, `m2-int`, ...). `git log --oneline`
is the changelog; `git checkout <tag>` reproduces any rung.

## Build & run

```sh
# build one target
shards build --release naive

# build all targets
shards build --release

# run against a data file (path is required; no hardcoded default)
./bin/naive measurements_10m.txt
```

Iterate on the 10M file (sub-second feedback) and only run the 1B file at
milestone tags to confirm a speedup holds at scale.

## Generating the data

The data files are **not** committed (they're 130 MB / 13 GB and trivially
regenerable). Generate them with the official Java generator:

```sh
git clone https://github.com/gunnarmorling/1brc
cd 1brc
./mvnw clean verify                 # needs JDK 21
java -cp target/average-1.0.0-SNAPSHOT.jar \
     dev.morling.onebrc.CreateMeasurements 10000000
```

The generator writes to `./measurements.txt` (the row count is the only
argument). Rename per size and move them next to this repo:

```sh
mv measurements.txt measurements_10m.txt
# ...and a second run with 1000000000 for measurements_1b.txt
```

## Correctness

`expected_10m.out` is the frozen golden output, originally produced by the
reference `CalculateAverage_baseline` from the 1brc repo on the 10M file. It is
tracked (one ~13 KB line). `verify.sh` runs a built binary and diffs its output
against it:

```sh
./verify.sh ./bin/naive measurements_10m.txt
```

Both outputs are a single comma-joined line, so the script splits on commas
before diffing to get per-station results. A clean diff means the rung is
correct; run it at every milestone before recording a time.

Note on rounding: the original golden file reflects float summation with
half-to-even rounding. Once integer/fixed-point parsing lands and rounding is
made explicit (half-up, per the spec), a handful of means may legitimately
shift by 0.1. That is the implementation becoming *more* correct, not a
regression — regenerate `expected_10m.out` from that rung once the deltas are
confirmed to be rounding-only, and note it in `RESULTS.md`.

## Milestones

| #  | Step                        | Idea                                                        | Status  |
|----|-----------------------------|-------------------------------------------------------------|---------|
| m1 | Naive baseline              | `split` on `;`, `Float64` parse, `Hash` aggregate           | ✅ done |
| m2 | Integer temperatures        | Parse to tenths as `Int64`; exact sum, no `to_f`            | ✅ done |
| m3 | Parse in place              | Drop `split`; scan bytes, no per-line substrings            | planned |
| m4 | Reusable read buffer / mmap | Stop minting a `String` per line                            | planned |
| m5 | Custom byte-keyed map        | Open-addressing table keyed on name bytes                  | planned |
| m6 | Parallelize                 | Split input across cores, local maps, merge                 | planned |
| m7 | SWAR / branchless           | Word-at-a-time delimiter scan, branch-free parse — if hot   | planned |

Order is the *expected* hot path, not gospel: after m3, profile before picking
the next rung rather than assuming.

## Results

See the [RESULTS.md] file

## Credits

The challenge, data generator, reference baseline, and the techniques being
rediscovered here are all from Gunnar Morling's
[1brc](https://github.com/gunnarmorling/1brc). Results write-up:
[1BRC — The Results Are In!](https://www.morling.dev/blog/1brc-results-are-in/).
