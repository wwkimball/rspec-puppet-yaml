require 'pp'

# Converts the supplied YAML data into rspec examples.
def parse_rspec_puppet_yaml(yaml_file)
  test_data = load_test_data(yaml_file)
  $stdout.puts("parse_yaml got data:")
  pp test_data

  # Apply any top-level lets
  apply_lets(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'let',
      test_data
    )
  )

  # The top-most entity must be a 'describe', which must have both name
  # and type.
  rspec_file = caller_locations.select {|e| e.path =~ /.+_spec.rb$/}.first.path
  apply_describe(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'describe',
      test_data
    ),
    { 'name' => get_eut_name(yaml_file, rspec_file),
      'type' => :class #guess_type_from_path(rspec_file) # RSpec::Puppet::Yaml::Parser.guess_type_from_path(rspec_file)
    }
  )
end

# Identify the name of the entity under test.
#
# @private
# @param [String] rspec_yaml_file_name YAML file name that describes tests.
# @return [String] Name of the entity under test.
def get_eut_name(rspec_yaml_file_name, rspec_file_name)
  base_yaml   = File.basename(rspec_yaml_file_name)
  base_caller = File.basename(rspec_file_name)

  if base_yaml =~ /^(.+)(_spec)?\.ya?ml$/
    $1.to_s
  elsif base_caller =~ /^(.+)_spec\.rb$/
    $1.to_s
  else
    'unknown'
  end
end

def apply_describe(apply_attrs = {}, default_attrs = {})
  full_attrs = default_attrs.merge(apply_attrs)
  desc_name  = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    full_attrs
  )
  desc_type  = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'type',
    full_attrs
  )
  if desc_type.nil?
    # Probably an inner describe
    describe(desc_name) { apply_content(full_attrs) }
  else
    # Probably the outer-most describe
    describe(desc_name, :type => desc_type) do
      $stdout.puts("describe #{desc_name}:#{desc_type.to_s} {")
      apply_content(full_attrs)
      $stdout.puts("} ## describe #{desc_name}:#{desc_type.to_s}")
    end
  end
end

def apply_context(apply_attrs = {}, default_attrs = {})
  full_attrs   = default_attrs.merge(apply_attrs)
  context_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    full_attrs
  )
  context(context_name) do
    $stdout.puts("context #{context_name} {")
    apply_content(full_attrs)
    $stdout.puts("} ## context #{context_name}")
  end
end

def apply_describes(describes = {})
  describes.each { |container| apply_describe(container) }
end

def apply_contexts(contexts = {})
  contexts.each { |container| apply_context(container) }
end

def apply_tests(tests = {})
  $stdout.puts("apply_tests got data:")
  pp tests
  tests.each do |method, props|
    # props must be split into args and tests based on method
    case method.to_s
    when 'compile'
      args = []
      calls = props
    when /^have_.+_resource_count$/
      args = props
      calls = {}
    end

    $stdout.puts("...split props into:")
    $stdout.puts("......args:")
    pp args
    $stdout.puts("......calls:")
    pp calls

    $stdout.puts("it #{method} {")
    matcher = RSpec::Puppet::MatcherHelpers.get_matcher_for(
      method,
      args,
      calls
    )
    $stdout.puts("Got matcher:")
    pp matcher
    it { is_expected.to matcher }
    $stdout.puts("} ## it #{method}")
  end
end

# Order:
#   1. subject
#   2. let
#   3. before (missing)
#   4. after (missing)
#   5. it examples
#   6. describe
#   7. context
#   8. variants (missing)
def apply_content(apply_data = {})
  $stdout.puts("...applying data:")
  pp apply_data

  apply_subject(
    RSpec::Puppet::Yaml::DataHelpers.get_named_value(
      'subject',
      apply_data
    )
  )
  apply_lets(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'let',
      apply_data
    )
  )
  #apply_before(apply_data)
  #apply_after(apply_data)
  apply_tests(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'tests',
      apply_data
    )
  )
  apply_describes(
    RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
      'describe',
      apply_data
    )
  )
  apply_contexts(
    RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
      'context',
      apply_data
    )
  )
  #apply_variants(apply_data)
end

def apply_subject(subject)
  if !subject.nil?
    subject { subject }
  end
end

# Sets all let variables.
#
# @private
# @param data [Hash] The data to scan for let variables
# @example As YAML
#  ---
#  let:
#    class: my_class
#    node: my-node.my-domain.tld
#    facts:
#      kernel: Linux
#      os:
#        family: RedHat
#        name: CentOS
#        release:
#          major: 7
#          minor: 1
def apply_lets(lets = {})
  $stdout.puts("apply_lets got data:")
  pp lets
  lets.each { |k,v|
    $stdout.puts("let #{k} fucks #{v} in the ass {")
    let(k.to_sym) { v }
    $stdout.puts("} ## let #{k} fucks #{v} in the ass")
  }
end

# Attempts to load the YAML test data.
#
# @private
# @raise IOError when the source file is not valid YAML or does not
#  contain a Hash.
def load_test_data(yaml_file)
  # The test data file must exist
  if !File.exists?(yaml_file)
    raise IOError, "#{yaml_file} does not exit."
  end

  begin
    yaml_data = YAML.load_file(yaml_file)
  rescue Psych::SyntaxError => ex
    raise IOError, "#{yaml_file} contains a YAML syntax error."
  rescue ArgumentError => ex
    raise IOError, "#{yaml_file} contains missing or undefined entities."
  rescue
    raise IOError, "#{yaml_file} could not be read or is not YAML."
  end

  # Must be a populated Hash
  if yaml_data.nil? || !yaml_data.is_a?(Hash)
    yaml_data = nil
    raise IOError, "#{yaml_file} is not a valid YAML Hash data structure."
  elsif yaml_data.empty?
    yaml_data = nil
    raise IOError, "#{yaml_file} contains no legible tests."
  end

  yaml_data
end
