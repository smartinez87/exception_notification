class ExceptionNotifier
  class RedmineNotifier
    require 'active_resource'

    attr_accessor :site
    attr_accessor :project_identifier
    attr_accessor :user
    attr_accessor :password

    def initialize(options)
	    site = options.delete(:site)
	    project_identifier = options.delete(:project_identifier)
	    user = options.delete(:user)
	    password = options.delete(:password)

		create_class('Issue', ActiveResource::Base) do
			self.site = site
			self.user = user
			self.password = password
	  		self.format = :xml
		end

		create_class('Project', ActiveResource::Base) do
			self.site = site
			self.user = user
	  		self.password = password
	  		self.format = :xml
		end

		@project = Project.find(:first, :params => { :identifier => project_identifier })
    end

    def exception_notification(exception)
		if active?
			# check if we allready have an exception for this case
			issue = Issue.find(:first, :params => { :subject => exception.message })
			if !issue # if not create new ticket for the exception
				issue = Issue.new(
					:subject => exception.message,
					:project_id => @project.id,
					:description => exception.backtrace
				)
				issue.save
			end
		end
    end

    private

    def active?
      !@project.nil?
    end

    def create_class(class_name, superclass, &block)
		klass = Class.new superclass, &block
		Object.const_set class_name, klass
	end

  end
end
