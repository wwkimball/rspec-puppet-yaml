# Identifies a YAML data file based on the name of a *_spec.rb rspec file and
# passes it to `parse_rspec_puppet_yaml` to initiate parsing.
#
# @param rspec_file Path to and name of the RSpec *_spec.rb file.  It is easiest
#  to simply pass `__FILE__` to this function from that file.
#
# @example Typical use
#  require 'spec_helper'
#  parse_yaml_from_spec(__FILE__)
#
# @since 0.1.0
def parse_yaml_from_spec(rspec_file)
  if rspec_file =~ /^(.+)_spec\.rb$/
    [ "#{$1}_spec.yaml",
      "#{$1}_spec.yml",
      "#{$1}.yaml",
      "#{$1}.yml"
    ].each do |yaml_file|
      if File.exist?(yaml_file)
        parse_rspec_puppet_yaml(yaml_file)
      end
    end
  elsif rspec_file =~ /^(.+\.ya?ml)$/
    parse_rspec_puppet_yaml($1)
  else
    parse_rspec_puppet_yaml(rspec_file)
  end
end
