require 'test_helper'
require 'rocket-chat-notifier'

class RocketChatNotifierTest < ActiveSupport::TestCase

  def setup
    @exception = fake_exception
    @options = {
      webhook_url: 'http://rocket.chat.webhook.url'
    }

    @exception.stubs(:backtrace).returns(fake_backtrace)
    @exception.stubs(:message).returns('exception message')
    Socket.stubs(:gethostname).returns('example.com')
  end

  test 'should send the notification if properly configured' do
    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification)

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)
  end

  test 'should send the notification without backtrace info if properly configured' do
    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification(fake_exception_without_backtrace))

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(fake_exception_without_backtrace)
  end

  test 'should send the notification to the specified channel' do
    @options.merge!(channel: 'channel')

    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification)

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)

    channel = notifier.notifier.default_payload[:channel]
    assert_equal channel, @options[:channel]
  end

  test 'should send the notification to the specified username' do
    @options.merge!(username: 'username')

    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification)

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)

    username = notifier.notifier.default_payload[:username]
    assert_equal username, @options[:username]
  end

  test 'should send the notification with specific backtrace lines' do
    @options.merge!(backtrace_lines: 1)

    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, {}, nil, 1))

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)
  end

  test 'should send the notification with additional fields' do
    field = { title: 'Branch', value: 'master', short: true }
    @options.merge!(additional_fields: [field])

    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, {}, nil, 10, [field]))

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)

    additional_fields = notifier.notifier.default_payload[:additional_fields]
    assert_equal additional_fields, @options[:additional_fields]
  end

  test 'should pass the additional parameters to ping method' do
    @options.merge!(
      username: 'test',
      custom_hook: 'hook',
      additional_parameters: {
        icon_url: 'icon',
      }
    )

    RocketChat::Notifier.any_instance.expects(:ping).with('', @options[:additional_parameters].merge(fake_notification) )

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    notifier.call(@exception)
  end

  test "shouldn't send the notification if webhook url is missing" do
    @options.delete(:webhook_url)

    notifier = ExceptionNotifier::RocketChatNotifier.new(@options)

    assert_nil notifier.notifier
    assert_nil notifier.call(@exception)
  end

  test 'should pass along environment data' do
    @options.merge!(
      ignore_data_if: lambda { |key, value|
        "#{ key }" == 'key_to_be_ignored' || value.is_a?(Hash)
      }
    )
    notification_options = {
      env: {
        'exception_notifier.exception_data' => { foo: 'bar', john: 'doe' }
      },
      data: {
        'user_id'           => 5,
        'key_to_be_ignored' => 'whatever',
        'ignore_as_well'    => { what: 'ever' }
      }
    }
    expected_data_string = "foo: bar\njohn: doe\nuser_id: 5"

    RocketChat::Notifier.any_instance.expects(:ping).with('', fake_notification(@exception, notification_options, expected_data_string))

    slack_notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
    slack_notifier.call(@exception, notification_options)
  end

  test 'should call pre/post_callback proc if specified' do
    post_callback_called = 0
    @options.merge!(
      username: 'test',
      custom_hook: 'hook',
      :pre_callback => proc { |opts, notifier, backtrace, message, message_opts|
        (message_opts[:attachments] = []) << { text: "#{ backtrace.join("\n") }", color: 'danger' }
      },
      :post_callback => proc { |opts, notifier, backtrace, message, message_opts|
        post_callback_called = 1
      },
      additional_parameters: {
        icon_url: "icon",
      }
    )

    RocketChat::Notifier.any_instance.expects(:ping).with('',
     { :icon_url => 'icon',
      :attachments => [
        {:text => fake_backtrace.join("\n"),
         :color => 'danger' }
     ] }
    )

    slack_notifier = ExceptionNotifier::RocketChatNotifier.new(@options)
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

  def fake_backtrace
    [
      'backtrace line 1',
      'backtrace line 2',
      'backtrace line 3',
      'backtrace line 4',
      'backtrace line 5',
      'backtrace line 6',
    ]
  end

  def fake_notification(exception = @exception, notification_options = {}, data_string = nil, expected_backtrace_lines = 10, additional_fields = [])
    exception_name = "*#{ exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A' }* `#{ exception.class.to_s }`"
    if notification_options[:env].nil?
      text = "#{ exception_name } *occured in background*"
    else
      env = notification_options[:env]

      kontroller = env['action_controller.instance']
      request = "#{ env['REQUEST_METHOD']} <#{env['REQUEST_URI'] }>"

      text = "#{ exception_name } *occurred while* `#{ request }`"
      text += " *was processed by* `#{ kontroller.controller_name }##{ kontroller.action_name }`" if kontroller
    end

    text += "\n"

    fields = [ { title: 'Exception', value: exception.message} ]
    fields.push({ title: 'Hostname', value: 'example.com' })
    if exception.backtrace
      formatted_backtrace = "```#{ exception.backtrace.first(expected_backtrace_lines).join("\n") }```"
      fields.push({ title: 'Backtrace', value: formatted_backtrace })
    end
    fields.push({ title: 'Data', value: "```#{ data_string }```" }) if data_string
    additional_fields.each { |f| fields.push(f) }

    { attachments: [ color: 'danger', text: text, fields: fields, mrkdwn_in: %w[text fields] ] }
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end
end
