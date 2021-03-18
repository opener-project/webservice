require File.expand_path('../lib/opener/webservice/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'opener-webservice'
  spec.version       = Opener::Webservice::VERSION
  spec.authors       = ['development@olery.com']
  spec.summary       = 'Basic webservice hooks for the OpeNER toolchain'
  spec.description   = spec.summary

  spec.license = 'Apache 2.0'

  spec.files = Dir.glob([
    'config/**/*',
    'lib/**/*',
    '*.gemspec',
    'README.md',
    'LICENSE.txt'
  ]).select { |file| File.file?(file) }

  spec.add_dependency 'sinatra', '~> 1.4.3'
  spec.add_dependency 'json'
  spec.add_dependency 'opener-callback-handler', '~> 1.0'
  spec.add_dependency 'httpclient', ['~> 2.0', '>= 2.5.3.3']
  spec.add_dependency 'opener-core', '~> 2.3'
  spec.add_dependency 'puma'
  spec.add_dependency 'slop', '~> 3.0'
  spec.add_dependency 'aws-sdk', '~> 2.0'

  spec.add_dependency 'newrelic_rpm', '~> 3.0'
  spec.add_dependency 'rollbar', '~> 3.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rack-test'
end
