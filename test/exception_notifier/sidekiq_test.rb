require "test_helper"

# To allow sidekiq error handlers to be registered, sidekiq must be in
# "server mode". This mode is triggered by loading sidekiq/cli. Note this
# has to be loaded before exception_notification/sidekiq.
require "sidekiq/cli"

require "exception_notification/sidekiq"

class MockSidekiqServer
  include ::Sidekiq::ExceptionHandler
end

class SidekiqTest < ActiveSupport::TestCase
  setup do
    @_original_sidekiq_logger = Sidekiq::Logging.logger

    # Silence sidekiq warning to stdout
    Sidekiq::Logging.logger = nil
  end

  test "should call notify_exception when sidekiq raises an error" do
    server = MockSidekiqServer.new
    message = Hash.new
    exception = RuntimeError.new

    ExceptionNotifier.expects(:notify_exception).with(
      exception,
      :data => { :sidekiq => message }
    )

    server.handle_exception(exception, message)
  end

  teardown do
    Sidekiq::Logging.logger = @_original_sidekiq_logger
  end
end
