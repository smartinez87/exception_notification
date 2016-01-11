require 'test_helper'
require 'slack-notifier'

class SlackNotifierTest < ActiveSupport::TestCase

  def setup
    @exception = fake_exception
    @exception.stubs(:backtrace).returns(["backtrace line 1", "backtrace line 2"])
    @exception.stubs(:message).returns('exception message')
  end

  test "should send a slack notification if properly configured" do
    options = {
      webhook_url: "http://slack.webhook.url"
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test "should send a slack notification without backtrace info if properly configured" do
    options = {
      webhook_url: "http://slack.webhook.url"
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(fake_exception_without_backtrace))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception_without_backtrace)
  end

  test "should send the notification to the specified channel" do
    options = {
      webhook_url: "http://slack.webhook.url",
      channel: "channel"
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)

    assert_equal slack_notifier.notifier.channel, options[:channel]
  end

  test "should send the notification to the specified username" do
    options = {
      webhook_url: "http://slack.webhook.url",
      username: "username"
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)

    assert_equal slack_notifier.notifier.username, options[:username]
  end

  test "should send the notification with specific backtrace lines" do
    options = {
      webhook_url: "http://slack.webhook.url",
      backtrace_lines: 1
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, nil, 1))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test "should pass the additional parameters to Slack::Notifier.ping" do
    options = {
      webhook_url: "http://slack.webhook.url",
      username: "test",
      custom_hook: "hook",
      additional_parameters: {
        icon_url: "icon",
      }
    }

    Slack::Notifier.any_instance.expects(:ping).with('', options[:additional_parameters].merge(fake_notification) )

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test "shouldn't send a slack notification if webhook url is missing" do
    options = {}

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)

    assert_nil slack_notifier.notifier
    assert_nil slack_notifier.call(@exception)
  end

  test "should pass along environment data" do
    options = {
      webhook_url: "http://slack.webhook.url",
      ignore_data_if: lambda {|k,v|
        "#{k}" == 'key_to_be_ignored' || v.is_a?(Hash)
      }
    }

    notification_options = {
      env: {
        'exception_notifier.exception_data' => {foo: 'bar', john: 'doe'}
      },
      data: {
        'user_id'           => 5,
        'key_to_be_ignored' => 'whatever',
        'ignore_as_well'    => {what: 'ever'}
      }
    }

    expected_data_string = "foo: bar\njohn: doe\nuser_id: 5"

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, expected_data_string))
    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception, notification_options)
  end

  test "should call pre/post_callback proc if specified" do
    post_callback_called = 0
    options = {
      webhook_url: "http://slack.webhook.url",
      username: "test",
      custom_hook: "hook",
      :pre_callback => proc { |opts, notifier, backtrace, message, message_opts|
        (message_opts[:attachments] = []) << { text: "#{backtrace.join("\n")}", color: 'danger' }
      },
      :post_callback => proc { |opts, notifier, backtrace, message, message_opts|
        post_callback_called = 1
      },
      additional_parameters: {
        icon_url: "icon",
      }
    }

    Slack::Notifier.any_instance.expects(:ping).with('',
                                                     {:icon_url => 'icon',
                                                      :attachments => [
                                                        {:text => "backtrace line 1\nbacktrace line 2",
                                                         :color => 'danger'}
                                                     ]})

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
    assert_equal(post_callback_called, 1)
  end

  private

  def fake_exception
    begin
      5/0
    rescue Exception => e
      e
    end
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end

  def fake_notification(exception=@exception, data_string=nil, expected_backtrace_lines=nil)
    text = "*An exception occurred while doing*: ` <>`\n"

    fields = [ { title: 'Exception', value: exception.message} ]
    if exception.backtrace
      formatted_backtrace = expected_backtrace_lines ? "```#{exception.backtrace.first(expected_backtrace_lines).join("\n")}```" : "```#{exception.backtrace.join("\n")}```"
      fields.push({ title: 'Backtrace', value: formatted_backtrace }) if exception.backtrace
    end
    fields.push({ title: 'Data', value: "```#{data_string}```" }) if data_string

    { attachments: [ color: 'danger', text: text, fields: fields, mrkdwn_in: %w(text fields) ] }
  end

end
