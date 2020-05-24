# frozen_string_literal: true

require 'benchmark/ips'
require 'json'

# Load Rails
Dir.chdir('/var/www/graphql/app') do
  load 'config/environment.rb'
end

def generate_hash(iteration = 0)
  ELEMENTS.times.map do |_|
    result = {
      'firstName' => 'John',
      'lastName' => 'Snow',
      'age' => 32,
    }

    result['children'] = generate_hash(iteration + 1) if iteration < NESTED
    result
  end
end

def generate_collector(collector, iteration = 0)
  ELEMENTS.times do
    collector.next
    collector.add('firstName', 'John')
    collector.add('lastName', 'Snow')
    collector.add('age', 32)

    if iteration < NESTED
      collector.start_stack
      generate_collector(collector, iteration + 1)
      collector.end_stack('children')
    end
  end
end

class JsonCollector < ActiveSupport::ProxyObject
  def initialize
    @current_array = nil
    @stack_array = []

    @current_value = ::String.new
    @stack_value = []
  end

  def start_stack
    @stack_array << @current_array
    @stack_value << @current_value

    @current_array = nil
    @current_value = ::String.new
  end

  def end_stack(key)
    result = to_s
    @current_array = @stack_array.pop
    @current_value = @stack_value.pop
    @current_value << %["#{key}":#{result},]
  end

  def add(key, value)
    @current_value << %["#{key}":#{value.to_json},]
  end

  def next
    if @current_array
      @current_value.chomp!(',')
      @current_value << '},{'
    else
      @current_array = true
    end
  end

  def to_s
    result = @current_value.delete_suffix(',')
    @current_array ? "[{#{result}}]" : "{#{result}}"
  end
end

ELEMENTS = 20
NESTED = 3

puts "Result for #{ELEMENTS + (ELEMENTS ** (NESTED + 1))} elements"
Benchmark.ips do |x|
  results = []
  x.report('Hash to JSON') { results << JSON.generate(generate_hash) }

  # x.report('JSON Collector') do
  #   col = JsonCollector.new
  #   generate_collector(col)
  #   results << col.to_s
  # end

  x.report('AS JSON Encode') do
    results << ActiveSupport::JSON.encode(generate_hash)
  end

  # unless results[1].eql?(results[0])
  #   puts results[0]
  #   puts results[1]
  #   raise 'Results does not match'
  # end

  x.compare!
end
