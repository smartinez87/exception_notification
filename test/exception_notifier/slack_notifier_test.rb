# frozen_string_literal: true

require 'test_helper'
require 'slack-notifier'

class SlackNotifierTest < ActiveSupport::TestCase
  def setup
    @exception = fake_exception
    @exception.stubs(:backtrace).returns(fake_backtrace)
    @exception.stubs(:message).returns('exception message')
    ExceptionNotifier::SlackNotifier.any_instance.stubs(:clean_backtrace).returns(fake_cleaned_backtrace)
    Socket.stubs(:gethostname).returns('example.com')
  end

  test 'should send a slack notification if properly configured' do
    options = {
      webhook_url: 'http://slack.webhook.url'
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test 'should send a slack notification without backtrace info if properly configured' do
    options = {
      webhook_url: 'http://slack.webhook.url'
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(fake_exception_without_backtrace))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(fake_exception_without_backtrace)
  end

  test 'should send the notification to the specified channel' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      channel: 'channel'
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)

    channel = slack_notifier.notifier.config.defaults[:channel]
    assert_equal channel, options[:channel]
  end

  test 'should send the notification to the specified username' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      username: 'username'
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification)

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)

    username = slack_notifier.notifier.config.defaults[:username]
    assert_equal username, options[:username]
  end

  test 'should send the notification with specific backtrace lines' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      backtrace_lines: 1
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, {}, nil, 1))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test 'should send the notification withouth cleaned backtrace lines if option is false' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      clean_backtrace: false
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, {}, nil, 6, [], false))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test 'should send the notification with additional fields' do
    field = { title: 'Branch', value: 'master', short: true }
    options = {
      webhook_url: 'http://slack.webhook.url',
      additional_fields: [field]
    }

    Slack::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, {}, nil, 10, [field]))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)

    additional_fields = slack_notifier.notifier.config.defaults[:additional_fields]
    assert_equal additional_fields, options[:additional_fields]
  end

  test 'should pass the additional parameters to Slack::Notifier.ping' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      username: 'test',
      custom_hook: 'hook',
      additional_parameters: {
        icon_url: 'icon'
      }
    }

    Slack::Notifier.any_instance.expects(:ping).with('', options[:additional_parameters].merge(fake_notification))

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
  end

  test "shouldn't send a slack notification if webhook url is missing" do
    options = {}

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)

    assert_nil slack_notifier.notifier
    assert_nil slack_notifier.call(@exception)
  end

  test 'should pass along environment data' do
    options = {
      webhook_url: 'http://slack.webhook.url',
      ignore_data_if: lambda { |k, v|
        k.to_s == 'key_to_be_ignored' || v.is_a?(Hash)
      }
    }

    notification_options = {
      env: {
        'exception_notifier.exception_data' => { foo: 'bar', john: 'doe' }
      },
      data: {
        'user_id' => 5,
        'key_to_be_ignored' => 'whatever',
        'ignore_as_well' => { what: 'ever' }
      }
    }

    expected_data_string = "foo: bar\njohn: doe\nuser_id: 5"

    Slack::Notifier.any_instance
                   .expects(:ping)
                   .with('', fake_notification(@exception, notification_options, expected_data_string))
    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception, notification_options)
  end

  test 'should call pre/post_callback proc if specified' do
    post_callback_called = 0
    options = {
      webhook_url: 'http://slack.webhook.url',
      username: 'test',
      custom_hook: 'hook',
      pre_callback: proc { |_opts, _notifier, backtrace, _message, message_opts|
        (message_opts[:attachments] = []) << { text: backtrace.join("\n").to_s, color: 'danger' }
      },
      post_callback: proc { |_opts, _notifier, _backtrace, _message, _message_opts|
        post_callback_called = 1
      },
      additional_parameters: {
        icon_url: 'icon'
      }
    }

    Slack::Notifier.any_instance.expects(:ping).with('',
                                                     icon_url: 'icon',
                                                     attachments: [{
                                                       text: fake_backtrace.join("\n"),
                                                       color: 'danger'
                                                     }])

    slack_notifier = ExceptionNotifier::SlackNotifier.new(options)
    slack_notifier.call(@exception)
    assert_equal(post_callback_called, 1)
  end

  private

  def fake_exception
    5 / 0
  rescue StandardError => e
    e
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end

  def fake_backtrace
    [
      'backtrace line 1', 'backtrace line 2', 'backtrace line 3',
      'backtrace line 4', 'backtrace line 5', 'backtrace line 6'
    ]
  end

  def fake_cleaned_backtrace
    fake_backtrace[2..-1]
  end

  def fake_notification(exception = @exception, notification_options = {},
                        data_string = nil, expected_backtrace_lines = 10,
                        additional_fields = [], clean_backtrace = true)

    exception_name = "*#{exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'}* `#{exception.class}`"
    if notification_options[:env].nil?
      text = "#{exception_name} *occured in background*"
    else
      env = notification_options[:env]

      kontroller = env['action_controller.instance']
      request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"

      text = "#{exception_name} *occurred while* `#{request}`"
      text += " *was processed by* `#{kontroller.controller_name}##{kontroller.action_name}`" if kontroller
    end

    text += "\n"

    fields = [{ title: 'Exception', value: exception.message }]
    fields.push(title: 'Hostname', value: 'example.com')
    if exception.backtrace
      backtrace = clean_backtrace ? fake_cleaned_backtrace : fake_backtrace
      formatted_backtrace = "```#{backtrace.first(expected_backtrace_lines).join("\n")}```"
      fields.push(title: 'Backtrace', value: formatted_backtrace)
    end
    fields.push(title: 'Data', value: "```#{data_string}```") if data_string
    additional_fields.each { |f| fields.push(f) }

    { attachments: [color: 'danger', text: text, fields: fields, mrkdwn_in: %w[text fields]] }
  end
end
