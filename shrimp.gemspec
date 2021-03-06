# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shrimp/version'

Gem::Specification.new do |gem|
  gem.name          = 'shrimp'
  gem.version       = Shrimp::VERSION
  gem.authors       = ['Manuel Kniep']
  gem.email         = %w(manuel@adeven.com)
  gem.description   = 'html to pdf with phantomjs'
  gem.summary       = 'a phantomjs based pdf renderer'
  gem.homepage      = 'http://github.com/adeven/shrimp'
  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.files.reject! { |fn| fn.include? 'script' }
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = %w(lib)
  gem.requirements << 'phantomjs, v1.6 or greater'
  gem.add_runtime_dependency 'json'
  gem.add_runtime_dependency 'god'
  # Developmnet Dependencies
  gem.add_development_dependency('rake', ['>=0.9.2'])
  gem.add_development_dependency('rspec', ['>= 2.2.0'])
  gem.add_development_dependency('rack-test', ['>= 0.5.6'])
  gem.add_development_dependency('rack', ['= 1.4.1'])
  gem.add_development_dependency('pry')
end
