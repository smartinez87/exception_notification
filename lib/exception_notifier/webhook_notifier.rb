require 'action_dispatch'
require 'active_support/core_ext/time'

module ExceptionNotifier
  class WebhookNotifier < BaseNotifier

    def initialize(options)
      super
      @default_options = options
    end

    def call(exception, options={})
      env = options[:env]

      options = options.reverse_merge(@default_options)
      url = options.delete(:url)
      http_method = options.delete(:http_method) || :post

      options[:body] ||= {}
      options[:body][:server] = Socket.gethostname
      options[:body][:process] = $$
      if defined?(Rails) && Rails.respond_to?(:root)
        options[:body][:rails_root] = Rails.root
      end
      options[:body][:exception] = {:error_class => exception.class.to_s,
                                    :message => exception.message.inspect,
                                    :backtrace => exception.backtrace}
      options[:body][:data] = (env && env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})

      unless env.nil?
        request = ActionDispatch::Request.new(env)

        request_items = {:url => request.original_url,
                         :http_method => request.method,
                         :ip_address => request.remote_ip,
                         :parameters => request.filtered_parameters,
                         :timestamp => Time.current }

        options[:body][:request] = request_items
        options[:body][:session] = request.session
        options[:body][:environment] = request.filtered_env
      end
      send_notice(exception, options, nil, @default_options) do |_, _|
        HTTParty.send(http_method, url, options)
      end
    end
  end
end
