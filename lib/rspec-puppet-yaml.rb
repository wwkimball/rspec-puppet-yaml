#require 'rspec'
#require 'rspec-puppet'
require 'rspec-puppet/support'
require 'rspec-puppet/matcher_helpers'
require 'rspec-puppet-yaml/data_helpers'
require 'rspec-puppet-yaml/extenders'
require 'rspec-puppet-yaml/parser'
#require 'puppetlabs_spec_helper/module_spec_helper'
require 'yaml'

extend RSpec::Puppet::Yaml::Parser
extend RSpec::Puppet::Yaml::Extenders
