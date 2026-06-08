# Shared, version-independent code used by every milestone from m2 on.
# Holds the aggregation type, the output formatter, and the sorted print.
# Keeping these identical across rungs means any output difference between
# increments is provably a parsing/aggregation change, not formatting drift.

# All temperatures are stored as tenths-of-a-degree integers:
#   -12.3  ->  -123      5.0  ->  50
# min/max fit in Int32 (range -999..999). sum must be Int64: 1e9 rows times
# up to ~999 tenths overflows Int32.
class Stat
  property min : Int32
  property max : Int32
  property sum : Int64
  property count : Int32

  def initialize(v : Int32)
    @min = v
    @max = v
    @sum = v.to_i64
    @count = 1
  end

  def add(v : Int32) : Nil
    @min = v if v < @min
    @max = v if v > @max
    @sum += v
    @count += 1
  end

  # Mean in tenths, rounded half-up toward +inf to match the reference's
  # Math.round (floor(x + 0.5)). Crystal's Float#round is ties-to-even, which
  # would disagree on exact halves, so we do not use it.
  def mean_tenths : Int32
    ((sum.to_f / count) + 0.5).floor.to_i
  end
end

# Append a tenths-integer as a fixed one-decimal value, straight from integers
# (no Float, so no "%.1f" rounding semantics and no "-0.0" edge case).
def append_tenths(io : IO, v : Int32) : Nil
  if v < 0
    io << '-'
    v = -v
  end
  io << (v // 10) << '.' << (v % 10)
end

# Emit {Station=min/mean/max, ...} sorted by station name, trailing newline.
def print_results(stats : Hash(String, Stat)) : Nil
  io = String::Builder.new
  io << '{'
  first = true
  stats.keys.sort!.each do |name|
    io << ", " unless first
    first = false
    s = stats[name]
    io << name << '='
    append_tenths(io, s.min)
    io << '/'
    append_tenths(io, s.mean_tenths)
    io << '/'
    append_tenths(io, s.max)
  end
  io << "}\n"
  print io.to_s
end
