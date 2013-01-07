require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

task 'setup_dummy_app' do
  unless File.exists? "test/dummy/db/test.sqlite3"
    Bundler.with_clean_env do
      sh "cd test/dummy; bundle; rake db:migrate; rake db:test:prepare; cd ../../;"
    end
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

task :default => [:setup_dummy_app, :test]
