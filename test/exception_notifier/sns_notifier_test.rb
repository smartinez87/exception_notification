require 'test_helper'
require 'aws-sdk-sns'

class SnsNotifierTest < ActiveSupport::TestCase
  def setup
    @exception = fake_exception
    @exception.stubs(:class).returns('MyException')
    @exception.stubs(:backtrace).returns(fake_backtrace)
    @exception.stubs(:message).returns("undefined method 'method=' for Empty")
    @options = {
      access_key_id: 'my-access_key_id',
      secret_access_key: 'my-secret_access_key',
      region: 'us-east',
      topic_arn: 'topicARN',
      sns_prefix: '[App Exception]',
    }
    Socket.stubs(:gethostname).returns('example.com')
  end

  # initialize

  test 'should initialize aws notifier with received params' do
    Aws::SNS::Client.expects(:new).with(
      region: 'us-east',
      access_key_id: 'my-access_key_id',
      secret_access_key: 'my-secret_access_key'
    )

    ExceptionNotifier::SnsNotifier.new(@options)
  end

  test 'should raise an exception if region is not received' do
    @options[:region] = nil

    error = assert_raises ArgumentError do
      ExceptionNotifier::SnsNotifier.new(@options)
    end
    assert_equal "You must provide 'region' option", error.message
  end

  test 'should raise an exception on publish if access_key_id is not received' do
    @options[:access_key_id] = nil
    error = assert_raises ArgumentError do
      ExceptionNotifier::SnsNotifier.new(@options)
    end

    assert_equal "You must provide 'access_key_id' option", error.message
  end

  test 'should raise an exception on publish if secret_access_key is not received' do
    @options[:secret_access_key] = nil
    error = assert_raises ArgumentError do
      ExceptionNotifier::SnsNotifier.new(@options)
    end

    assert_equal "You must provide 'secret_access_key' option", error.message
  end

  # call

  test 'should send a sns notification in background' do
    Aws::SNS::Client.any_instance.expects(:publish).with(
      {
      topic_arn: "topicARN",
      message: "3 MyException occured in background\n"\
               "Exception: undefined method 'method=' for Empty\n"\
               "Hostname: example.com\n"\
               "Backtrace:\n#{fake_backtrace.join("\n")}\n",
      subject: "[App Exception] - 3 MyException occurred"
    })

    sns_notifier = ExceptionNotifier::SnsNotifier.new(@options)
    sns_notifier.call(@exception, { accumulated_errors_count: 3 })
  end

  test 'should send a sns notification with controller#action information' do
    ExamplesController.any_instance.stubs(:action_name).returns('index')

    Aws::SNS::Client.any_instance.expects(:publish).with(
      {
      topic_arn: "topicARN",
      message: "A MyException occurred while GET </examples> "\
               "was processed by examples#index\n"\
               "Exception: undefined method 'method=' for Empty\n"\
               "Hostname: example.com\n"\
               "Backtrace:\n#{fake_backtrace.join("\n")}\n",
      subject: "[App Exception] - A MyException occurred"
    })

    sns_notifier = ExceptionNotifier::SnsNotifier.new(@options)
    sns_notifier.call(@exception,
      env: {
        'REQUEST_METHOD' => 'GET',
        'REQUEST_URI' => '/examples',
        'action_controller.instance' => ExamplesController.new
      }
    )
  end

  private

  class ExamplesController < ActionController::Base; end

  def fake_exception
    begin
      1 / 0
    rescue Exception => e
      e
    end
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end

  def fake_backtrace
    [
      'backtrace line 1',
      'backtrace line 2',
      'backtrace line 3',
      'backtrace line 4',
      'backtrace line 5',
      'backtrace line 6'
    ]
  end
end
