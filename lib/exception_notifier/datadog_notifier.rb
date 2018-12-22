module ExceptionNotifier

  class DatadogNotifier < BaseNotifier

    attr_reader :client,
      :default_options

    def initialize(options)
      super
      @client = options.fetch(:client)
      @default_options = options
    end

    def call(exception, options = {})
      client.emit_event(
        datadog_event(exception, options)
      )
    end

    def datadog_event(exception, options = {})
      DatadogExceptionEvent.new(
        exception,
        options.reverse_merge(default_options)
      ).event
    end

    private

    class DatadogExceptionEvent
      include ExceptionNotifier::BacktraceCleaner

      MAX_TITLE_LENGTH = 120
      MAX_VALUE_LENGTH = 300
      MAX_BACKTRACE_SIZE = 3
      ALERT_TYPE = "error"

      attr_reader :exception,
        :options

      def initialize(exception, options)
        @exception = exception
        @options = options
      end

      def request
        @request ||= ActionDispatch::Request.new(options[:env]) if options[:env]
      end

      def controller
        @controller ||= options[:env] && options[:env]['action_controller.instance']
      end

      def backtrace
        @backtrace ||= exception.backtrace ? clean_backtrace(exception) : []
      end

      def tags
        options[:tags] || []
      end

      def title_prefix
        options[:title_prefix] || ""
      end

      def event
        title = formatted_title
        body = formatted_body

        Dogapi::Event.new(
          body,
          msg_title: title,
          alert_type: ALERT_TYPE,
          tags: tags,
          aggregation_key: [title]
        )
      end

      def formatted_title
        title = title_prefix
        title << "#{controller.controller_name} #{controller.action_name}" if controller
        title << " (#{exception.class})"
        title << " #{exception.message.inspect}"

        truncate(title, MAX_TITLE_LENGTH)
      end

      def formatted_body
        text = []

        text << "%%%"
        text << formatted_request if request
        text << formatted_session if request
        text << formatted_backtrace
        text << "%%%"

        text.join("\n")
      end

      def formatted_key_value(key, value)
        "**#{key}:** #{value}"
      end

      def formatted_request
        text = []
        text << "### **Request**"
        text << formatted_key_value("URL", request.url)
        text << formatted_key_value("HTTP Method", request.request_method)
        text << formatted_key_value("IP Address", request.remote_ip)
        text << formatted_key_value("Parameters", request.filtered_parameters.inspect)
        text << formatted_key_value("Timestamp", Time.current)
        text << formatted_key_value("Server", Socket.gethostname)
        if defined?(Rails) && Rails.respond_to?(:root)
          text << formatted_key_value("Rails root", Rails.root)
        end
        text << formatted_key_value("Process", $$)
        text << "___"
        text.join("\n")
      end

      def formatted_session
        text = []
        text << "### **Session**"
        text << formatted_key_value("Data", request.session.to_hash)
        text << "___"
        text.join("\n")
      end

      def formatted_backtrace
        size = [backtrace.size, MAX_BACKTRACE_SIZE].min

        text = []
        text << "### **Backtrace**"
        text << "````"
        size.times { |i| text << backtrace[i] }
        text << "````"
        text << "___"
        text.join("\n")
      end

      def truncate(string, max)
        string.length > max ? "#{string[0...max]}..." : string
      end

      def inspect_object(object)
        case object
          when Hash, Array
            truncate(object.inspect, MAX_VALUE_LENGTH)
          else
            object.to_s
        end
      end

    end
  end

end

