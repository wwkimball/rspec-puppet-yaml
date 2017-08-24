require 'rspec'
require 'rspec-puppet'
require 'rspec-puppet/matcher_helpers'
require 'rspec-puppet-yaml/parser'
require 'yaml'

module RSpec::Puppet
  # Simply creates the necessary YAML parser and runs it against a supplied
  # YAML data file.
  #
  # @since 0.1.0
  def self.parse_yaml(rspec_yaml_file)
    $stdout.puts("INFO:  #{__FILE__} will now parse #{rspec_yaml_file}.")
    parser = RSpec::Puppet::Yaml::Parser.new(rspec_yaml_file)
    parser.parse
  end

  # Identifies a YAML data file based on the name of a *_spec.rb rspec file and
  # passes it to `parse_yaml` to initiate parsing.
  #
  # @since 0.1.0
  def self.parse_yaml_from_spec(rspec_file)
    if rspec_file =~ /^(.+)_spec\.rb$/
      [ "#{$1}_spec.yaml",
        "#{$1}_spec.yml",
        "#{$1}.yml",
        "#{$1}.yml"
      ].each do |yaml_file|
        if File.exist?(yaml_file)
          RSpec::Puppet.parse_yaml(yaml_file)
        end
      end
    elsif rspec_file =~ /^(.+\.ya?ml)$/
      RSpec::Puppet.parse_yaml($1)
    else
      RSpec::Puppet.parse_yaml(rspec_file)
    end
  end
end
