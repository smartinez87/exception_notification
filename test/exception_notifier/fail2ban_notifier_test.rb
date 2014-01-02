require 'test_helper'
require 'httparty'

class Fail2banNotifierTest < ActiveSupport::TestCase
  test "should write exception notification to fail2ban log" do
    custom_log = Rails.root.join('tmp/fail2ban.log')

    ExceptionNotifier::Fail2banNotifier.stubs(:new).returns(Object.new)
    fail2ban = ExceptionNotifier::Fail2banNotifier.new({:logfile => custom_log})
    fail2ban.stubs(:call).returns(fake_response)

    notif = fail2ban.call(fake_exception)

    assert File.exists?(custom_log)
    last_line = File.read_lines(custom_log).last

    # Very basic test that just verifies we've got a remote IP and an
    # exception class in no particular order
    assert last_line.include? fake_response[:body][:request][:ip_address]
    assert last_line.include? fake_response[:body][:exception][:error_class]
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
