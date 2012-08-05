require 'test_helper'

class ExceptionNotificationTest < ActiveSupport::TestCase
  test "should have default ignored exceptions" do
    assert ExceptionNotifier.default_ignore_exceptions == ['ActiveRecord::RecordNotFound', 'AbstractController::ActionNotFound', 'ActionController::RoutingError']
  end

  test "should have default sender address overridden" do
    assert ExceptionNotifier::Notifier.default_sender_address == %("Dummy Notifier" <dummynotifier@example.com>)
  end

  test "should have default email prefix overridden" do
    assert ExceptionNotifier::Notifier.default_email_prefix == "[Dummy ERROR] "
  end

  test "should have default email format overridden" do
    assert ExceptionNotifier::Notifier.default_email_format == :text
  end

  test "should have default sections" do
    for section in %w(request session environment backtrace)
      assert ExceptionNotifier::Notifier.default_sections.include? section
    end
  end

  test "should have default section overridden" do
    begin
      test_string = '--- this is a test ---'
      env = {}
      exception = StandardError.new("Test Error")
      options = {:sections => %w(environment)}

      section_partial = Rails.root.join('app', 'views', 'exception_notifier', '_environment.text.erb')

      File.open(section_partial, 'w+') { |f| f.puts test_string }

      assert ExceptionNotifier::Notifier.exception_notification(env, exception, options).body =~ /#{test_string}/
    ensure
      File.delete section_partial
    end
  end

  test "should have default background sections" do
    for section in %w(backtrace data)
      assert ExceptionNotifier::Notifier.default_background_sections.include? section
    end
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

  test "should have normalize_subject false by default" do
    assert ExceptionNotifier::Notifier.default_options[:normalize_subject] == false
  end
  
  test "should have smtp_settings nil by default" do
    assert ExceptionNotifier::Notifier.default_options[:smtp_settings] == nil
  end
end
