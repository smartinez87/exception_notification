require 'test_helper'

class BackgroundExceptionNotificationTest < ActiveSupport::TestCase
  setup do
    begin
      1/0
    rescue => e
      @exception = e
      @time = Time.current
      @mail = ExceptionNotifier::Notifier.background_exception_notification(@exception,
        :data => {:job => 'DivideWorkerJob', :payload => '1/0', :message => 'My Custom Message'})
    end
  end

  test "should have raised an exception" do
    assert_not_nil @exception
  end

  test "should have generated a notification email" do
    assert_not_nil @mail
  end

  test "mail should have a from address set" do
    assert @mail.from == ["dummynotifier@example.com"]
  end

  test "mail should have a to address set" do
    assert @mail.to == ["dummyexceptions@example.com"]
  end

  test "mail should have a descriptive subject" do
    assert @mail.subject == "[Dummy ERROR]  (ZeroDivisionError) \"divided by 0\""
  end

  test "mail should say exception was raised in background at show timestamp" do
    assert @mail.body.include? "A ZeroDivisionError occurred in background at #{@time}"
  end

  test "mail should contain backtrace in body" do
    assert @mail.body.include? "test/background_exception_notification_test.rb:6"
  end

  test "mail should contain data in body" do
    assert @mail.body.include? '* data:'
    assert @mail.body.include? ':payload=>"1/0"'
    assert @mail.body.include? ':job=>"DivideWorkerJob"'
    assert @mail.body.include? "My Custom Message"
  end

  test "mail should not contain any attachments" do
    assert @mail.attachments == []
  end

  test "should not send notification if one of ignored exceptions" do
    begin
      raise ActiveRecord::RecordNotFound
    rescue => e
      @ignored_exception = e
      unless ExceptionNotifier.default_ignore_exceptions.include?(@ignored_exception.class.name)
        @ignored_mail = ExceptionNotifier::Notifier.background_exception_notification(@ignored_exception)
      end
    end

    assert @ignored_exception.class.inspect == "ActiveRecord::RecordNotFound"
    assert_nil @ignored_mail
  end
end
