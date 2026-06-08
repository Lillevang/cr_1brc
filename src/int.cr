
# m2: integer temperatures.
# Only change vs m1: parse the temperature to tenths as an integer instead of
# Float64, and store sums exactly as Int64. Still split on ';' (that's m3's
# job) so the parse/storage change is the single isolated variable.
#
# Run:  shards build --release int && ./bin/int measurements_10m.txt

require "./common"

# Parse a temperature like "-12.3" or "5.0" into tenths: -123, 50.
# Format is guaranteed [-]?\d{1,2}\.\d, so a flat byte walk suffices.
def parse_temp(s : String) : Int32
  bytes = s.to_slice
  i = 0
  neg = false
  if bytes[0] == '-'.ord
    neg = true
    i = 1
  end
  v = 0
  while i < bytes.size
    b = bytes[i]
    v = v * 10 + (b.to_i - '0'.ord) if b != '.'.ord
    i += 1
  end
  neg ? -v : v
end

path = ARGV[0]? || "measurements.txt"
stats = Hash(String, Stat).new

File.each_line(path) do |line|
  name, temp_str = line.split(';', 2)
  v = parse_temp(temp_str)
  if s = stats[name]?
    s.add(v)
  else
    stats[name] = Stat.new(v)
  end
end

print_results(stats)
