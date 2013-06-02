require 'test_helper'
require 'httparty'

class WebhookNotifierTest < ActiveSupport::TestCase

  test "should send webhook notification if properly configured" do
    ExceptionNotifier::WebhookNotifier.stubs(:new).returns(Object.new)
    webhook = ExceptionNotifier::WebhookNotifier.new({:url => 'http://localhost:8000'})
    webhook.stubs(:call).returns(fake_response)
    response = webhook.call(fake_exception)

    assert_not_nil response
    assert_equal response[:status], 200
    assert_equal response[:body][:exception][:error_class], "ZeroDivisionError"
    assert response[:body][:exception][:message].include? "divided by 0"
    assert response[:body][:exception][:backtrace].include? "/exception_notification/test/webhook_notifier_test.rb:48"
  end

  private

  def fake_response
    {
      :status => 200,
      :body => {
        :exception => {
          :error_class => 'ZeroDivisionError',
          :message => 'divided by 0',
          :backtrace => '/exception_notification/test/webhook_notifier_test.rb:48:in `/'
        }
      }
    }
  end

  def fake_exception
    exception = begin
      5/0
    rescue Exception => e
      e
    end
  end
end
