require 'test_helper'

class EmailNotifierRequestTest < ActiveSupport::TestCase
  setup do
    Time.stubs(:current).returns('Sat, 20 Apr 2013 20:58:55 UTC +00:00')

    @email_notifier = ExceptionNotifier.registered_exception_notifier(:email)
    begin
      1/0
    rescue => e
      @exception = e
      @mail      = @email_notifier.create_email(
          @exception,
          :env => {
              'REQUEST_METHOD' => 'GET'.freeze,
              'HTTP_HOST'      => 'example.com',
              'QUERY_STRING'   => 'data=привет&utf8=✓'.b,
              'rack.input'     => true
          }
      )
    end
  end

  test "request mail should contain unicode in body" do
    assert @mail.body.include? '✓'
    assert @mail.body.include? 'привет'
  end

end
