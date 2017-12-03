require 'test_helper'
require 'action_mailer'

class EmailNotifierTest < ActiveSupport::TestCase
  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    begin
      1/0
    rescue => e
      @exception = e
      @mail = @email_notifier.create_email(@exception,
        :data => {:job => 'DivideWorkerJob', :payload => '1/0', :message => 'My Custom Message'})
    end
  end

  test "should call pre/post_callback if specified" do
    assert_equal @email_notifier.options[:pre_callback_called], 1
    assert_equal @email_notifier.options[:post_callback_called], 1
  end

  test "should have default sender address overridden" do
    assert_equal @email_notifier.sender_address, %("Dummy Notifier" <dummynotifier@example.com>)
  end

  test "should have default exception recipients overridden" do
    assert_equal @email_notifier.exception_recipients, %w(dummyexceptions@example.com)
  end

  test "should have default email prefix overridden" do
    assert_equal @email_notifier.email_prefix, "[Dummy ERROR] "
  end

  test "should have default email headers overridden" do
    assert_equal @email_notifier.email_headers, { "X-Custom-Header" => "foobar"}
  end

  test "should have default sections overridden" do
    for section in %w(new_section request session environment backtrace)
      assert_includes @email_notifier.sections, section
    end
  end

  test "should have default background sections" do
    for section in %w(new_bkg_section backtrace data)
      assert_includes @email_notifier.background_sections, section
    end
  end

  test "should have email format by default" do
    assert_equal @email_notifier.email_format, :text
  end

  test "should have verbose subject by default" do
    assert @email_notifier.verbose_subject
  end

  test "should have normalize_subject false by default" do
    refute @email_notifier.normalize_subject
  end

  test "should have delivery_method nil by default" do
    assert_nil @email_notifier.delivery_method
  end

  test "should have mailer_settings nil by default" do
    assert_nil @email_notifier.mailer_settings
  end

  test "should have mailer_parent by default" do
    assert_equal @email_notifier.mailer_parent, 'ActionMailer::Base'
  end

  test "should have template_path by default" do
    assert_equal @email_notifier.template_path, 'exception_notifier'
  end

  test "should normalize multiple digits into one N" do
    assert_equal 'N foo N bar N baz N',
      ExceptionNotifier::EmailNotifier.normalize_digits('1 foo 12 bar 123 baz 1234')
  end

  test "mail should be plain text and UTF-8 enconded by default" do
    assert_equal @mail.content_type, "text/plain; charset=UTF-8"
  end

  test "should have raised an exception" do
    refute_nil @exception
  end

  test "should have generated a notification email" do
    refute_nil @mail
  end

  test "mail should have a from address set" do
    assert_equal @mail.from, ["dummynotifier@example.com"]
  end

  test "mail should have a to address set" do
    assert_equal @mail.to, ["dummyexceptions@example.com"]
  end

  test "mail should have a descriptive subject" do
    assert_match(/^\[Dummy ERROR\]\s+\(ZeroDivisionError\) "divided by 0"$/, @mail.subject)
  end

  test "mail should say exception was raised in background at show timestamp" do
    assert_includes @mail.encoded, "A ZeroDivisionError occurred in background at #{Time.current}"
  end

  test "mail should prefix exception class with 'an' instead of 'a' when it starts with a vowel" do
    begin
      raise ActiveRecord::RecordNotFound
    rescue => e
      @vowel_exception = e
      @vowel_mail = @email_notifier.create_email(@vowel_exception)
    end

    assert_includes @vowel_mail.encoded, "An ActiveRecord::RecordNotFound occurred in background at #{Time.current}"
  end

  test "mail should contain backtrace in body" do
    assert @mail.encoded.include?("test/exception_notifier/email_notifier_test.rb:9"), "\n#{@mail.inspect}"
  end

  test "mail should contain data in body" do
    assert_includes @mail.encoded, '* data:'
    assert_includes @mail.encoded, ':payload=>"1/0"'
    assert_includes @mail.encoded, ':job=>"DivideWorkerJob"'
    assert_includes @mail.encoded, "My Custom Message"
  end

  test "mail should not contain any attachments" do
    assert_equal @mail.attachments, []
  end

  test "should not send notification if one of ignored exceptions" do
    begin
      raise ActiveRecord::RecordNotFound
    rescue => e
      @ignored_exception = e
      unless ExceptionNotifier.ignored_exceptions.include?(@ignored_exception.class.name)
        ignored_mail = @email_notifier.create_email(@ignored_exception)
      end
    end

    assert_equal @ignored_exception.class.inspect, "ActiveRecord::RecordNotFound"
    assert_nil ignored_mail
  end

  test "should encode environment strings" do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      :sender_address => "<dummynotifier@example.com>",
      :exception_recipients => %w{dummyexceptions@example.com},
      :deliver_with => :deliver_now
    )

    mail = email_notifier.create_email(
      @exception,
      :env => {
        "REQUEST_METHOD" => "GET",
        "rack.input" => "",
        "invalid_encoding" => "R\xC3\xA9sum\xC3\xA9".force_encoding(Encoding::ASCII),
      },
      :email_format => :text
    )

    assert_match(/invalid_encoding\s+: R__sum__/, mail.encoded)
  end

  test "should send email using ActionMailer" do
    ActionMailer::Base.deliveries.clear

    email_notifier = ExceptionNotifier::EmailNotifier.new(
      :email_prefix => '[Dummy ERROR] ',
      :sender_address => %{"Dummy Notifier" <dummynotifier@example.com>},
      :exception_recipients => %w{dummyexceptions@example.com},
      :delivery_method => :test
    )

    email_notifier.call(@exception)

    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test "should be able to specify ActionMailer::MessageDelivery method" do
    ActionMailer::Base.deliveries.clear

    if ActionMailer.version < Gem::Version.new("4.2")
      deliver_with = :deliver
    else
      deliver_with = :deliver_now
    end

    email_notifier = ExceptionNotifier::EmailNotifier.new(
      :email_prefix => '[Dummy ERROR] ',
      :sender_address => %{"Dummy Notifier" <dummynotifier@example.com>},
      :exception_recipients => %w{dummyexceptions@example.com},
      :deliver_with => deliver_with
    )

    email_notifier.call(@exception)

    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test "should lazily evaluate exception_recipients" do
    exception_recipients = %w{first@example.com second@example.com}
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      :email_prefix => '[Dummy ERROR] ',
      :sender_address => %{"Dummy Notifier" <dummynotifier@example.com>},
      :exception_recipients => -> { [ exception_recipients.shift ] },
      :delivery_method => :test
    )

    mail = email_notifier.call(@exception)
    assert_equal %w{first@example.com}, mail.to
    mail = email_notifier.call(@exception)
    assert_equal %w{second@example.com}, mail.to
  end

  test "should prepend accumulated_errors_count in email subject if accumulated_errors_count larger than 1" do
    ActionMailer::Base.deliveries.clear

    email_notifier = ExceptionNotifier::EmailNotifier.new(
      :email_prefix => '[Dummy ERROR] ',
      :sender_address => %{"Dummy Notifier" <dummynotifier@example.com>},
      :exception_recipients => %w{dummyexceptions@example.com},
      :delivery_method => :test
    )

    mail = email_notifier.call(@exception, { accumulated_errors_count: 3 })
    assert mail.subject.start_with?("[Dummy ERROR] (3 times) (ZeroDivisionError)")
  end
end
