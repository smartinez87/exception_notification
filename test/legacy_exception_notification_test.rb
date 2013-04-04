require 'test_helper'

class LegacyExceptionNotificationTest < ActiveSupport::TestCase

  test "should have default sender address overridden" do
    assert ExceptionNotifier::EmailNotifier.default_sender_address == %("Dummy Notifier" <dummynotifier@example.com>)
  end

  test "should have default exception recipients overridden" do
    assert ExceptionNotifier::EmailNotifier.default_exception_recipients == %w(dummyexceptions@example.com)
  end

  test "should have default email prefix overridden" do
    assert ExceptionNotifier::EmailNotifier.default_email_prefix == "[Dummy ERROR] "
  end

  test "should have default email format overridden" do
    assert ExceptionNotifier::EmailNotifier.default_email_format == :text
  end

  test "should have default email headers overridden" do
    assert ExceptionNotifier::EmailNotifier.default_email_headers == { "X-Custom-Header" => "foobar"}
  end

  test "should have default sections overridden" do
    for section in %w(new_section request session environment backtrace)
      assert ExceptionNotifier::EmailNotifier.default_sections.include? section
    end
  end

  test "should have default background sections" do
    for section in %w(new_bkg_section backtrace data)
      assert ExceptionNotifier::EmailNotifier.default_background_sections.include? section
    end
  end

  test "should have verbose subject by default" do
    assert ExceptionNotifier::EmailNotifier.default_options[:verbose_subject] == true
  end

  test "should have normalize_subject false by default" do
    assert ExceptionNotifier::EmailNotifier.default_options[:normalize_subject] == false
  end

  test "should have smtp_settings nil by default" do
    assert ExceptionNotifier::EmailNotifier.default_options[:smtp_settings] == nil
  end
end
