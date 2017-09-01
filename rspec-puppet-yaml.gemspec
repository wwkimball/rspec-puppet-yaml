# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rspec-puppet-yaml/version"

Gem::Specification.new do |spec|
  spec.name          = "rspec-puppet-yaml"
  spec.version       = RSpec::Puppet::Yaml::VERSION
  spec.authors       = ["William W. Kimball, Jr., MBA, MSIS"]
  spec.email         = ["github-rspec-puppet-yaml@kimballstuff.com"]

  spec.summary       = %q{Enables the use of YAML to specify rspec tests for Puppet projects}
  spec.description   = %q{rspec is effective but quite hard to learn for Puppet authors who don't wish to take up Ruby.  YAML is comparatively easy to pick up and most Puppet authors are necessarily exposed to it.  This extension enables Puppet code authors to define their rspec-puppet tests in YAML instead of Ruby.}
  spec.homepage      = "https://github.com/wwkimball/rspec-puppet-yaml"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "yard", "~> 0.9"

  spec.add_dependency "rspec-puppet", "~> 2.6"
  spec.add_dependency "deep_merge", "~> 1.1"
end
