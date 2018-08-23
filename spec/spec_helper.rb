ENV['RACK_ENV'] = 'test'

require 'rack/test'
require 'rspec'
require 'dotenv/load'

require File.expand_path '../../app.rb', __FILE__

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = true
  config.order = :random
  config.include Rack::Test::Methods
end
