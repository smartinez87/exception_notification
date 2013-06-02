module ExceptionNotifier
  class CampfireNotifier

    attr_accessor :subdomain
    attr_accessor :token
    attr_accessor :room

    def initialize(options)
      begin
        subdomain = options.delete(:subdomain)
        room_name = options.delete(:room_name)
        @campfire = Tinder::Campfire.new subdomain, options
        @room     = @campfire.find_room_by_name room_name
      rescue
        @campfire = @room = nil
      end
    end

    def call(exception, options={})
      @room.paste "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'" if active?
    end

    private

    def active?
      !@room.nil?
    end
  end
end
