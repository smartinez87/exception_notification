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
    exception = begin
      5/0
    rescue Exception => e
      e
    end
  end
end
