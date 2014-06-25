require File.expand_path('../lib/opener/webservice/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "opener-webservice"
  spec.version       = Opener::Webservice::VERSION
  spec.authors       = ["development@olery.com"]
  spec.summary       = %q{Basic webservice hooks for the opener toolchain}
  spec.description   = spec.summary

  spec.license = 'Apache 2.0'

  spec.files = Dir.glob([
    'lib/**/*',
    '*.gemspec',
    'README.md',
    'LICENSE.txt'
  ]).select { |file| File.file?(file) }

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"

  spec.add_dependency "sinatra", "~> 1.4.3"
  spec.add_dependency "uuidtools"
  spec.add_dependency "json"
end
