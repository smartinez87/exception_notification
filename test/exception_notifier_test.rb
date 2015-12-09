require 'test_helper'

class ExceptionNotifierTest < ActiveSupport::TestCase
  test "should have default ignored exceptions" do
    assert_equal ExceptionNotifier.ignored_exceptions, ['ActiveRecord::RecordNotFound', 'AbstractController::ActionNotFound', 'ActionController::RoutingError', 'ActionController::UnknownFormat']
  end

  test "should have email notifier registered" do
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test "should have a valid email notifier" do
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    refute_nil @email_notifier
    assert_equal @email_notifier.class, ExceptionNotifier::EmailNotifier
    assert_respond_to @email_notifier, :call
  end

  test "should allow register/unregister another notifier" do
    called = false
    proc_notifier = lambda { |exception, options| called = true }
    ExceptionNotifier.register_exception_notifier(:proc, proc_notifier)

    assert_equal ExceptionNotifier.notifiers.sort, [:email, :proc]

    exception = StandardError.new
    ExceptionNotifier.notify_exception(exception)
    assert called

    ExceptionNotifier.unregister_exception_notifier(:proc)
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test "should allow select notifiers to send error to" do
    notifier1_calls = 0
    notifier1 = lambda { |exception, options| notifier1_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:notifier1, notifier1)

    notifier2_calls = 0
    notifier2 = lambda { |exception, options| notifier2_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:notifier2, notifier2)

    assert_equal ExceptionNotifier.notifiers.sort, [:email, :notifier1, :notifier2]

    exception = StandardError.new
    ExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 1
    assert_equal notifier2_calls, 1

    ExceptionNotifier.notify_exception(exception, {:notifiers => :notifier1})
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 1

    ExceptionNotifier.notify_exception(exception, {:notifiers => :notifier2})
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 2

    ExceptionNotifier.unregister_exception_notifier(:notifier1)
    ExceptionNotifier.unregister_exception_notifier(:notifier2)
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test "can catch database connection pool problems" do
    begin
      a = b = nil
      a = ActiveRecord::Base.connection_pool.checkout
      b = ActiveRecord::Base.connection_pool.checkout
      ActiveRecord::Base.connection_pool.checkout

    ensure
      ActiveRecord::Base.connection_pool.checkin a rescue nil
      ActiveRecord::Base.connection_pool.checkin b rescue nil
    end
  end

  test "should ignore exception if satisfies conditional ignore" do
    env = "production"
    ExceptionNotifier.ignore_if do |exception, options|
      env != "production"
    end

    notifier_calls = 0
    test_notifier = lambda { |exception, options| notifier_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:test, test_notifier)

    exception = StandardError.new

    ExceptionNotifier.notify_exception(exception, {:notifiers => :test})
    assert_equal notifier_calls, 1

    env = "development"
    ExceptionNotifier.notify_exception(exception, {:notifiers => :test})
    assert_equal notifier_calls, 1

    ExceptionNotifier.clear_ignore_conditions!
    ExceptionNotifier.unregister_exception_notifier(:test)
  end

  test "should not send notification if one of ignored exceptions" do
    notifier_calls = 0
    test_notifier = lambda { |exception, options| notifier_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:test, test_notifier)

    exception = StandardError.new

    ExceptionNotifier.notify_exception(exception, {:notifiers => :test})
    assert_equal notifier_calls, 1

    ExceptionNotifier.notify_exception(exception, {:notifiers => :test, :ignore_exceptions => 'StandardError' })
    assert_equal notifier_calls, 1

    ExceptionNotifier.unregister_exception_notifier(:test)
  end
end
