require 'test_helper'

class ExceptionNotificationTest < ActiveSupport::TestCase
  test "should have default ignored exceptions" do
    assert ExceptionNotifier.default_ignore_exceptions == [ActiveRecord::RecordNotFound, AbstractController::ActionNotFound, ActionController::RoutingError]
  end

  test "should have default sender address overriden" do
    assert ExceptionNotifier::Notifier.default_sender_address == %("Dummy Notifier" <dummynotifier@example.com>)
  end

  test "should have default email prefix overriden" do
    assert ExceptionNotifier::Notifier.default_email_prefix == "[Dummy ERROR] "
  end

  test "should have default sections" do
    for section in %w(request session environment backtrace)
      assert ExceptionNotifier::Notifier.default_sections.include? section
    end
  end

  test "should have default background sections" do
    assert ExceptionNotifier::Notifier.default_background_sections == %w(backtrace data)
  end

  test "should have verbose subject by default" do
    assert ExceptionNotifier::Notifier.default_options[:verbose_subject] == true
  end

  test "should have ignored crawler by default" do
    assert ExceptionNotifier.default_ignore_crawlers == []
  end

  test "should normalize multiple digits into one N" do
    assert_equal 'N foo N bar N baz N',
      ExceptionNotifier::Notifier.normalize_digits('1 foo 12 bar 123 baz 1234')
  end
  
end
