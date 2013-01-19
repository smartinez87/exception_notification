require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  setup do
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      @mail = ExceptionNotifier::Notifier.exception_notification(request.env, @exception, {:data => {:message => 'My Custom Message'}})
    end
  end

  test "should have raised an exception" do
    assert_not_nil @exception
  end

  test "should have generated a notification email" do
    assert_not_nil @mail
  end

  test "mail should be plain text and UTF-8 enconded by default" do
    assert @mail.content_type == "text/plain; charset=UTF-8"
  end

  test "mail should have a from address set" do
    assert @mail.from == ["dummynotifier@example.com"]
  end

  test "mail should have a to address set" do
    assert @mail.to == ["dummyexceptions@example.com"]
  end

  test "mail subject should have the proper prefix" do
    assert @mail.subject.include? "[Dummy ERROR]"
  end

  test "mail subject should include descriptive error message" do
    assert @mail.subject.include? "(NoMethodError) \"undefined method `nw'"
  end

  test "mail should contain backtrace in body" do
    assert @mail.encoded.include? "`method_missing'\r\n  app/controllers/posts_controller.rb:18:in `create'\r\n"
  end

  test "mail should contain timestamp of exception in body" do
    assert @mail.encoded.include? "Timestamp : #{Time.current}"
  end

  test "mail should contain the newly defined section" do
    assert @mail.encoded.include? "* New text section for testing"
  end

  test "mail should contain the custom message" do
    assert @mail.encoded.include? "My Custom Message"
  end

  test "should filter sensible data" do
    assert @mail.encoded.include? "secret\"=>\"[FILTERED]"
  end

  test "mail should contain the custom header" do
    assert @mail.headers["X-Custom-Header"] == "foobar"
  end

  test "mail should not contain any attachments" do
    assert @mail.attachments == []
  end

  test "should not send notification if one of ignored exceptions" do
    begin
      get :show, :id => @post.to_param + "10"
    rescue => e
      @ignored_exception = e
      unless ExceptionNotifier.default_ignore_exceptions.include?(@ignored_exception.class.name)
        @ignored_mail = ExceptionNotifier::Notifier.exception_notification(request.env, @ignored_exception)
      end
    end

    assert @ignored_exception.class.inspect == "ActiveRecord::RecordNotFound"
    assert_nil @ignored_mail
  end

  test "should filter session_id on secure requests" do
    request.env['HTTPS'] = 'on'
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @secured_mail = ExceptionNotifier::Notifier.exception_notification(request.env, e)
    end

    assert request.ssl?
    assert @secured_mail.encoded.include? "* session id: [FILTERED]\r\n  *"
  end

  test "should ignore exception if from unwanted cralwer" do
    request.env['HTTP_USER_AGENT'] = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options'] ||= {}
      custom_env['exception_notifier.options'].merge!(:ignore_crawlers => %w(Googlebot))
      ignore_array = custom_env['exception_notifier.options'][:ignore_crawlers]
      unless ExceptionNotifier.new(Dummy::Application, custom_env['exception_notifier.options']).send(:from_crawler, ignore_array, custom_env['HTTP_USER_AGENT'])
        @ignored_mail = ExceptionNotifier::Notifier.exception_notification(custom_env, @exception)
      end
    end

    assert_nil @ignored_mail
  end

  test "should ignore exception if satisfies conditional ignore" do
    request.env['IGNOREME'] = "IGNOREME"
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options'] ||= {}
      ignore_cond = {:ignore_if => lambda {|env, e| (env['IGNOREME'] == 'IGNOREME') && (e.message =~ /undefined method/)}}
      custom_env['exception_notifier.options'].merge!(ignore_cond)
      unless ExceptionNotifier.new(Dummy::Application, custom_env['exception_notifier.options']).send(:conditionally_ignored, ignore_cond[:ignore_if], custom_env, @exception)
        @ignored_mail = ExceptionNotifier::Notifier.exception_notification(custom_env, @exception)
      end
    end

    assert_nil @ignored_mail
  end

  test "should send html email when selected html format" do
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options'] ||= {}
      custom_env['exception_notifier.options'].merge!({:email_format => :html})
      @mail = ExceptionNotifier::Notifier.exception_notification(custom_env, @exception)
    end

    assert @mail.content_type.include? "multipart/alternative"
  end
end

class PostsControllerTestWithoutVerboseSubject < ActionController::TestCase
  tests PostsController
  setup do
    ExceptionNotifier::Notifier.default_verbose_subject = false
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      @mail = ExceptionNotifier::Notifier.exception_notification(request.env, @exception)
    end
  end

  test "should not include exception message in subject" do
    assert_equal "[ERROR] # (NoMethodError)", @mail.subject
  end
end

class PostsControllerTestWithSmtpSettings < ActionController::TestCase
  tests PostsController
  setup do
    ExceptionNotifier::Notifier.default_smtp_settings = {
      :user_name => "Dummy user_name",
      :password => "Dummy password"
    }
    
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      @mail = ExceptionNotifier::Notifier.exception_notification(request.env, @exception)
    end
  end

  test "should have overridden smtp settings" do
    assert_equal "Dummy user_name", @mail.delivery_method.settings[:user_name]
    assert_equal "Dummy password", @mail.delivery_method.settings[:password]
  end
  
  test "should have overridden smtp settings with background notification" do
    @mail = ExceptionNotifier::Notifier.background_exception_notification(@exception)
    assert_equal "Dummy user_name", @mail.delivery_method.settings[:user_name]
    assert_equal "Dummy password", @mail.delivery_method.settings[:password]
  end
end

class PostsControllerTestBadRequestData < ActionController::TestCase
  tests PostsController
  setup do
    begin
      # This might seem synthetic, but the point is that the data used by
      # ExceptionNotification could be rendered "invalid" by e.g. a badly
      # behaving middleware, and we want to test that ExceptionNotification
      # still manages to send off an email in those cases.
      #
      # The trick here is to trigger an exception in the template used by
      # ExceptionNotification. (The original test stuffed request.env with
      # badly encoded strings, but that only works in Ruby 1.9+.)
      request.send :instance_variable_set, :@env, {}

      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      @mail = ExceptionNotifier::Notifier.exception_notification(request.env, @exception)
    end
  end

  test "should include error message in body" do
    assert_match /ERROR: Failed to generate exception summary/, @mail.encoded.to_s
  end
end

class PostsControllerTestBackgroundNotification < ActionController::TestCase
  tests PostsController
  setup do
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => exception
      @mail = ExceptionNotifier::Notifier.background_exception_notification(exception)
    end
  end

  test "mail should contain the specified section" do
    assert @mail.encoded.include? "* New background section for testing"
  end
end
