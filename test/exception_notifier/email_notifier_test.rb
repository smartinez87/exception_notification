# frozen_string_literal: true

require 'test_helper'
require 'action_mailer'
require 'action_controller'

class EmailNotifierTest < ActiveSupport::TestCase
  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')

    @exception = ZeroDivisionError.new('divided by 0')
    @exception.set_backtrace(['test/exception_notifier/email_notifier_test.rb:20'])

    @email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      email_headers: { 'X-Custom-Header' => 'foobar' },
      sections: %w[new_section request session environment backtrace],
      background_sections: %w[new_bkg_section backtrace data],
      pre_callback: proc { |_opts, _notifier, _backtrace, _message, _message_opts| @pre_callback_called = true },
      post_callback: proc { |_opts, _notifier, _backtrace, _message, _message_opts| @post_callback_called = true },
      smtp_settings: {
        user_name: 'Dummy user_name',
        password: 'Dummy password'
      }
    )

    @mail = @email_notifier.call(
      @exception,
      data: { job: 'DivideWorkerJob', payload: '1/0', message: 'My Custom Message' }
    )
  end

  test 'should call pre/post_callback if specified' do
    assert @pre_callback_called
    assert @post_callback_called
  end

  test 'sends mail with correct content' do
    assert_equal %("Dummy Notifier" <dummynotifier@example.com>), @mail[:from].value
    assert_equal %w[dummyexceptions@example.com], @mail.to
    assert_equal '[Dummy ERROR]  (ZeroDivisionError) "divided by 0"', @mail.subject
    assert_equal 'foobar', @mail['X-Custom-Header'].value
    assert_equal 'text/plain; charset=UTF-8', @mail.content_type
    assert_equal [], @mail.attachments
    assert_equal 'Dummy user_name', @mail.delivery_method.settings[:user_name]
    assert_equal 'Dummy password', @mail.delivery_method.settings[:password]

    body = <<-BODY.gsub(/^      /, '')
      A ZeroDivisionError occurred in background at Sat, 20 Apr 2013 20:58:55 UTC +00:00 :

        divided by 0
        test/exception_notifier/email_notifier_test.rb:20

      -------------------------------
      New bkg section:
      -------------------------------

        * New background section for testing

      -------------------------------
      Backtrace:
      -------------------------------

        test/exception_notifier/email_notifier_test.rb:20

      -------------------------------
      Data:
      -------------------------------

        * data: {:job=>"DivideWorkerJob", :payload=>"1/0", :message=>"My Custom Message"}


    BODY

    assert_equal body, @mail.decode_body
  end

  test 'should normalize multiple digits into one N' do
    assert_equal 'N foo N bar N baz N',
                 ExceptionNotifier::EmailNotifier.normalize_digits('1 foo 12 bar 123 baz 1234')
  end

  test "mail should prefix exception class with 'an' instead of 'a' when it starts with a vowel" do
    begin
      raise ArgumentError
    rescue StandardError => e
      @vowel_exception = e
      @vowel_mail = @email_notifier.call(@vowel_exception)
    end

    assert_includes @vowel_mail.encoded, "An ArgumentError occurred in background at #{Time.current}"
  end

  test 'should not send notification if one of ignored exceptions' do
    begin
      raise AbstractController::ActionNotFound
    rescue StandardError => e
      @ignored_exception = e
      unless ExceptionNotifier.ignored_exceptions.include?(@ignored_exception.class.name)
        ignored_mail = @email_notifier.call(@ignored_exception)
      end
    end

    assert_equal @ignored_exception.class.inspect, 'AbstractController::ActionNotFound'
    assert_nil ignored_mail
  end

  test 'should encode environment strings' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      sender_address: '<dummynotifier@example.com>',
      exception_recipients: %w[dummyexceptions@example.com]
    )

    mail = email_notifier.call(
      @exception,
      env: {
        'REQUEST_METHOD' => 'GET',
        'rack.input' => '',
        'invalid_encoding' => "R\xC3\xA9sum\xC3\xA9".dup.force_encoding(Encoding::ASCII)
      }
    )

    assert_match(/invalid_encoding\s+: R__sum__/, mail.encoded)
  end

  test 'should send email using ActionMailer' do
    ActionMailer::Base.deliveries.clear
    @email_notifier.call(@exception)
    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test 'should be able to specify ActionMailer::MessageDelivery method' do
    ActionMailer::Base.deliveries.clear

    deliver_with = if ActionMailer.version < Gem::Version.new('4.2')
                     :deliver
                   else
                     :deliver_now
                   end

    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      deliver_with: deliver_with
    )

    email_notifier.call(@exception)

    assert_equal 1, ActionMailer::Base.deliveries.count
  end

  test 'should lazily evaluate exception_recipients' do
    exception_recipients = %w[first@example.com second@example.com]
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: -> { [exception_recipients.shift] },
      delivery_method: :test
    )

    mail = email_notifier.call(@exception)
    assert_equal %w[first@example.com], mail.to
    mail = email_notifier.call(@exception)
    assert_equal %w[second@example.com], mail.to
  end

  test 'should prepend accumulated_errors_count in email subject if accumulated_errors_count larger than 1' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      delivery_method: :test
    )

    mail = email_notifier.call(@exception, accumulated_errors_count: 3)
    assert mail.subject.start_with?('[Dummy ERROR] (3 times) (ZeroDivisionError)')
  end

  test 'should not include exception message in subject when verbose_subject: false' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      verbose_subject: false
    )

    mail = email_notifier.call(@exception)

    assert_equal '[ERROR]  (ZeroDivisionError)', mail.subject
  end

  test 'should send html email when selected html format' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      email_format: :html
    )

    mail = email_notifier.call(@exception)

    assert mail.multipart?
  end
