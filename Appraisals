rails_versions = ['~> 4.0.5', '~> 4.1.1', '~> 4.2.0', '~> 5.0.0']

rails_versions.each do |rails_version|
  appraise "rails#{rails_version.slice(/\d+\.\d+/).gsub('.', '_')}" do
    gem 'rails', rails_version
    gem "sqlite3"
  end
end
