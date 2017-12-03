Gem::Specification.new do |s|
  s.name = 'exception_notification'
  s.version = '4.2.2'
  s.authors = ["Jamis Buck", "Josh Peek"]
  s.date = %q{2017-08-12}
  s.summary = "Exception notification for Rails apps"
  s.homepage = "https://smartinez87.github.io/exception_notification/"
  s.email = "smartinez87@gmail.com"
  s.license = "MIT"

  s.required_ruby_version     = '>= 2.0'
  s.required_rubygems_version = '>= 1.8.11'

  s.files = `git ls-files`.split("\n")
  s.files -= `git ls-files -- .??*`.split("\n")
  s.test_files = `git ls-files -- test`.split("\n")
  s.require_path = 'lib'

  s.add_dependency("actionmailer", ">= 4.0", "< 6")
  s.add_dependency("activesupport", ">= 4.0", "< 6")

  s.add_development_dependency "rails", ">= 4.0", "< 6"
  s.add_development_dependency "resque", "~> 1.2.0"
  # Sidekiq 3.2.2 does not support Ruby 1.9.
  s.add_development_dependency "sidekiq", "~> 3.0.0", "< 3.2.2"
  s.add_development_dependency "tinder", "~> 1.8"
  s.add_development_dependency "httparty", "~> 0.10.2"
  s.add_development_dependency "mocha", ">= 0.13.0"
  s.add_development_dependency "sqlite3", ">= 1.3.4"
  s.add_development_dependency "coveralls", "~> 0.8.2"
  s.add_development_dependency "appraisal", "~> 2.0.0"
  s.add_development_dependency "hipchat", ">= 1.0.0"
  s.add_development_dependency "carrier-pigeon", ">= 0.7.0"
  s.add_development_dependency "slack-notifier", ">= 1.0.0"
end
