# frozen_string_literal: true

require File.expand_path('lib/exception_notification/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'exception_notification'
  s.version = ExceptionNotification::VERSION
  s.authors = ['Jamis Buck', 'Josh Peek']
  s.summary = 'Exception notification for Rails apps'
  s.homepage = 'https://smartinez87.github.io/exception_notification/'
  s.email = 'smartinez87@gmail.com'
  s.license = 'MIT'
  s.metadata = { 'changelog_uri' => 'https://github.com/smartinez87/exception_notification/blob/master/CHANGELOG.rdoc' }

  s.required_ruby_version     = '>= 2.3'
  s.required_rubygems_version = '>= 1.8.11'

  s.files = `git ls-files | grep -v '^examples'`.split("\n")
  s.files -= `git ls-files -- .??*`.split("\n")
  s.test_files = `git ls-files -- test`.split("\n")
  s.require_path = 'lib'

  s.post_install_message = "The `exception_notification` gem has moved.
This repo is no longer maintained and all development should move to: https://github.com/kmcphillips/exception_notification"

  s.add_dependency('actionmailer', '>= 5.2', '< 9')
  s.add_dependency('activesupport', '>= 5.2', '< 9')

  s.add_development_dependency 'appraisal', '~> 2.2.0'
  s.add_development_dependency 'aws-sdk-sns', '~> 1'
  s.add_development_dependency 'carrier-pigeon', '>= 0.7.0'
  s.add_development_dependency 'coveralls', '~> 0.8.2'
  s.add_development_dependency 'dogapi', '>= 1.23.0'
  s.add_development_dependency 'hipchat', '>= 1.0.0'
  s.add_development_dependency 'httparty', '~> 0.10.2'
  s.add_development_dependency 'mocha', '>= 0.13.0'
  s.add_development_dependency 'mock_redis', '~> 0.19.0'
  s.add_development_dependency 'net-smtp'
  s.add_development_dependency 'rails', '>= 5.2', '< 9'
  s.add_development_dependency 'resque', '~> 1.8.0'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'sidekiq', '>= 5.0.4'
  s.add_development_dependency 'slack-notifier', '>= 1.0.0'
  s.add_development_dependency 'timecop', '~> 0.9.0'
end
