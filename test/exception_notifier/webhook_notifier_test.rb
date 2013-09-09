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
    
    assert response[:body][:request][:cookies].has_key?(:cookie_item1)
    assert_equal response[:body][:request][:url], "http://example.com/example"
    assert_equal response[:body][:request][:ip_address], "192.168.1.1"
    assert response[:body][:request][:environment].has_key?(:env_item1)
    assert_equal response[:body][:request][:controller], "#<ControllerName:0x007f9642a04d00>"
    assert response[:body][:request][:session].has_key?(:session_item1)
    assert response[:body][:request][:parameters].has_key?(:controller)
    assert response[:body][:data][:extra_data].has_key?(:data_item1)
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
        },
        :data => {
          :extra_data => {:data_item1 => "datavalue1", :data_item2 => "datavalue2"}
        },
        :request => {
          :cookies => {:cookie_item1 => 'cookieitemvalue1', :cookie_item2 => 'cookieitemvalue2'},
          :url => 'http://example.com/example',
          :ip_address => '192.168.1.1',
          :environment => {:env_item1 => "envitem1", :env_item2 => "envitem2"},
          :controller => '#<ControllerName:0x007f9642a04d00>',
          :session => {:session_item1 => "sessionitem1", :session_item2 => "sessionitem2"},
          :parameters => {:action =>"index", :controller =>"projects"}
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
