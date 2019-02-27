require 'test_helper'

class ExceptionOne < StandardError; end
class ExceptionTwo < StandardError; end

class ExceptionNotifierTest < ActiveSupport::TestCase
  setup do
    @notifier_calls = 0
    @test_notifier = ->(_exception, _options) { @notifier_calls += 1 }
  end

  teardown do
    ExceptionNotifier.error_grouping = false
    ExceptionNotifier.notification_trigger = nil
    ExceptionNotifier.class_eval('@@notifiers.delete_if { |k, _| k.to_s != "email"}') # reset notifiers
    Rails.cache.clear
  end

  test 'should have default ignored exceptions' do
    assert_equal ExceptionNotifier.ignored_exceptions,
                 ['ActiveRecord::RecordNotFound', 'Mongoid::Errors::DocumentNotFound', 'AbstractController::ActionNotFound',
                  'ActionController::RoutingError', 'ActionController::UnknownFormat', 'ActionController::UrlGenerationError']
  end

  test 'should have email notifier registered' do
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test 'should have a valid email notifier' do
    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    refute_nil @email_notifier
    assert_equal @email_notifier.class, ExceptionNotifier::EmailNotifier
    assert_respond_to @email_notifier, :call
  end

  test 'should allow register/unregister another notifier' do
    called = false
    proc_notifier = ->(_exception, _options) { called = true }
    ExceptionNotifier.register_exception_notifier(:proc, proc_notifier)

    assert_equal ExceptionNotifier.notifiers.sort, %i[email proc]

    exception = StandardError.new

    ExceptionNotifier.notify_exception(exception)
    assert called

    ExceptionNotifier.unregister_exception_notifier(:proc)
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test 'should allow register a third party notifier' do
    third_party_notification_service = Object.const_set('ThirdPartyNotificationService', Module.new)
    exception_notifier = third_party_notification_service.const_set('ExceptionNotifier', Module.new)
    third_party_notifier = exception_notifier.const_set('ThirdPartyNotifier', Class.new)

    third_party_notifier.class_eval do
      def initialize(options); end

      def call(exception, options); end
    end

    ExceptionNotifier.register_exception_notifier(:third_party, third_party_module: third_party_notification_service)

    assert_equal ExceptionNotifier.notifiers.sort, %i[email third_party]
  end

  test 'should allow select notifiers to send error to' do
    notifier1_calls = 0
    notifier1 = ->(_exception, _options) { notifier1_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:notifier1, notifier1)

    notifier2_calls = 0
    notifier2 = ->(_exception, _options) { notifier2_calls += 1 }
    ExceptionNotifier.register_exception_notifier(:notifier2, notifier2)

    assert_equal ExceptionNotifier.notifiers.sort, %i[email notifier1 notifier2]

    exception = StandardError.new
    ExceptionNotifier.notify_exception(exception)
    assert_equal notifier1_calls, 1
    assert_equal notifier2_calls, 1

    ExceptionNotifier.notify_exception(exception, notifiers: :notifier1)
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 1

    ExceptionNotifier.notify_exception(exception, notifiers: :notifier2)
    assert_equal notifier1_calls, 2
    assert_equal notifier2_calls, 2

    ExceptionNotifier.unregister_exception_notifier(:notifier1)
    ExceptionNotifier.unregister_exception_notifier(:notifier2)
    assert_equal ExceptionNotifier.notifiers, [:email]
  end

  test 'should ignore exception if satisfies conditional ignore' do
    env = 'production'
    ExceptionNotifier.ignore_if do |_exception, _options|
      env != 'production'
    end

    ExceptionNotifier.register_exception_notifier(:test, @test_notifier)

    exception = StandardError.new

    ExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    env = 'development'
    ExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    ExceptionNotifier.clear_ignore_conditions!
  end

  test 'should not send notification if one of ignored exceptions' do
    ExceptionNotifier.register_exception_notifier(:test, @test_notifier)

    exception = StandardError.new

    ExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    ExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: 'StandardError')
    assert_equal @notifier_calls, 1
  end

  test 'should not send notification if subclass of one of ignored exceptions' do
    ExceptionNotifier.register_exception_notifier(:test, @test_notifier)

    class StandardErrorSubclass < StandardError
    end

    exception = StandardErrorSubclass.new

    ExceptionNotifier.notify_exception(exception, notifiers: :test)
    assert_equal @notifier_calls, 1

    ExceptionNotifier.notify_exception(exception, notifiers: :test, ignore_exceptions: 'StandardError')
    assert_equal @notifier_calls, 1
  end

  test 'should call received block' do
    @block_called = false
    notifier = ->(_exception, _options, &block) { block.call }
    ExceptionNotifier.register_exception_notifier(:test, notifier)

    exception = ExceptionOne.new

    ExceptionNotifier.notify_exception(exception) do
      @block_called = true
    end

    assert @block_called
  end

  test 'should not call group_error! or send_notification? if error_grouping false' do
    exception = StandardError.new
    ExceptionNotifier.expects(:group_error!).never
    ExceptionNotifier.expects(:send_notification?).never

    ExceptionNotifier.notify_exception(exception)
  end

  test 'should call group_error! and send_notification? if error_grouping true' do
    ExceptionNotifier.error_grouping = true

    exception = StandardError.new
    ExceptionNotifier.expects(:group_error!).once
    ExceptionNotifier.expects(:send_notification?).once

    ExceptionNotifier.notify_exception(exception)
  end

  test 'should skip notification if send_notification? is false' do
    ExceptionNotifier.error_grouping = true

    exception = StandardError.new
    ExceptionNotifier.expects(:group_error!).once.returns(1)
    ExceptionNotifier.expects(:send_notification?).with(exception, 1).once.returns(false)

    refute ExceptionNotifier.notify_exception(exception)
  end

  test 'should send notification if send_notification? is true' do
    ExceptionNotifier.error_grouping = true

    exception = StandardError.new
    ExceptionNotifier.expects(:group_error!).once.returns(1)
    ExceptionNotifier.expects(:send_notification?).with(exception, 1).once.returns(true)

    assert ExceptionNotifier.notify_exception(exception)
  end
end
