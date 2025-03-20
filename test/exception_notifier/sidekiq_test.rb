# frozen_string_literal: true

require 'test_helper'

# To allow sidekiq error handlers to be registered, sidekiq must be in
# "server mode". This mode is triggered by loading sidekiq/cli. Note this
# has to be loaded before exception_notification/sidekiq.
require 'sidekiq/cli'
require 'sidekiq/testing'

require 'exception_notification/sidekiq'

class MockSidekiqServer
  include ::Sidekiq::Component

  def config
    Sidekiq.default_configuration
  end
end

class SidekiqTest < ActiveSupport::TestCase
  test 'should call notify_exception when sidekiq raises an error' do
    server = MockSidekiqServer.new
    message = {}
    exception = RuntimeError.new

    ExceptionNotifier.expects(:notify_exception).with(
      exception,
      data: { sidekiq: message }
    )

    server.handle_exception(exception, message)
  end
end
