class ExceptionNotifier
  class SlackNotifier

    attr_accessor :notifier
    attr_accessor :webhook_url
    attr_accessor :channel
    attr_accessor :additional_parameters

    def initialize(options)
      begin
        @ignore_data_if = options[:ignore_data_if]

        webhook_url = options.fetch(:webhook_url)
        @message_opts = options.fetch(:additional_parameters, {})
        @notifier = Slack::Notifier.new webhook_url, options
      rescue
        @notifier = nil
      end
    end

    def call(exception, options={})
      message = "An exception occurred: '#{exception.message}'"
      message += " on '#{exception.backtrace.first}'" if exception.backtrace

      message = enrich_message_with_data(message, options)
      message = enrich_message_with_backtrace(message, exception) if exception.backtrace

      @notifier.ping(message, @message_opts) if valid?
    end

    protected

    def valid?
      !@notifier.nil?
    end

    def enrich_message_with_data(message, options)
      def deep_reject(hash, block)
        hash.each do |k, v|
          if v.is_a?(Hash)
            deep_reject(v, block)
          end

          if block.call(k, v)
            hash.delete(k)
          end
        end
      end

      data = ((options[:env] || {})['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
      deep_reject(data, @ignore_data_if) if @ignore_data_if.is_a?(Proc)
      text = data.map{|k,v| "#{k}: #{v}"}.join(', ')

      unless text.nil? || text.empty?
        text = ['*Data:*', text].join("\n")
        [message, text].join("\n")
      else
        message
      end
    end

    def enrich_message_with_backtrace(message, exception)
      backtrace = clean_backtrace(exception).first(10).join("\n")
      [message, ['*Backtrace:*', backtrace]].join("\n")
    end

  end
end