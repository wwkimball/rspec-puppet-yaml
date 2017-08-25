require 'rspec'
require 'rspec-puppet'
require 'rspec-puppet/support'
require 'rspec-puppet/matcher_helpers'
require 'rspec-puppet-yaml/data_helpers'
require 'rspec-puppet-yaml/parser'
require 'puppetlabs_spec_helper/module_spec_helper'
require 'yaml'

module RSpec::Puppet
  # Simply creates the necessary YAML parser and runs it against a supplied
  # YAML data file.
  #
  # @since 0.1.0
  def self.parse_yaml(rspec_yaml_file)
    $stdout.puts("INFO:  #{__FILE__} will now parse #{rspec_yaml_file}.")
    $stdout.flush
    RSpec::Puppet::Yaml.parse_yaml(rspec_yaml_file)
  end

  # Identifies a YAML data file based on the name of a *_spec.rb rspec file and
  # passes it to `parse_yaml` to initiate parsing.
  #
  # @since 0.1.0
  def self.parse_yaml_from_spec(rspec_file)
    if rspec_file =~ /^(.+)_spec\.rb$/
      $stdout.puts("DEBUG:  #{__FILE__} received a Ruby file, #{$1}.")
      $stdout.flush
      [ "#{$1}_spec.yaml",
        "#{$1}_spec.yml",
        "#{$1}.yaml",
        "#{$1}.yml"
      ].each do |yaml_file|
        $stdout.puts("DEBUG:  #{__FILE__} is checking for a YAML file named, #{yaml_file}.")
        $stdout.flush
        if File.exist?(yaml_file)
          RSpec::Puppet.parse_yaml(yaml_file)
        end
      end
    elsif rspec_file =~ /^(.+\.ya?ml)$/
      $stdout.puts("DEBUG:  #{__FILE__} received a YAML file, #{$1}.")
      $stdout.flush
      RSpec::Puppet.parse_yaml($1)
    else
      $stdout.puts("DEBUG:  #{__FILE__} received an unknown type of file, #{$1}.")
      $stdout.flush
      RSpec::Puppet.parse_yaml(rspec_file)
    end
  end
end
