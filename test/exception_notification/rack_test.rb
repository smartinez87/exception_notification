require 'test_helper'

class RackTest < ActiveSupport::TestCase

  setup do
    @pass_app = Object.new
    @pass_app.stubs(:call).returns([nil, { 'X-Cascade' => 'pass' }, nil])

    @normal_app = Object.new
    @normal_app.stubs(:call).returns([nil, { }, nil])
  end

  teardown do
    ExceptionNotifier.error_grouping = false
    ExceptionNotifier.notification_trigger = nil
  end

  test "should ignore \"X-Cascade\" header by default" do
    ExceptionNotifier.expects(:notify_exception).never
    ExceptionNotification::Rack.new(@pass_app).call({})
  end

  test "should notify on \"X-Cascade\" = \"pass\" if ignore_cascade_pass option is false" do
    ExceptionNotifier.expects(:notify_exception).once
    ExceptionNotification::Rack.new(@pass_app, :ignore_cascade_pass => false).call({})
  end

  test "should assign error_grouping if error_grouping is specified" do
    refute ExceptionNotifier.error_grouping
    ExceptionNotification::Rack.new(@normal_app, error_grouping: true).call({})
    assert ExceptionNotifier.error_grouping
  end

  test "should assign notification_trigger if notification_trigger is specified" do
    assert_nil ExceptionNotifier.notification_trigger
    ExceptionNotification::Rack.new(@normal_app, notification_trigger: lambda {|i| true}).call({})
    assert_respond_to ExceptionNotifier.notification_trigger, :call
  end

  test "should set default cache to Rails cache" do
    ExceptionNotification::Rack.new(@normal_app, error_grouping: true).call({})
    assert_equal Rails.cache, ExceptionNotifier.error_grouping_cache
  end
end
