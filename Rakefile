require 'rubygems'
require 'bundler/setup'
Bundler::GemHelper.install_tasks
require 'appraisal'

require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
