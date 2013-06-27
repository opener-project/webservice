# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'opener/webservice/version'

Gem::Specification.new do |spec|
  spec.name          = "opener-webservice"
  spec.version       = Opener::Webservice::VERSION
  spec.authors       = ["development@olery.com"]
  spec.summary       = %q{Basic webservice hooks for the opener toolchain}
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "sinatra", "~> 1.4.3"
end
