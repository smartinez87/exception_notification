module ExceptionNotifier
  class IrcNotifier < BaseNotifier
    def initialize(options)
      super
      @config = OpenStruct.new
      parse_options(options)
    end

    def call(exception, options={})
      errors_count = options[:accumulated_errors_count].to_i

      message = "'#{exception.message}'"
      message.prepend("(#{errors_count} times)") if errors_count > 1

      message += " on '#{exception.backtrace.first}'" if exception.backtrace
      if active?
        send_notice(exception, options, message) do |msg, _|
          send_message([*@config.prefix, *msg].join(' '))
        end
      end
    end

    def send_message(message)
      CarrierPigeon.send @config.irc.merge({message: message})
    end

    private
      def parse_options(options)
        nick = options.fetch(:nick, 'ExceptionNotifierBot')
        password = options[:password] ? ":#{options[:password]}" : nil
        domain = options.fetch(:domain, nil)
        port = options[:port] ? ":#{options[:port]}" : nil
        channel = options.fetch(:channel, '#log')
        notice = options.fetch(:notice, false)
        ssl = options.fetch(:ssl, false)
        join = options.fetch(:join, false)
        uri = "irc://#{nick}#{password}@#{domain}#{port}/#{channel}"
        prefix = options.fetch(:prefix, nil)
        recipients = options[:recipients] ? options[:recipients].join(', ') + ':' : nil

        @config.prefix = [*prefix, *recipients].join(' ')
        @config.irc = { uri: uri, ssl: ssl, notice: notice, join: join }
      end

      def active?
        valid_uri? @config.irc[:uri]
      end

      def valid_uri?(uri)
        !!URI.parse(uri)
      rescue URI::InvalidURIError
        false
      end
  end
end
