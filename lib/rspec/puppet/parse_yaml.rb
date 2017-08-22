module Rspec::Puppet
  # Simply creates the necessary YAML parser and runs it against a supplied
  # YAML data file.
  #
  # @since 0.1.0
  def parse_yaml(rspec_yaml_file)
    parser = Rspec::Puppet::Yaml::Parser.new(rspec_yaml_file)
    parser.parse
  end
end
