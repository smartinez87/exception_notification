require 'test_helper'

# silence_warnings trick around require can be removed once
# https://github.com/collectiveidea/tinder/pull/77
# gets merged and released
silence_warnings do
  require 'tinder'
end

class CampfireNotifierTest < ActiveSupport::TestCase

  test "should send campfire notification if properly configured" do
    ExceptionNotifier::CampfireNotifier.stubs(:new).returns(Object.new)
    campfire = ExceptionNotifier::CampfireNotifier.new({:subdomain => 'test', :token => 'test_token', :room_name => 'test_room'})
    campfire.stubs(:call).returns(fake_notification)
    notif = campfire.call(fake_exception)

    assert !notif[:message].empty?
    assert_equal notif[:message][:type], 'PasteMessage'
    assert_includes notif[:message][:body], "A new exception occurred:"
    assert_includes notif[:message][:body], "divided by 0"
    assert_includes notif[:message][:body], "/exception_notification/test/campfire_test.rb:45"
  end

  test "should send campfire notification without backtrace info if properly configured" do
    ExceptionNotifier::CampfireNotifier.stubs(:new).returns(Object.new)
    campfire = ExceptionNotifier::CampfireNotifier.new({:subdomain => 'test', :token => 'test_token', :room_name => 'test_room'})
    campfire.stubs(:call).returns(fake_notification_without_backtrace)
    notif = campfire.call(fake_exception_without_backtrace)

    assert !notif[:message].empty?
    assert_equal notif[:message][:type], 'PasteMessage'
    assert_includes notif[:message][:body], "A new exception occurred:"
    assert_includes notif[:message][:body], "my custom error"
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

  test "should send the new exception message if no :accumulated_errors_count option" do
    campfire = ExceptionNotifier::CampfireNotifier.new({})
    campfire.stubs(:active?).returns(true)
    campfire.expects(:send_notice).with{ |_, _, message| message.start_with?("A new exception occurred") }.once
    campfire.call(fake_exception)
  end

  test "shoud send the exception message if :accumulated_errors_count option greater than 1" do
    campfire = ExceptionNotifier::CampfireNotifier.new({})
    campfire.stubs(:active?).returns(true)
    campfire.expects(:send_notice).with{ |_, _, message| message.start_with?("The exception occurred 3 times:") }.once
    campfire.call(fake_exception, accumulated_errors_count: 3)
  end

  test "should call pre/post_callback if specified" do 
    pre_callback_called, post_callback_called = 0,0
    Tinder::Campfire.stubs(:new).returns(Object.new)

    campfire = ExceptionNotifier::CampfireNotifier.new(
      {
        :subdomain => 'test',
        :token => 'test_token',
        :room_name => 'test_room',
        :pre_callback => proc { |opts, notifier, backtrace, message, message_opts|
          pre_callback_called += 1
        },
        :post_callback => proc { |opts, notifier, backtrace, message, message_opts|
          post_callback_called += 1
        }
      }
    )
    campfire.room = Object.new
    campfire.room.stubs(:paste).returns(fake_notification)
    campfire.call(fake_exception)
    assert_equal(1, pre_callback_called)
    assert_equal(1, post_callback_called)
  end

  private

  def fake_notification
    {:message => {:type => 'PasteMessage',
                  :body => "A new exception occurred: 'divided by 0' on '/Users/sebastian/exception_notification/test/campfire_test.rb:45:in `/'"
                 }
    }
  end

  def fake_exception
    begin
      5/0
    rescue Exception => e
      e
    end
  end

  def fake_notification_without_backtrace
    {:message => {:type => 'PasteMessage',
                  :body => "A new exception occurred: 'my custom error'"
                 }
    }
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end
end
