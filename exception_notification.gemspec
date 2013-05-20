Gem::Specification.new do |s|
  s.name = 'exception_notification'
  s.version = '3.0.1'
  s.authors = ["Jamis Buck", "Josh Peek"]
  s.date = %q{2013-02-02}
  s.summary = "Exception notification for Rails apps"
  s.homepage = "http://smartinez87.github.com/exception_notification"
  s.email = "smartinez87@gmail.com"

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test`.split("\n")
  s.require_path = 'lib'

  s.add_dependency("actionmailer", ">= 3.0.4")
  s.add_dependency("activesupport", ">= 3.0.4")

  s.add_development_dependency "rails", ">= 3.0.4"
  s.add_development_dependency "tinder", "~> 1.8"
  s.add_development_dependency "httparty", "~> 0.10.2"
  s.add_development_dependency "mocha", ">= 0.13.0"
  s.add_development_dependency "coveralls", "~> 0.6.5"
  s.add_development_dependency "appraisal", ">= 0"
end
