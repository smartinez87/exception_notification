require 'test_helper'
require 'carrier-pigeon'

class IrcNotifierTest < ActiveSupport::TestCase

  test "should send irc notification if properly configured" do
    options = {
      :domain => 'irc.example.com'
    }

    CarrierPigeon.expects(:send).with(has_key(:uri)) do |v|
      /divided by 0/.match(v[:message])
    end

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception)
  end

  test "should exclude errors count in message if :accumulated_errors_count nil" do
    irc = ExceptionNotifier::IrcNotifier.new({})
    irc.stubs(:active?).returns(true)

    irc.expects(:send_message).with{ |message| message.include?("divided by 0") }.once
    irc.call(fake_exception)
  end

  test "should include errors count in message if :accumulated_errors_count is 3" do
    irc = ExceptionNotifier::IrcNotifier.new({})
    irc.stubs(:active?).returns(true)

    irc.expects(:send_message).with{ |message| message.include?("(3 times)'divided by 0'") }.once
    irc.call(fake_exception, accumulated_errors_count: 3)
  end

  test "should call pre/post_callback if specified" do
    pre_callback_called, post_callback_called = 0,0

    options = {
      :domain => 'irc.example.com',
      :pre_callback => proc { |*| pre_callback_called += 1},
      :post_callback => proc { |*| post_callback_called += 1}
    }

    CarrierPigeon.expects(:send).with(has_key(:uri)) do |v|
      /divided by 0/.match(v[:message])
    end

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception)
    assert_equal(1, pre_callback_called)
    assert_equal(1, post_callback_called)
  end

  test "should send irc notification without backtrace info if properly configured" do
    options = {
      :domain => 'irc.example.com'
    }

    CarrierPigeon.expects(:send).with(has_key(:uri)) do |v|
      /my custom error/.match(v[:message])
    end

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception_without_backtrace)
  end

  test "should properly construct URI from constituent parts" do
    options = {
      :nick => 'BadNewsBot',
      :password => 'secret',
      :domain => 'irc.example.com',
      :port => 9999,
      :channel => '#exceptions'
    }

    CarrierPigeon.expects(:send).with(has_entry(uri: "irc://BadNewsBot:secret@irc.example.com:9999/#exceptions"))

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception)
  end

  test "should properly add recipients if specified" do
    options = {
      domain: 'irc.example.com',
      recipients: ['peter', 'michael', 'samir']
    }

    CarrierPigeon.expects(:send).with(has_key(:uri)) do |v|
      /peter, michael, samir/.match(v[:message])
    end

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception)
  end

  test "should properly set miscellaneous options" do
    options = {
      domain: 'irc.example.com',
      ssl: true,
      join: true,
      notice: true,
      prefix: '[test notification]'
    }

    CarrierPigeon.expects(:send).with(has_entries(
      ssl: true,
      join: true,
      notice: true,
    )) do |v|
      /\[test notification\]/.match(v[:message])
    end

    irc = ExceptionNotifier::IrcNotifier.new(options)
    irc.call(fake_exception)
  end

  test "should not send irc notification if badly configured" do
    wrong_params = { domain: '##scriptkiddie.com###'}
    irc = ExceptionNotifier::IrcNotifier.new(wrong_params)

    assert_nil irc.call(fake_exception)
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
end
