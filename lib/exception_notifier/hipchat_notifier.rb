module ExceptionNotifier
  class HipchatNotifier

    attr_accessor :from
    attr_accessor :room
    attr_accessor :message_options

    def initialize(options)
      begin
        api_token         = options.delete(:api_token)
        api_version       = options.delete(:api_version) || 'v1'
        room_name         = options.delete(:room_name)
        @from             = options.delete(:from) || 'Exception'
        @room             = HipChat::Client.new(api_token, :api_version => api_version)[room_name]
        @message_template = options.delete(:message_template) || ->(exception) {
          "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'"
        }
        @message_options  = options
        @message_options[:color] ||= 'red'
      rescue
        @room = nil
      end
    end

    def call(exception, options={})
      return if !active?

      message = @message_template.call(exception)
      @room.send(@from, message, @message_options)
    end

    private

    def active?
      !@room.nil?
    end
  end
end
