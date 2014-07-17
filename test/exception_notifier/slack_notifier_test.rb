require 'test_helper'
require 'slack-notifier'

class SlackNotifierTest < ActiveSupport::TestCase

  test "should send a slack notification if properly configured" do
    options = {
      token: "token",
      team:  "team"
    }

    Slack::Notifier.any_instance.expects(:ping).with(fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception)
  end

  test "should send a notification as the specified hook" do
    options = {
      token: "token",
      team:  "team",
      custom_hook: "custom"
    }

    Slack::Notifier.any_instance.expects(:ping).with(fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception)

    assert_equal slack_notifier.notifier.hook_name, options[:custom_hook]
  end

  test "should send the notification to the specified channel" do
    options = {
      token: "token",
      team:  "team",
      channel: "channel"
    }

    Slack::Notifier.any_instance.expects(:ping).with(fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception)

    assert_equal slack_notifier.notifier.channel, options[:channel]
  end

  test "should send the notification to the specified username" do
    options = {
      token: "token",
      team:  "team",
      username: "username"
    }

    Slack::Notifier.any_instance.expects(:ping).with(fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception)

    assert_equal slack_notifier.notifier.username, options[:username]
  end

  test "shouldn't send a slack notification if token is missing" do
    options = {
      team: "test"
    }

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)

    assert_nil slack_notifier.notifier
    assert_nil slack_notifier.call(fake_exception)
  end

  test "shouldn't send a slack notification if team is missing" do
    options = {
      token: "test"
    }

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)

    assert_nil slack_notifier.notifier
    assert_nil slack_notifier.call(fake_exception)
  end

  private

  def fake_exception
    begin
      5/0
    rescue Exception => e
      e
    end
  end

  def fake_notification
    "An exception occurred on *#{Rails.application.class.parent_name} (#{Rails.env})*: ```#{fake_exception.message}```"
  end
end
