require 'test_helper'

class ThrottleNotifierTest < ActiveSupport::TestCase
  setup do
    @throttle = ExceptionNotifier::ThrottleNotifier.new notifier: :email
    @notifier = @throttle.instance_variable_get "@notifier"
  end

  test "should delegate to notifier by default" do
    exception = Exception.new
    options = {}
    @notifier.expects(:call).with(exception, options)

    @throttle.call exception, options
  end

  test "should stop delegating after three equivalent exceptions occur" do
    exception = Exception.new
    options = {}
    @notifier.expects(:call).with(exception, options).times(3)
    ExceptionNotifier::logger.expects(:warn).stubs(:warn)

    4.times { @throttle.call exception, options }
  end

  test "should resume delegating after an hour has passed" do
    Time.stubs(:now).returns(Time.new 2000,1,1,1)
    exception = Exception.new
    options = {}
    @notifier.stubs(:call)
    ExceptionNotifier::logger.expects(:warn).times(2).stubs(:warn)

    4.times { @throttle.call exception, options }

    Time.stubs(:now).returns(Time.new 2000,1,1,2)
    @notifier.expects(:call).with(exception, options).times(3)

    4.times { @throttle.call exception, options }
  end
end

