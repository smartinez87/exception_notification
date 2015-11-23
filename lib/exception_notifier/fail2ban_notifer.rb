# This notifier outputs exception details in a log file that you can parse with
# fail2ban to detect possible attacks..
#
# Fail2ban jail configuration (append to /etc/fail2ban/jail.local):
#
#   [rails-app]
#   enabled = true
#   port = http,https
#   filter = rails-app
#   logpath = /path/to/app/log/fail2ban.log
#   bantime = 3600
#   findtime = 600
#   maxretry = 10
#
#
# Fail2ban filter configuration (save in /etc/fail2ban/filters.d/rails-app.conf):
#   [Definition]
#   failregex = : <HOST> :
#   ignoreregex =
#
require 'action_dispatch'

module ExceptionNotifier
  class Fail2banNotifier

    # This notifier only accepts a :logfile option that should point to a valid
    # file that will be used to log exception entries. Point fail2ban to this
    # file
    def initialize(options)
      @default_options = options
      @default_options[:logfile] ||= Rails.root.join('log', 'fail2ban.log')

      # Roll over every 30M, keep 10 files
      @logger ||= Logger.new(@default_options[:logfile], 10, 30*1024*1024)
    end

    def call(exception, options={})
      env = options[:env]
      request = ActionDispatch::Request.new(env)

      # <ip> : <exception class> : <method> <path> -- <params>
      msg = "%s : %s : %s %s -- %s" % [
        request.remote_ip,
        exception.class,
        request.request_method,
        env["PATH_INFO"],
        request.filtered_parameters.inspect
      ]
      @logger.error(msg)
    end
  end
end