require 'test_helper'

class EmailNotifierTest < ActiveSupport::TestCase
  setup do
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    begin
      1/0
    rescue => e
      @exception = e
      @time = Time.current
      @mail = @email_notifier.create_email(@exception,
        :data => {:job => 'DivideWorkerJob', :payload => '1/0', :message => 'My Custom Message'})
    end
  end

  test "should have default sender address overridden" do
    assert @email_notifier.sender_address == %("Dummy Notifier" <dummynotifier@example.com>)
  end

  test "should have default exception recipients overridden" do
    assert @email_notifier.exception_recipients == %w(dummyexceptions@example.com)
  end

  test "should have default email prefix overridden" do
    assert @email_notifier.email_prefix == "[Dummy ERROR] "
  end

  test "should have default email headers overridden" do
    assert @email_notifier.email_headers == { "X-Custom-Header" => "foobar"}
  end

  test "should have default sections overridden" do
    for section in %w(new_section request session environment backtrace)
      assert @email_notifier.sections.include? section
    end
  end

  test "should have default background sections" do
    for section in %w(new_bkg_section backtrace data)
      assert @email_notifier.background_sections.include? section
    end
  end

  test "should have email format by default" do
    assert @email_notifier.email_format == :text
  end

  test "should have verbose subject by default" do
    assert @email_notifier.verbose_subject == true
  end

  test "should have normalize_subject false by default" do
    assert @email_notifier.normalize_subject == false
  end

  test "should have smtp_settings nil by default" do
    assert @email_notifier.smtp_settings == nil
  end

  test "should normalize multiple digits into one N" do
    assert_equal 'N foo N bar N baz N',
      ExceptionNotifier::EmailNotifier.normalize_digits('1 foo 12 bar 123 baz 1234')
  end

  test "mail should be plain text and UTF-8 enconded by default" do
    assert @mail.content_type == "text/plain; charset=UTF-8"
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
    assert @mail.encoded.include? "A ZeroDivisionError occurred in background at #{@time}"
  end

  test "mail should prefix exception class with 'an' instead of 'a' when it starts with a vowel" do
    begin
      raise ActiveRecord::RecordNotFound
    rescue => e
      @vowel_exception = e
      @vowel_mail = @email_notifier.create_email(@vowel_exception)
    end

    assert @vowel_mail.encoded.include? "An ActiveRecord::RecordNotFound occurred in background at #{@time}"
  end

  test "mail should contain backtrace in body" do
    assert @mail.encoded.include?("test/email_notifier_test.rb:7"), "\n#{@mail.inspect}"
  end

  test "mail should contain data in body" do
    assert @mail.encoded.include? '* data:'
    assert @mail.encoded.include? ':payload=>"1/0"'
    assert @mail.encoded.include? ':job=>"DivideWorkerJob"'
    assert @mail.encoded.include? "My Custom Message"
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
        @ignored_mail = @email_notifier.create_email(@ignored_exception)
      end
    end

    assert @ignored_exception.class.inspect == "ActiveRecord::RecordNotFound"
    assert_nil @ignored_mail
  end
end
