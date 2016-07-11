require 'action_dispatch'
require 'pp'

module ExceptionNotifier
  class GithubNotifier < BaseNotifier
    attr_accessor :body, :client, :title, :repo

    def initialize(options)
      super
      begin
        @client  = Octokit::Client.new(login: options.delete(:login),
                                       password: options.delete(:password))
        @repo    = options.delete(:repo)
        @prefix  = options.delete(:prefix) || '[Error] '
      end
    end

    def call(exception, options = {})
      @exception = exception
      @env = options[:env]
      @kontroller = @env['action_controller.instance']
      @data = (@env && @env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
      unless @env.nil?
        @request = ActionDispatch::Request.new(@env)
        @request_hash = hash_from_request
        @session = @request.session
        @environment = @request.filtered_env
      end
      @title = compose_title
      @body = compose_body
      issue_options = { title: @title, body: @body }
      send_notice(@exception, options, nil, issue_options) do |_msg, opts|
        @client.create_issue(@repo, opts[:title], opts[:body]) if @client.basic_authenticated?
      end
    end

    private

    def compose_backtrace_section
      return '' if @exception.backtrace.empty?
      out = sub_title('Backtrace')
      out << "<pre>#{@exception.backtrace.join("\n")}</pre>\n"
    end

    def compose_body
      body = compose_header
      if @env.nil?
        body << compose_backtrace_section
      else
        body << compose_request_section
        body << compose_session_section
        body << compose_environment_section
        body << compose_backtrace_section
      end
      body << compose_data_section
    end

    def compose_data_section
      return '' if @data.empty?
      out = sub_title('Data')
      out << "<pre>#{PP.pp(@data, '')}</pre>"
    end

    def compose_environment_section
      out = sub_title('Environment')
      max = @environment.keys.map(&:to_s).max { |a, b| a.length <=> b.length }
      out << "<pre>"
      @environment.keys.map(&:to_s).sort.each do |key|
        out << "* #{"%-*s: %s" % [max.length, key, inspect_object(@environment[key])]}\n"
      end
      out << "</pre>"
    end

    def compose_header
      header = @exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
      header << format(" %s occurred", @exception.class.to_s)
      if @kontroller
        header << format(" in %s#%s",
                         @kontroller.controller_name,
                         @kontroller.action_name)
      end
      header << format(":\n\n")
      header << "<pre>#{@exception.message}\n"
      header << "#{@exception.backtrace.first}</pre>"
    end

    def compose_request_section
      return '' if @request_hash.empty?
      out = sub_title('Request')
      out << "<pre>* URL        : #{@request_hash[:url]}\n"
      out << "* HTTP Method: #{@request_hash[:http_method]}\n"
      out << "* IP address : #{@request_hash[:ip_address]}\n"
      out << "* Parameters : #{@request_hash[:parameters].inspect}\n"
      out << "* Timestamp  : #{@request_hash[:timestamp]}\n"
      out << "* Server     : #{Socket.gethostname}\n"
      if defined?(Rails) && Rails.respond_to?(:root)
        out << "* Rails root : #{Rails.root}\n"
      end
      out << "* Process    : #{$$}</pre>"
    end

    def compose_session_section
      out = sub_title('Session')
      id = if @request.ssl?
             '[FILTERED]'
           else
             rack_session_id = (@request.env["rack.session.options"] and @request.env["rack.session.options"][:id])
             (@request.session['session_id'] || rack_session_id).inspect
           end
      out << format("<pre>* session id: %s\n", id)
      out << "* data     : #{PP.pp(@request.session.to_hash, '')}</pre>"
    end

    def compose_title
      subject = "#{@prefix}"
      if @kontroller
        subject << "#{@kontroller.controller_name}##{@kontroller.action_name}"
      end
      subject << " (#{@exception.class.to_s})"
      subject.length > 120 ? subject[0...120] + "..." : subject
    end

    def hash_from_request
      {
        http_method: @request.method,
        ip_address: @request.remote_ip,
        parameters: @request.filtered_parameters,
        timestamp: Time.current,
        url: @request.original_url
      }
    end

    def inspect_object(object)
      case object
        when Hash, Array
          object.inspect
        else
          object.to_s
      end
    end

    def sub_title(text)
      "\n\n-------------------- #{text} --------------------\n\n"
    end
  end
end
