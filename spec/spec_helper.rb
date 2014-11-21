require 'rspec'
require 'rack/test'

ENV['RACK_ENV'] = ENV['RAILS_ENV'] = ENV['DAEMON_ENV'] = 'test'

ENV['NEWRELIC_AGENT_ENABLED'] = 'false'

require_relative '../lib/opener/webservice'

RSpec.configure do |config|
  config.color = true

  config.include Rack::Test::Methods, :type => :request

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  def app
    return Opener::Webservice::Server
  end
end
