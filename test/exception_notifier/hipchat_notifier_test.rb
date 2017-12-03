require 'test_helper'

# silence_warnings trick around require can be removed once
# https://github.com/hipchat/hipchat-rb/pull/174
# gets merged and released
silence_warnings do
  require 'hipchat'
end

class HipchatNotifierTest < ActiveSupport::TestCase

  test "should send hipchat notification if properly configured" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow',
    }

    HipChat::Room.any_instance.expects(:send).with('Exception', fake_body, { :color => 'yellow' })

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should call pre/post_callback if specified" do
    pre_callback_called, post_callback_called = 0,0
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow',
      :pre_callback => proc { |*| pre_callback_called += 1},
      :post_callback => proc { |*| post_callback_called += 1}
    }

    HipChat::Room.any_instance.expects(:send).with('Exception', fake_body, { :color => 'yellow' }.merge(options.except(:api_token, :room_name)))

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
    assert_equal(1, pre_callback_called)
    assert_equal(1, post_callback_called)
  end

  test "should send hipchat notification without backtrace info if properly configured" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow',
    }

    HipChat::Room.any_instance.expects(:send).with('Exception', fake_body_without_backtrace, { :color => 'yellow' })

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception_without_backtrace)
  end

  test "should allow custom from value if set" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :from      => 'TrollFace',
    }

    HipChat::Room.any_instance.expects(:send).with('TrollFace', fake_body, { :color => 'red' })

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should not send hipchat notification if badly configured" do
    wrong_params = {
      :api_token => 'bad_token',
      :room_name => 'test_room'
    }

    HipChat::Client.stubs(:new).with('bad_token', {:api_version => 'v1'}).returns(nil)

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  test "should not send hipchat notification if api_key is missing" do
    wrong_params  = {:room_name => 'test_room'}

    HipChat::Client.stubs(:new).with(nil, {:api_version => 'v1'}).returns(nil)

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  test "should not send hipchat notification if room_name is missing" do
    wrong_params  = {:api_token => 'good_token'}

    HipChat::Client.stubs(:new).with('good_token', {:api_version => 'v1'}).returns({})

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  test "should send hipchat notification with message_template" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow',
      :message_template => ->(exception, _) { "This is custom message: '#{exception.message}'" }
    }

    HipChat::Room.any_instance.expects(:send).with('Exception', "This is custom message: '#{fake_exception.message}'", { :color => 'yellow' })

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should send hipchat notification exclude accumulated errors count" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow'
    }

    HipChat::Room.any_instance.expects(:send).with{ |_, msg, _| msg.start_with?("A new exception occurred:") }
    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should send hipchat notification include accumulated errors count" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow'
    }

    HipChat::Room.any_instance.expects(:send).with{ |_, msg, _| msg.start_with?("The exception occurred 3 times:") }
    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception, { accumulated_errors_count: 3 })
  end

  test "should send hipchat notification with HTML-escaped meessage if using default message_template" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :color     => 'yellow',
    }

    exception = fake_exception_with_html_characters
    body = "A new exception occurred: '#{Rack::Utils.escape_html(exception.message)}' on '#{exception.backtrace.first}'"

    HipChat::Room.any_instance.expects(:send).with('Exception', body, { :color => 'yellow' })

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(exception)
  end

  test "should use APIv1 if api_version is not specified" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
    }

    HipChat::Client.stubs(:new).with('good_token', {:api_version => 'v1'}).returns({})

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should use APIv2 when specified" do
    options = {
      :api_token => 'good_token',
      :room_name => 'room_name',
      :api_version => 'v2',
    }

    HipChat::Client.stubs(:new).with('good_token', {:api_version => 'v2'}).returns({})

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  test "should allow server_url value (for a self-hosted HipChat Server) if set" do
    options = {
      :api_token   => 'good_token',
      :room_name   => 'room_name',
      :api_version => 'v2',
      :server_url  => 'https://domain.com',
    }

    HipChat::Client.stubs(:new).with('good_token', {:api_version => 'v2', :server_url => 'https://domain.com'}).returns({})

    hipchat = ExceptionNotifier::HipchatNotifier.new(options)
    hipchat.call(fake_exception)
  end

  private

  def fake_body
    "A new exception occurred: '#{fake_exception.message}' on '#{fake_exception.backtrace.first}'"
  end

  def fake_exception
    begin
      5/0
    rescue Exception => e
      e
    end
  end

  def fake_exception_with_html_characters
    begin
      raise StandardError.new('an error with <html> characters')
    rescue Exception => e
      e
    end
  end

  def fake_body_without_backtrace
    "A new exception occurred: '#{fake_exception_without_backtrace.message}'"
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end
end
