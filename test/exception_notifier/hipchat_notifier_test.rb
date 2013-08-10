require 'test_helper'
require 'hipchat'

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

    HipChat::Client.stubs(:new).with('bad_token').returns(nil)

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  test "should not send hipchat notification if api_key is missing" do
    wrong_params  = {:room_name => 'test_room'}

    HipChat::Client.stubs(:new).with(nil).returns(nil)

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  test "should not send hipchat notification if room_name is missing" do
    wrong_params  = {:api_token => 'good_token'}

    HipChat::Client.stubs(:new).with('good_token').returns({})

    hipchat = ExceptionNotifier::HipchatNotifier.new(wrong_params)
    assert_nil hipchat.room
  end

  private

  def fake_body
    "A new exception occurred: '#{fake_exception.message}' on '#{fake_exception.backtrace.first}'"
  end

  def fake_exception
    exception = begin
      5/0
    rescue Exception => e
      e
    end
  end
end
