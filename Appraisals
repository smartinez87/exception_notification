rails_versions = ['~> 4.0.5', '~> 4.1.1', '~> 4.2.0', '~> 5.0.0.beta3']

rails_versions.each do |rails_version|
  appraise "rails#{rails_version.slice(/\d+\.\d+/).gsub('.', '_')}" do
    gem 'rails', rails_version
  end
end

appraise "rails_edge" do
  gem 'rails', github: 'rails/rails'
  gem 'rack', '~> 2.x', github: 'rack/rack'
end
