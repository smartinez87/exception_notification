module ExceptionNotifier
  class WebhookNotifier

    def initialize(options)
      @default_options = options
    end

    def call(exception, options={})
      options = options.reverse_merge(@default_options)
      url = options.delete(:url)
      http_method = options.delete(:http_method) || :post

      options[:body] ||= {}
      options[:body][:exception] = {:error_class => exception.class.to_s,
                                    :message => exception.message.inspect,
                                    :backtrace => exception.backtrace}

      HTTParty.send(http_method, url, options)
    end
  end
end
