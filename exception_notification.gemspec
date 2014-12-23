Gem::Specification.new do |s|
  s.name = 'exception_notification'
  s.version = '4.1.0.rc1'
  s.authors = ["Jamis Buck", "Josh Peek"]
  s.date = %q{2014-04-16}
  s.summary = "Exception notification for Rails apps"
  s.homepage = "http://smartinez87.github.com/exception_notification"
  s.email = "smartinez87@gmail.com"
  s.license = "MIT"

  s.required_ruby_version     = '>= 1.9.3'
  s.required_rubygems_version = '>= 1.8.11'

  s.files = `git ls-files`.split("\n")
  s.files -= `git ls-files -- .??*`.split("\n")
  s.test_files = `git ls-files -- test`.split("\n")
  s.require_path = 'lib'

  s.add_dependency("actionmailer", ">= 3.0.4")
  s.add_dependency("activesupport", ">= 3.0.4")

  s.add_development_dependency "rails", ">= 3.0.4"
  s.add_development_dependency "resque", "~> 1.2.0"
  if RUBY_VERSION > "1.9"
    s.add_development_dependency "sidekiq", "~> 3.3"
  else
    s.add_development_dependency "sidekiq", "~> 3.2.6"  
  end
  s.add_development_dependency "tinder", "~> 1.8"
  s.add_development_dependency "httparty", "~> 0.10.2"
  s.add_development_dependency "mocha", ">= 0.13.0"
  s.add_development_dependency "sqlite3", ">= 1.3.4"
  s.add_development_dependency "coveralls", "~> 0.6.5"
  s.add_development_dependency "appraisal", "~> 1.0.0"
  s.add_development_dependency "hipchat", ">= 1.0.0"
  s.add_development_dependency "carrier-pigeon", ">= 0.7.0"
  s.add_development_dependency "slack-notifier", ">= 1.0.0"
end
