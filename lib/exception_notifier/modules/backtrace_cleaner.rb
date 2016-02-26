module ExceptionNotifier
  module BacktraceCleaner

    def clean_backtrace(exception)

      if ExceptionNotifier.clean_backtrace && defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
        Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
        exception.backtrace
      end
    end

  end
end
