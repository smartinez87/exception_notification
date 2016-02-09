module ExceptionNotifier
  class SlackNotifier < BaseNotifier
    include ExceptionNotifier::BacktraceCleaner

    attr_accessor :notifier

    def initialize(options)
      super
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
      if options[:env].nil?
        data = options[:data] || {}
        text = "*#{exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'}* `#{exception.class.to_s}` *occured in background*\n"
      else
        env = options[:env] || {}
        title = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"
        data = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
        text = "*An exception occurred while doing*: `#{title}`\n"
      end

      clean_message = exception.message.gsub("`", "'")
      fields = [ { title: 'Exception', value: clean_message} ]

      fields.push({ title: 'Hostname', value: Socket.gethostname })

      if exception.backtrace
        formatted_backtrace = "```#{exception.backtrace.first(5).join("\n")}```"
        fields.push({ title: 'Backtrace', value: formatted_backtrace })
      end

      unless data.empty?
        deep_reject(data, @ignore_data_if) if @ignore_data_if.is_a?(Proc)
        data_string = data.map{|k,v| "#{k}: #{v}"}.join("\n")
        fields.push({ title: 'Data', value: "```#{data_string}```" })
      end

      attchs = [color: 'danger', text: text, fields: fields, mrkdwn_in: %w(text fields)]

      if valid?
        send_notice(exception, options, clean_message, @message_opts.merge(attachments: attchs)) do |msg, message_opts|
          @notifier.ping '', message_opts
        end
      end
    end

    protected

    def valid?
      !@notifier.nil?
    end

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

  end
end
