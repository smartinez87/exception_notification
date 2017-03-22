require 'test_helper'
require 'octokit'

class GithubNotifierTest < ActiveSupport::TestCase

  test "should create github issue if properly configured" do
    Octokit::Client.any_instance.expects(:create_issue)

    options = {
      :prefix   => '[Prefix] ',
      :repo     => 'some/repo',
      :login    => 'login',
      :password => 'password'
    }

    github = ExceptionNotifier::GithubNotifier.new(options)
    github.call(fake_exception,
                :env => { "REQUEST_METHOD" => "GET", "rack.input" => "" },
                :data => {})
  end

  test "does not create an authenticated github client if badly configured" do
    incomplete_options = {
      :prefix   => '[Prefix] ',
      :repo     => 'some/repo',
      :login    => nil,
      :password => 'password'
    }

    github = ExceptionNotifier::GithubNotifier.new(incomplete_options)
    github.call(fake_exception,
                :env => { "REQUEST_METHOD" => "GET", "rack.input" => "" },
                :data => {})

    refute github.client.basic_authenticated?
  end

  test "github issue is formed with data" do
    Octokit::Client.any_instance.expects(:create_issue)

    options = {
      :prefix   => '[Prefix] ',
      :repo     => 'some/repo',
      :login    => 'login',
      :password => 'password'
    }

    github = ExceptionNotifier::GithubNotifier.new(options)
    github.call(fake_exception,
                :env => { "REQUEST_METHOD" => "GET", "rack.input" => "" },
                :data => {})

    assert_includes github.title, '[Prefix]  (ZeroDivisionError)'
    assert_includes github.body, 'A ZeroDivisionError occurred:'
    assert_includes github.body, 'divided by 0'
    assert_includes github.body, '-------------------- Request --------------------'
    assert_includes github.body, "* HTTP Method: GET"
    assert_includes github.body, "-------------------- Session --------------------"
    assert_includes github.body, "* session id: nil"
    assert_includes github.body, "-------------------- Environment --------------------"
    assert_includes github.body, "* REQUEST_METHOD                            : GET"
    assert_includes github.body, "-------------------- Backtrace --------------------"
    assert_includes github.body, "`fake_exception'"
  end

  private

  def fake_exception
    5/0
  rescue Exception => e
    e
  end
end
