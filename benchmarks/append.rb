require 'benchmark/ips'

def slow_plus
  x = 'foo'
  x += 'bar'
end

def slow_concat
  x = 'foo'
  x.concat 'bar'
end

def fast_append
  x = 'foo'
  x << 'bar'
end

def fast_interpolation
  x = 'foo'
  x = "#{x}bar"
end

Benchmark.ips do |x|
  x.report('x += "bar"')             { slow_plus }
  x.report('x.concat("bar")')        { slow_concat }
  x.report('x << "bar"')             { fast_append }
  x.report('x = "#{x}#{\'bar\'}"')   { fast_interpolation }
  x.compare!
end
