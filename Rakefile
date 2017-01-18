require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

task :pry do
  require 'pry'
  gem_name = File.basename(Dir.pwd)
  sh %(pry -I lib -r #{gem_name}.rb)
end
