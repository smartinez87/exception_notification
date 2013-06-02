require 'test_helper'
require 'tinder'

class CampfireNotifierTest < ActiveSupport::TestCase

  test "should send campfire notification if properly configured" do
    ExceptionNotifier::CampfireNotifier.stubs(:new).returns(Object.new)
    campfire = ExceptionNotifier::CampfireNotifier.new({:subdomain => 'test', :token => 'test_token', :room_name => 'test_room'})
    campfire.stubs(:call).returns(fake_notification)
    notif = campfire.call(fake_exception)

    assert !notif[:message].empty?
    assert_equal notif[:message][:type], 'PasteMessage'
    assert notif[:message][:body].include? "A new exception occurred:"
    assert notif[:message][:body].include? "divided by 0"
    assert notif[:message][:body].include? "/exception_notification/test/campfire_test.rb:45"
  end

  test "should not send campfire notification if badly configured" do
    wrong_params = {:subdomain => 'test', :token => 'bad_token', :room_name => 'test_room'}
    Tinder::Campfire.stubs(:new).with('test', {:token => 'bad_token'}).returns(nil)
    campfire = ExceptionNotifier::CampfireNotifier.new(wrong_params)

    assert_nil campfire.room
    assert_nil campfire.call(fake_exception)
  end

  test "should not send campfire notification if config attr missing" do
    wrong_params  = {:subdomain => 'test', :room_name => 'test_room'}
    Tinder::Campfire.stubs(:new).with('test', {}).returns(nil)
    campfire = ExceptionNotifier::CampfireNotifier.new(wrong_params)

    assert_nil campfire.room
    assert_nil campfire.call(fake_exception)
  end

  private

  def fake_notification
    {:message => {:type => 'PasteMessage',
                  :body => "A new exception occurred: 'divided by 0' on '/Users/sebastian/exception_notification/test/campfire_test.rb:45:in `/'"
                 }
    }
  end

  def fake_exception
    exception = begin
      5/0
    rescue Exception => e
      e
    end
  end
end