end

class EmailNotifierWithEnvTest < ActiveSupport::TestCase
  class HomeController < ActionController::Metal
    def index; end
  end

  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')

    @exception = ZeroDivisionError.new('divided by 0')
    @exception.set_backtrace(['test/exception_notifier/email_notifier_test.rb:20'])

    @email_notifier = ExceptionNotifier::EmailNotifier.new(
      email_prefix: '[Dummy ERROR] ',
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      email_headers: { 'X-Custom-Header' => 'foobar' },
      sections: %w[new_section request session environment backtrace],
      background_sections: %w[new_bkg_section backtrace data],
      pre_callback:
        proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:pre_callback_called] = 1 },
      post_callback:
        proc { |_opts, _notifier, _backtrace, _message, message_opts| message_opts[:post_callback_called] = 1 }
    )

    @controller = HomeController.new
    @controller.process(:index)

    @test_env = Rack::MockRequest.env_for(
      '/',
      'HTTP_HOST' => 'test.address',
      'REMOTE_ADDR' => '127.0.0.1',
      'HTTP_USER_AGENT' => 'Rails Testing',
      'action_dispatch.parameter_filter' => ['secret'],
      'HTTPS' => 'on',
      'action_controller.instance' => @controller,
      params: { id: 'foo', secret: 'secret' }
    )

    @mail = @email_notifier.call(@exception, env: @test_env, data: { message: 'My Custom Message' })
  end

  test 'sends mail with correct content' do
    assert_equal %("Dummy Notifier" <dummynotifier@example.com>), @mail[:from].value
    assert_equal %w[dummyexceptions@example.com], @mail.to
    assert_equal '[Dummy ERROR] home#index (ZeroDivisionError) "divided by 0"', @mail.subject
    assert_equal 'foobar', @mail['X-Custom-Header'].value
    assert_equal 'text/plain; charset=UTF-8', @mail.content_type
    assert_equal [], @mail.attachments

    body = <<-BODY.gsub(/^      /, '')
      A ZeroDivisionError occurred in home#index:

        divided by 0
        test/exception_notifier/email_notifier_test.rb:20


      -------------------------------
      New section:
      -------------------------------

        * New text section for testing

      -------------------------------
      Request:
      -------------------------------

        * URL        : https://test.address/?id=foo&secret=secret
        * HTTP Method: GET
        * IP address : 127.0.0.1
        * Parameters : {\"id\"=>\"foo\", \"secret\"=>\"[FILTERED]\"}
        * Timestamp  : Sat, 20 Apr 2013 20:58:55 UTC +00:00
        * Server : #{Socket.gethostname}
    BODY

    body << "    * Rails root : #{Rails.root}\n" if defined?(Rails) && Rails.respond_to?(:root)

    body << <<-BODY.gsub(/^      /, '')
        * Process: #{Process.pid}

      -------------------------------
      Session:
      -------------------------------

        * session id: [FILTERED]
        * data: {}

      -------------------------------
      Environment:
      -------------------------------

        * CONTENT_LENGTH                            : 0
          * HTTPS                                     : on
          * HTTP_HOST                                 : test.address
          * HTTP_USER_AGENT                           : Rails Testing
          * PATH_INFO                                 : /
          * QUERY_STRING                              : id=foo&secret=secret
          * REMOTE_ADDR                               : 127.0.0.1
          * REQUEST_METHOD                            : GET
          * SCRIPT_NAME                               :
          * SERVER_NAME                               : example.org
          * SERVER_PORT                               : 80
          * action_controller.instance                : #{@controller}
          * action_dispatch.parameter_filter          : [\"secret\"]
          * action_dispatch.request.content_type      :
          * action_dispatch.request.parameters        : {"id"=>"foo", "secret"=>"[FILTERED]"}
          * action_dispatch.request.path_parameters   : {}
          * action_dispatch.request.query_parameters  : {"id"=>"foo", "secret"=>"[FILTERED]"}
          * action_dispatch.request.request_parameters: {}
          * rack.errors                               : #{@test_env['rack.errors']}
          * rack.input                                : #{@test_env['rack.input']}
          * rack.multiprocess                         : true
          * rack.multithread                          : true
          * rack.request.query_hash                   : {"id"=>"foo", "secret"=>"[FILTERED]"}
          * rack.request.query_string                 : id=foo&secret=secret
          * rack.run_once                             : false
          * rack.session                              : {}
          * rack.url_scheme                           : http
          * rack.version                              : #{Rack::VERSION}

      -------------------------------
      Backtrace:
      -------------------------------

        test/exception_notifier/email_notifier_test.rb:20

      -------------------------------
      Data:
      -------------------------------

        * data: {:message=>\"My Custom Message\"}


    BODY

    assert_equal body, @mail.decode_body
  end

  test 'should not include controller and action names in subject' do
    email_notifier = ExceptionNotifier::EmailNotifier.new(
      sender_address: %("Dummy Notifier" <dummynotifier@example.com>),
      exception_recipients: %w[dummyexceptions@example.com],
      include_controller_and_action_names_in_subject: false
    )

    mail = email_notifier.call(@exception, env: @test_env)

    assert_equal '[ERROR]  (ZeroDivisionError) "divided by 0"', mail.subject
  end
end
