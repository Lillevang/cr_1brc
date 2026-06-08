# m3: parse in place.
# Change vs m2: drop `split`. Scan for ';' directly on the line's byte slice and
# parse the temperature straight from the bytes. This removes two of the three
# per-row allocations split caused (the Array and the temp String). The name
# String remains because it's the Hash key — removing that is m5's job.
#
# Run:  shards build --release inplace && ./bin/inplace measurements_10m.txt

require "./common"

SEMI  = ';'.ord.to_u8
DOT   = '.'.ord.to_u8
MINUS = '-'.ord.to_u8
ZERO  = '0'.ord.to_u8

# Parse the temperature (tenths) from `bytes`, starting at `start` (the index
# just past ';') to the end of the slice. No substring is allocated.
# ';' / '.' / '-' / digits are all ASCII (< 0x80), so they can never appear
# inside a UTF-8 multibyte character — byte scanning is correct for names like
# "Zürich" too.
def parse_temp(bytes : Bytes, start : Int32) : Int32
  i = start
  neg = false
  if bytes[i] == MINUS
    neg = true
    i += 1
  end
  v = 0
  n = bytes.size
  while i < n
    b = bytes[i]
    v = v * 10 + (b - ZERO).to_i if b != DOT
    i += 1
  end
  neg ? -v : v
end

path = ARGV[0]? || "measurements.txt"
stats = Hash(String, Stat).new

File.each_line(path) do |line|
  bytes = line.to_slice          # zero-copy view of the line's bytes
  sep = bytes.index(SEMI).not_nil!
  name = String.new(bytes[0, sep]) # the one remaining per-row allocation
  v = parse_temp(bytes, sep + 1)
  if s = stats[name]?
    s.add(v)
  else
    stats[name] = Stat.new(v)
  end
end

print_results(stats)
