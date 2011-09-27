require 'test_helper'

class PostsControllerTest < ActionController::TestCase
  setup do
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      @mail = ExceptionNotifier::Notifier.exception_notification(request.env, @exception)
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
    assert @mail.subject.include? "[Dummy ERROR] # (NoMethodError)"
  end

  test "mail should contain backtrace in body" do
    assert @mail.body.include? "`method_missing'\n  app/controllers/posts_controller.rb:17:in `create'\n"
  end

  test "should filter sensible data" do
    assert @mail.body.include? "secret\"=>\"[FILTERED]"
  end

  test "mail should not contain any attachments" do
    assert @mail.attachments == []
  end

  test "should not send notification if one of ignored exceptions" do
    begin
      get :show, :id => @post.to_param + "10"
    rescue => e
      @ignored_exception = e
      unless ExceptionNotifier.default_ignore_exceptions.include?(@ignored_exception.class)
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
    assert @secured_mail.body.include? "* session id: [FILTERED]\n  *"
  end

  test "should not include exception message in subject" do
    begin
      @post = posts(:one)
      post :create, :post => @post.attributes
    rescue => e
      @exception = e
      custom_env = request.env
      custom_env['exception_notifier.options']||={}
      custom_env['exception_notifier.options'].merge!(:verbose_subject => false)
      @mail = ExceptionNotifier::Notifier.exception_notification(custom_env, @exception)
    end
    assert_equal "[Dummy ERROR] # (NoMethodError)", @mail.subject
  end
end
