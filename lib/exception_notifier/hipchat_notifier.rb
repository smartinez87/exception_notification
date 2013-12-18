module ExceptionNotifier
  class HipchatNotifier

    attr_accessor :from
    attr_accessor :room
    attr_accessor :message_options

    def initialize(options)
      begin
        api_token				  = options.delete(:api_token)
        room_name 			  = options.delete(:room_name)
        api_version = options.delete(:api_version) || 'v1'
        @from             = options.delete(:from) || 'Exception'
        @room     			  = hipchat_client(api_token, api_version)[room_name]
        @message_options  = options
        @message_options[:color] ||= 'red'
      rescue
        @room = nil
      end
    end

    def call(exception, options={})
      return if !active?

      message = "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'"
      @room.send(@from, message, @message_options)
    end

    private

    def active?
      !@room.nil?
    end

    def hipchat_client(api_token, api_version)
      if api_version.eql?('v2')
        HipChat::Client.new(api_token, :api_version => api_version)
      else
        HipChat::Client.new(api_token)
      end
    end

  end
end
