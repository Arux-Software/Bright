# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bright/version'

Gem::Specification.new do |spec|
  spec.name          = "bright"
  spec.version       = Bright::VERSION
  spec.authors       = ["Arux Software"]
  spec.email         = ["hello@arux.software"]
  spec.summary       = "Framework and tools for dealing with Student Information Systems"
  spec.description   = "Bright is a simple Student Information System API abstraction library used in and sponsored by Arux Software. It is written by Stephen Heuer, Steven Novotny, and contributors. The aim of the project is to abstract as many parts as possible away from the user to offer a consistent interface across all supported Student Information System APIs."
  spec.homepage      = "https://github.com/Arux-Software/Bright"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "httpi", "~> 2.1"
  spec.add_runtime_dependency "json", ">= 0"
  spec.add_runtime_dependency "oauth", ">= 0.5.4"
  spec.add_runtime_dependency "parallel", "~> 1.2"

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake", "~> 12.3.3"
end
