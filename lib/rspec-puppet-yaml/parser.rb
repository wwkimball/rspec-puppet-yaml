# Gratuitously copied from the following and slamming everything into the global
# scope because I couldn't find a Ruby way to call this function from my own
# code while keeping RSpec happy.  I tried a Class-based approach.  I tried a
# Module-extend approach.  While I was able to make calls to this function from
# the appropriate scope in either model, doing so either broke RSpec's ability
# to find its own `it` or my `apply_content` (when it was either a Class member
# or Module function).  Why does Ruby make this so damn difficult?!  I've now
# uterly burned over 30 hours of my life on this problem, so I'm "throwing in
# the towel" and just copying this code.  I'm DONE fighting with Ruby on this
# issue!  It SUCKS to be blocked from using any namespaces but I just can't find
# any other way to move forward at this point.
#
# @see https://github.com/rodjek/rspec-puppet/blob/434653f8a143e047a082019975b66fb2323051eb/lib/rspec-puppet/support.rb#L25-L46
def guess_type_from_path(path)
  case path
  when /spec\/defines/
    :define
  when /spec\/classes/
    :class
  when /spec\/functions/
    :function
  when /spec\/hosts/
    :host
  when /spec\/types/
    :type
  when /spec\/type_aliases/
    :type_alias
  when /spec\/provider/
    :provider
  when /spec\/applications/
    :application
  else
    :unknown
  end
end

# Converts the supplied YAML data into rspec examples.
def parse_rspec_puppet_yaml(yaml_file)
  test_data = load_test_data(yaml_file)

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
      'type' => guess_type_from_path(rspec_file)
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
      apply_content(full_attrs)
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
    apply_content(full_attrs)
  end
end

def apply_describes(describes = [])
  bad_input = false

  # Input must be an Array
  if !describes.kind_of?(Array)
    bad_input = true
  end

  # Every element of the input must be a Hash, each with a :name attribute
  describes.each do |container|
    if !container.is_a?(Hash)
      bad_input = true
    elsif !container.has_key?('name') && !container.has_key?(:name)
      bad_input = true
    end
  end

  if bad_input
    raise ArgumentError, "apply_describes requires an Array of Hashes, each with a :name attribute."
  end

  describes.each { |container| apply_describe(container) }
end

def apply_contexts(contexts = [])
  bad_input = false

  # Input must be an Array
  if !contexts.kind_of?(Array)
    bad_input = true
  end

  # Every element of the input must be a Hash, each with a :name attribute
  contexts.each do |container|
    if !container.is_a?(Hash)
      bad_input = true
    elsif !container.has_key?('name') && !container.has_key?(:name)
      bad_input = true
    end
  end

  if bad_input
    raise ArgumentError, "apply_contexts requires an Array of Hashes, each with a :name attribute."
  end

  contexts.each { |container| apply_context(container) }
end

def apply_tests(tests = {})
  tests.each do |method, props|
    # props must be split into args and tests based on method
    case method.to_s
    when 'compile'
      args = []
      calls = props
    when /^have_.+_resource_count$/
      args = props
      calls = {}
    when /^contain_.+$/
      # There can be only one beyond this point, so recurse a necessary
      if 1 < props.keys.count
        props.each { |k,v| apply_tests({method => {k => v}})}
        return  # Avoid processing the first entry twice
      end

      args = [ props.keys.first ]
      calls = props.values.first
    end

    matcher = RSpec::Puppet::MatcherHelpers.get_matcher_for(
      method,
      args,
      calls
    )
    it { is_expected.to matcher }
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
  lets.each { |k,v|
    let(k.to_sym) { v }
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
