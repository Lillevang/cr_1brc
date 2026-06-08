# 1BRC — milestone 1: naive but correct.
# Deliberately unoptimized: split on ';', parse Float64, Hash lookup.
# Run: crystal build --release brc_naive.cr && ./brc_naive measurements.txt

# Reference type (class, not struct) on purpose: a struct stored in a Hash
# is a value copy, so mutating it in place silently does nothing. Class avoids that trap.
class Stat
  property min : Float64
  property max : Float64
  property sum : Float64
  property count : Int32

  def initialize(v : Float64)
    @min = @max = @sum = v
    @count = 1
  end

  def add(v : Float64)
    @min = v if v < @min
    @max = v if v > @max
    @sum += v
    @count += 1
  end

  def mean : Float64
    sum / count
  end
end

path = ARGV[0]? || "measurements.txt"
stats = Hash(String, Stat).new

# each_line streams and chomps the newline -> O(1) memory, won't OOM on 1B rows.
File.each_line(path) do |line|
  name, temp_str = line.split(';', 2)
  temp = temp_str.to_f
  if s = stats[name]?
    s.add(temp)
  else
    stats[name] = Stat.new(temp)
  end
end

io = String::Builder.new
io << '{'
stats.keys.sort!.each_with_index do |name, i|
  io << ", " if i > 0
  s = stats[name]
  io << name << '=' << ("%.1f" % s.min) << '/' << ("%.1f" % s.mean) << '/' << ("%.1f" % s.max)
end
io << "}\n"
print io.to_s
