require 'test_helper'
require 'dogapi/common'
require 'dogapi/event'

class DatadogNotifierTest < ActiveSupport::TestCase
  def setup
    @dd_client = FakeDatadogClient.new
    @options = {
      dd_client: @dd_client
    }
    @notifier = ExceptionNotifier::DatadogNotifier.new(@options)
    @exception = FakeException.new
    @controller = FakeController.new
    @request = FakeRequest.new
  end

  test "should send an event to datadog" do
    fake_event = Dogapi::Event.any_instance
    @dd_client.expects(:emit_event).with(fake_event)

    @notifier.stubs(:datadog_event).returns(fake_event)
    @notifier.call(@exception)
  end

  test "should include exception class in event title" do
    event = @notifier.datadog_event(@exception)
    assert_includes event.msg_title, "FakeException"
  end

  test "should include exception message in event title" do
    event = @notifier.datadog_event(@exception)
    assert_includes event.msg_title, "Fake exception message"
  end

  test "should include controller info in event title if controller information is available" do
    event = @notifier.datadog_event(@exception, {
      env: {
        "action_controller.instance" => @controller,
        "REQUEST_METHOD" => "GET",
        "rack.input" => "",
      }
    })
    assert_includes event.msg_title, "Fake controller"
    assert_includes event.msg_title, "Fake action"
  end

  test "should include backtrace info in event body" do
    event = @notifier.datadog_event(@exception)
    assert_includes event.msg_text, "backtrace line 1\nbacktrace line 2\nbacktrace line 3"
  end

  test "should include request info in event body" do
    ActionDispatch::Request.stubs(:new).returns(@request)

    event = @notifier.datadog_event(@exception, {
      env: {
        "action_controller.instance" => @controller,
        "REQUEST_METHOD" => "GET",
        "rack.input" => "",
      }
    })
    assert_includes event.msg_text, "http://localhost:8080"
    assert_includes event.msg_text, "GET"
    assert_includes event.msg_text, "127.0.0.1"
    assert_includes event.msg_text, "{\"param 1\"=>\"value 1\", \"param 2\"=>\"value 2\"}"
  end

  test "should include tags in event" do
    options = {
      dd_client: @dd_client,
      tags: ["error", "production"]
    }
    notifier = ExceptionNotifier::DatadogNotifier.new(options)
    event = notifier.datadog_event(@exception)
    assert_equal event.tags, ["error", "production"]
  end

  test "should include event title in event aggregation key" do
    event = @notifier.datadog_event(@exception)
    assert_equal event.aggregation_key, [event.msg_title]
  end

  private

  class FakeDatadogClient
    def emit_event(event)
    end
  end

  class FakeController
    def controller_name
      "Fake controller"
    end

    def action_name
      "Fake action"
    end
  end

  class FakeException
    def backtrace
      [
        "backtrace line 1",
        "backtrace line 2",
        "backtrace line 3",
        "backtrace line 4",
        "backtrace line 5"
      ]
    end

    def message
      "Fake exception message"
    end
  end

  class FakeRequest
    def url
      "http://localhost:8080"
    end

    def request_method
      "GET"
    end

    def remote_ip
      "127.0.0.1"
    end

    def filtered_parameters
      {
        "param 1" => "value 1",
        "param 2" => "value 2"
      }
    end
  end

end
