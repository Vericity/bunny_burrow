require 'pry'
require 'simplecov'
require 'simplecov-rcov'

# As recommended by RSpec 3, enable verifying partial doubles.
RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end

# SimpleCov must be started before loading any application code.
SimpleCov.start do
  add_filter 'spec'
  add_filter 'vendor'
end

class SimpleCov::Formatter::MergedFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format result
    SimpleCov::Formatter::RcovFormatter.new.format result
  end
end
SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'bunny_burrow'
