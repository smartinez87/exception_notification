require 'test_helper'
require 'httparty'

class MattermostNotifierTest < ActiveSupport::TestCase

  test "should send notification if properly configured" do
    options = {
      :webhook_url => 'http://localhost:8000'
    }
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    mattermost_notifier.httparty = FakeHTTParty.new

    options = mattermost_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]
    assert body.has_key? 'text'
    assert body.has_key? 'username'

    text = body['text'].split("\n")
    assert_equal 4, text.size
    assert_equal '@channel', text[0]
    assert_equal 'An *ArgumentError* occured.', text[2]
    assert_equal '*foo*', text[3]
  end

  test "should send notification with create issue link if specified" do
    options = {
      :webhook_url => 'http://localhost:8000',
      :git_url => 'github.com/aschen'
    }
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    mattermost_notifier.httparty = FakeHTTParty.new

    options = mattermost_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]

    text = body['text'].split("\n")
    assert_equal 5, text.size
    assert_equal '[Create an issue](github.com/aschen/dummy/issues/new/?issue%5Btitle%5D=%5BBUG%5D+Error+500+%3A++%28ArgumentError%29+foo)', text[4]
  end

  test 'should add username and icon_url params to the notification if specified' do
    options = {
      :webhook_url => 'http://localhost:8000',
      :username => "Test Bot",
      :avatar => 'http://site.com/icon.png'
    }
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    mattermost_notifier.httparty = FakeHTTParty.new

    options = mattermost_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]

    assert_equal 'Test Bot', body['username']
    assert_equal 'http://site.com/icon.png', body['icon_url']
  end

  test 'should add other HTTParty options to params' do
    options = {
      :webhook_url => 'http://localhost:8000',
      :username => "Test Bot",
      :avatar => 'http://site.com/icon.png',
      :basic_auth => {
        :username => 'clara',
        :password => 'password'
      }
    }
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    mattermost_notifier.httparty = FakeHTTParty.new

    options = mattermost_notifier.call ArgumentError.new("foo"), options

    assert options.has_key? :basic_auth
    assert 'clara', options[:basic_auth][:username]
    assert 'password', options[:basic_auth][:password]
  end

  test "should use 'An' for exceptions count if :accumulated_errors_count option is nil" do
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    exception = ArgumentError.new("foo")
    mattermost_notifier.instance_variable_set(:@exception, exception)
    mattermost_notifier.instance_variable_set(:@options, {})

    assert_includes mattermost_notifier.send(:message_header), "An *ArgumentError* occured."
  end

  test "shoud use direct errors count if :accumulated_errors_count option is 5" do
    mattermost_notifier = ExceptionNotifier::MattermostNotifier.new
    exception = ArgumentError.new("foo")
    mattermost_notifier.instance_variable_set(:@exception, exception)
    mattermost_notifier.instance_variable_set(:@options, { accumulated_errors_count: 5 })

    assert_includes mattermost_notifier.send(:message_header), "5 *ArgumentError* occured."
  end
end

class FakeHTTParty

  def post(url, options)
    return options
  end

end
