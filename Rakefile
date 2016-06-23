require 'rubygems'
require 'bundler/setup'
Bundler::GemHelper.install_tasks
require 'appraisal'

require 'rake/testtask'

task :default => :test

Rake::TestTask.new(:test => :setup_dummy_app) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

task 'setup_dummy_app' do
  unless File.exists? "test/dummy/db/test.sqlite3"
    Bundler.with_clean_env do
      sh "cd test/dummy && bundle && bundle exec rake db:setup db:test:prepare"
    end
  end
end
