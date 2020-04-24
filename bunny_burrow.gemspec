# coding: utf-8
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bunny_burrow/version'

Gem::Specification.new do |spec|
  spec.name                  = 'bunny_burrow'
  spec.version               = BunnyBurrow::VERSION
  spec.authors               = ['Vericity']
  spec.homepage              = 'https://github.com/Vericity/bunny_burrow'

  spec.summary               = 'RPC over RabbitMQ based on Bunny.'
  spec.description           = spec.summary
  spec.license               = 'MIT'

  spec.files                 = Dir['lib/**/*.rb']
  spec.require_paths         = ['lib']
  spec.required_ruby_version = '>= 2.5.0'

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'dotenv'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-nav'
  spec.add_development_dependency 'rake', '~> 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.8.0'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-rcov'

  spec.add_runtime_dependency 'bunny', '~> 2.3'
end
