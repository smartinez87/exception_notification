require 'test_helper'
require 'httparty'

class TeamsNotifierTest < ActiveSupport::TestCase

  test "should send notification if properly configured" do
    options = {
      webhook_url: 'http://localhost:8000'
    }
    teams_notifier = ExceptionNotifier::TeamsNotifier.new
    teams_notifier.httparty = FakeHTTParty.new

    options = teams_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]
    assert body.has_key? 'title'
    assert body.has_key? 'sections'

    sections = body['sections']
    header = sections[0]

    assert_equal 2, sections.size
    assert_equal 'A *ArgumentError* occurred.', header['activityTitle']
    assert_equal 'foo', header['activitySubtitle']
  end

  test "should send notification with create gitlab issue link if specified" do
    options = {
      webhook_url: 'http://localhost:8000',
      git_url: 'github.com/aschen'
    }
    teams_notifier = ExceptionNotifier::TeamsNotifier.new
    teams_notifier.httparty = FakeHTTParty.new

    options = teams_notifier.call ArgumentError.new("foo"), options

    body = ActiveSupport::JSON.decode options[:body]

    potential_action = body['potentialAction']
    assert_equal 2, potential_action.size
    assert_equal '🦊 View in GitLab', potential_action[0]['name']
    assert_equal '🦊 Create Issue in GitLab', potential_action[1]['name']
  end

  test 'should add other HTTParty options to params' do
    options = {
      webhook_url: 'http://localhost:8000',
      username: "Test Bot",
      avatar: 'http://site.com/icon.png',
      basic_auth: {
        username: 'clara',
        password: 'password'
      }
    }
    teams_notifier = ExceptionNotifier::TeamsNotifier.new
    teams_notifier.httparty = FakeHTTParty.new

    options = teams_notifier.call ArgumentError.new("foo"), options

    assert options.has_key? :basic_auth
    assert 'clara', options[:basic_auth][:username]
    assert 'password', options[:basic_auth][:password]
  end

  test "should use 'A' for exceptions count if :accumulated_errors_count option is nil" do
    teams_notifier = ExceptionNotifier::TeamsNotifier.new
    exception = ArgumentError.new("foo")
    teams_notifier.instance_variable_set(:@exception, exception)
    teams_notifier.instance_variable_set(:@options, {})

    message_text = teams_notifier.send(:message_text)
    header = message_text['sections'][0]
    assert_equal 'A *ArgumentError* occurred.', header['activityTitle']
  end

  test "should use direct errors count if :accumulated_errors_count option is 5" do
    teams_notifier = ExceptionNotifier::TeamsNotifier.new
    exception = ArgumentError.new("foo")
    teams_notifier.instance_variable_set(:@exception, exception)
    teams_notifier.instance_variable_set(:@options, { accumulated_errors_count: 5 })
    message_text = teams_notifier.send(:message_text)
    header = message_text['sections'][0]
    assert_equal '5 *ArgumentError* occurred.', header['activityTitle']
  end
end

class FakeHTTParty

  def post(url, options)
    return options
  end

end
