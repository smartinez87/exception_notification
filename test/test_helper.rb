# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

begin
  require "coveralls"
  Coveralls.wear!
rescue LoadError
  warn "warning: coveralls gem not found; skipping Coveralls"
end

require File.expand_path("../dummy/config/environment.rb", __FILE__)
require "rails/test_help"
require File.expand_path("../dummy/test/test_helper.rb", __FILE__)

require "mocha/setup"

Rails.backtrace_cleaner.remove_silencers!
ExceptionNotifier.testing_mode!
