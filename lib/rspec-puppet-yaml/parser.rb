# Converts the supplied YAML data into rspec examples.
def parse_rspec_puppet_yaml(yaml_file)
  test_data = __load_rspec_puppet_yaml_data(yaml_file)

  # Apply any top-level lets
  __apply_rspec_puppet_lets(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'let',
      test_data
    )
  )

  # The top-most entity must be a 'describe', which must have both name (which
  # must be identical to the entity-under-test) and type-of-entity (in case the
  # user failed to follow the prescribed directory structure for unit testing
  # Puppet modules).
  rspec_file        = caller_locations.select {|e| e.path =~ /.+_spec.rb$/}
    .first
    .path
  default_describe  = {
    'name' => __get_eut_name(yaml_file, rspec_file),
    'type' => guess_type_from_path(rspec_file)
  }
  all_top_describes = []
  top_describes     = RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
    'describe',
    test_data,
  ).each { |desc| all_top_describes << default_describe.merge(desc)}
  __apply_rspec_puppet_describes(all_top_describes, test_data)
end

# Identify the name of the entity under test.
#
# @param [String] rspec_yaml_file_name YAML file name that describes tests.
# @return [String] Name of the entity under test.
def __get_eut_name(rspec_yaml_file_name, rspec_file_name)
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

def __apply_rspec_puppet_describe(apply_attrs = {}, parent_data = {})
  desc_name  = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    apply_attrs
  )
  desc_type  = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'type',
    apply_attrs
  )
  if desc_type.nil?
    describe(desc_name) { __apply_rspec_puppet_content(apply_attrs, parent_data) }
  else
    describe(desc_name, :type => desc_type) do
      __apply_rspec_puppet_content(apply_attrs, parent_data)
    end
  end
end

def __apply_rspec_puppet_context(apply_attrs = {}, parent_data = {})
  context_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    apply_attrs
  )
  context(context_name) do
    __apply_rspec_puppet_content(apply_attrs, parent_data)
  end
end

def __apply_rspec_puppet_variant(apply_attrs = {}, parent_data = {})
  variant_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    apply_attrs
  )

  # The deep_merge gem's funtionality unfortunately changes the destination
  # Hash, even when you attempt to store the result to another variable and use
  # the non-bang method call.  This seems like a pretty serious bug, to me,
  # despite the gem's documentation clearly stating this will happen.  IMHO, the
  # gem's author made a very poor decision in how the bang and non-bang behavior
  # would differ (merely a difference in the default values of its options
  # rather than the Ruby-norm of affecting or not-affecting the calling Object).
  # To workaround this issue and protect the original destination against
  # unwanted change, a deep copy of the destination Hash must be taken and used.
  parent_dup   = Marshal.load(Marshal.dump(parent_data))
  context_data = parent_dup.select { |k,v| 'variants' != k.to_s }.deep_merge!(
    apply_attrs,
    { :extend_existing_arrays => false,
      :merge_hash_arrays      => true,
      :merge_nil_values       => false,
      :overwrite_arrays       => false,
      :preserve_unmergeables  => false,
      :sort_merged_arrays     => false
    }
  )

  context(variant_name) do
    __apply_rspec_puppet_content(context_data, parent_data)
  end
end

def __apply_rspec_puppet_describes(describes = [], parent_data = {})
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
    raise ArgumentError, "__apply_rspec_puppet_describes requires an Array of Hashes, each with a :name attribute."
  end

  describes.each { |container| __apply_rspec_puppet_describe(container, parent_data) }
end

def __apply_rspec_puppet_contexts(contexts = [], parent_data = {})
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
    raise ArgumentError, "__apply_rspec_puppet_contexts requires an Array of Hashes, each with a :name attribute."
  end

  contexts.each { |container| __apply_rspec_puppet_context(container, parent_data) }
end

def __apply_rspec_puppet_tests(tests = {})
  tests.each do |method, props|
    # props must be split into args and tests based on method
    case method.to_s
    when /^(contain|create)_.+$/
      # There can be only one beyond this point, so recurse as necessary
      if 1 < props.keys.count
        props.each { |k,v| __apply_rspec_puppet_tests({method => {k => v}})}
        return  # Avoid processing the first entry twice
      end

      args = [ props.keys.first ]
      calls = props.values.first
    when /^have_.+_resource_count$/
      args = props
      calls = {}
    when 'compile'
      args = []
      calls = props
    when 'run'
      args = []
      calls = props
    when 'be_valid_type'
      args = []
      calls = props
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
def __apply_rspec_puppet_content(apply_data = {}, parent_data = {})
  __apply_rspec_puppet_subject(
    RSpec::Puppet::Yaml::DataHelpers.get_named_value(
      'subject',
      apply_data,
    )
  )
  __apply_rspec_puppet_lets(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'let',
      apply_data
    )
  )
  # TODO __apply_rspec_puppet_before(apply_data)
  # TODO __apply_rspec_puppet_after(apply_data)
  __apply_rspec_puppet_tests(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'tests',
      apply_data
    )
  )
  __apply_rspec_puppet_describes(
    RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
      'describe',
      apply_data
    ),
    apply_data
  )
  __apply_rspec_puppet_contexts(
    RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
      'context',
      apply_data
    ),
    apply_data
  )
  __apply_rspec_puppet_variants(
    RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
      'variants',
      apply_data
    ),
    apply_data
  )
end

def __apply_rspec_puppet_variants(variants = [], parent_data = {})
  bad_input = false

  # Input must be an Array
  if !variants.kind_of?(Array)
    bad_input = true
  end

  # Every element of the input must be a Hash, each with a :name attribute
  variants.each do |variant|
    if !variant.is_a?(Hash)
      bad_input = true
    elsif !variant.has_key?('name') && !variant.has_key?(:name)
      bad_input = true
    end
  end

  if bad_input
    raise ArgumentError, "__apply_rspec_puppet_variants requires an Array of Hashes, each with a :name attribute."
  end

  variants.each { |variant| __apply_rspec_puppet_variant(variant, parent_data) }
end

def __apply_rspec_puppet_subject(subject)
  if !subject.nil?
    subject { subject }
  end
end

# Sets all let variables.
#
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
def __apply_rspec_puppet_lets(lets = {})
  lets.each { |k,v|
    let(k.to_sym) { v }
  }
end

# Attempts to load the YAML test data.
#
# @raise IOError when the source file is not valid YAML or does not
#  contain a Hash.
def __load_rspec_puppet_yaml_data(yaml_file)
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
