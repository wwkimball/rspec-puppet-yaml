# Converts the supplied YAML data into rspec tests.  When this is called from
# a *_spec.rb file from RSpec, testing begins immediately upon parsing.
#
# @param yaml_file [String] Path to a YAML file containing rspec-puppet tests
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
  # Puppet modules).  RSpec docs often show more than one top-level describe,
  # so this function supports the same.
  rspec_file       = caller_locations.select {|e| e.path =~ /.+_spec.rb$/}
    .first
    .path
  default_describe = {
    'name' => __get_eut_name(yaml_file, rspec_file),
    'type' => guess_type_from_path(rspec_file)
  }
  describes        = []
  RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
    'describe',
    test_data,
  ).each { |desc| describes << default_describe.merge(desc)}
  __apply_rspec_puppet_describes(describes, test_data)
end

# Identify the name of the entity under test.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param [String] rspec_yaml_file_name YAML file name that describes tests.
# @param [String] rspec_file_name Name of the *_spec.rb file that is requesting
#  parsed results from `rspec_yaml_file_name`.
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

# Generates an RSpec `describe {}` and its contents.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param apply_attrs [Hash] Definition of the entity and its contents.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
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
    describe(desc_name) do
      __apply_rspec_puppet_content(apply_attrs, parent_data)
    end
  else
    describe(desc_name, :type => desc_type) do
      __apply_rspec_puppet_content(apply_attrs, parent_data)
    end
  end
end

# Generates an RSpec `context {}` and its contents.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param apply_attrs [Hash] Definition of the entity and its contents.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
def __apply_rspec_puppet_context(apply_attrs = {}, parent_data = {})
  context_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    apply_attrs
  )
  context(context_name) do
    __apply_rspec_puppet_content(apply_attrs, parent_data)
  end
end

# An extension for RSpec, variants are contexts that repeat all parent tests
# with specified tweaks to their inputs and expectations.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param apply_attrs [Hash] Definition of the entity and its contents.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
def __apply_rspec_puppet_variant(apply_attrs = {}, parent_data = {})
  variant_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
    'name',
    apply_attrs
  )

  # The deep_merge gem's funtionality unfortunately changes the destination
  # Hash, even when you attempt to store the result to another variable and use
  # the non-bang method call.  This seems like a pretty serious bug, to me,
  # despite the gem's documentation implying that this will happen.  IMHO, the
  # gem's author made a very poor decision in how the bang and non-bang behavior
  # would differ (merely a difference in the default values of its options
  # rather than the Ruby-norm of affecting or not-affecting the calling Object).
  # To workaround this issue and protect the original destination against
  # unwanted change, a deep copy of the destination Hash must be taken and used.
  parent_dup   = Marshal.load(Marshal.dump(parent_data))
  context_data = parent_dup.select do |k,v|
    !['variants', 'before', 'after', 'subject'].include?(k.to_s)
  end.deep_merge!(
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

# Generates a set of RSpec `describe` entities.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param describes [Array[Hash]] Set of entities to generate.  Each element must
#  be a Hash that has a :name or 'name' attribute.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
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

  describes.each do |container|
    __apply_rspec_puppet_describe(container, parent_data)
  end
end

# Generates a set of RSpec `context` entities.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param contexts [Array[Hash]] Set of entities to generate.  Each element must
#  be a Hash that has a :name or 'name' attribute.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
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

  contexts.each do |container|
    __apply_rspec_puppet_context(container, parent_data)
  end
end

# Generates a set of variants of RSpec entities.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param variants [Array[Hash]] Set of entities to generate.  Each element must
#  be a Hash that has a :name or 'name' attribute.
# @param parent_data [Hash] Used for recursion, this is the parent for this
#  entity.
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

# Generates a set of RSpec `it {}` "examples".
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param tests [Hash] Set of examples to build.
def __apply_rspec_puppet_tests(tests = {})
  tests.each do |method, props|
    # props must be split into args and tests based on method
    case method.to_s
    when /^(!)?((contain|create)_.+)$/
      # There can be only one beyond this point, so recurse as necessary
      if 1 < props.keys.count
        props.each { |k,v| __apply_rspec_puppet_tests({method => {k => v}})}
        return  # Avoid processing the first entry twice
      end

      positive_test = $1.nil?
      apply_method  = $2
      args          = [ props.keys.first ]
      calls         = props.values.first
    when /^(!)?(have_.+_count)$/
      positive_test = $1.nil?
      apply_method  = $2
      args          = props
      calls         = {}
    when /^(!)?(compile)$/
      positive_test = $1.nil?
      apply_method  = $2
      args          = []
      calls         = props
    when /^(!)?(run)$/
      positive_test = $1.nil?
      apply_method  = $2
      args          = []
      calls         = props
    when /^(!)?(be_valid_type)$/
      positive_test = $1.nil?
      apply_method  = $2
      args          = []
      calls         = props
    end

    matcher = RSpec::Puppet::MatcherHelpers.get_matcher_for(
      apply_method,
      args,
      calls
    )

    if positive_test
      it { is_expected.to matcher }
    else
      it { is_expected.not_to matcher }
    end
  end
end

# Generates an RSpec `before {}` entity with one or more global-scope method
# calls as its contents.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param commands [Variant[String,Array[String]]] Command or commands to call.
def __apply_rspec_puppet_before(commands)
  if !commands.nil?
    if commands.kind_of?(Array)
      before do
        commands.each { |command| Object.send(command.to_s.to_sym) }
      end
    elsif !commands.is_a?(Hash)
      before { Object.send(commands.to_s.to_sym) }
    else
      raise ArgumentError, "__apply_rspec_puppet_before requires a command String or an Array of commands."
    end
  end
end

# Generates an RSpec `after {}` entity with one or more global-scope method
# calls as its contents.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param commands [Variant[String,Array[String]]] Command or commands to call.
def __apply_rspec_puppet_after(commands)
  if !commands.nil?
    if commands.kind_of?(Array)
      after do
        commands.each { |command| Object.send(command.to_s.to_sym) }
      end
    elsif !commands.is_a?(Hash)
      after { Object.send(commands.to_s.to_sym) }
    else
      raise ArgumentError, "__apply_rspec_puppet_after requires a command String or an Array of commands."
    end
  end
end

# Generates an RSpec `subject {}` entity.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param subject [Any] The subject descriptor.
def __apply_rspec_puppet_subject(subject)
  if !subject.nil?
    subject { subject }
  end
end

# Sets all let variables.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param lets [Hash] The data to scan for let variables
#
# @example As YAML
#  ---
#  let:
#    facts:
#      kernel: Linux
#      os:
#        family: RedHat
#        name: CentOS
#        release:
#          major: 7
#          minor: 1
#    params:
#      require:
#        '%{call("ref")}':
#          - Package
#          - my-package
def __apply_rspec_puppet_lets(lets = {})
  __expand_data_commands(lets).each { |k,v| let(k.to_sym) { v } }
end

# Recursively expands specially-formatted commands with or without arguments to
# them found within serialized data.
#
# @param serialized_data [Any] The data to check for expansion markers and
#  expand them, when present.
# @return [Any] Expanded or original (when there are no expansion markers) data.
def __expand_data_commands(serialized_data)
  return nil if serialized_data.nil?
  if serialized_data.kind_of?(Array)
    expanded_data = []
    serialized_data.each { |let| expanded_data << __expand_data_commands(let) }
  elsif serialized_data.is_a?(Hash)
    expanded_data = {}
    serialized_data.each do |k,v|
      # Peek ahead to identify whether this is an expansion request and whether
      # the expansion requires arguments.
      if v.is_a?(Hash) \
        && 1 == v.keys.length \
        && v.keys[0] =~ /^%{([a-z]+)\(['"]?([a-z][A-Za-z0-9_]*)["']?\)}$/ \
      then
        mechanism = $1
        target    = $2.to_sym
        args      = v.values[0]

        case mechanism
        when /^(call|send|function|fn)$/
          if args.nil?
            value = Object.send(target)
          elsif args.kind_of?(Array)
            value = Object.send(target, *args)
          else args.is_a?(Hash)
            value = Object.send(target, args)
          end
        end
        expanded_data[k] = value
      else
        expanded_data[k] = __expand_data_commands(v)
      end
    end
  else
    expanded_data = serialized_data
  end
  expanded_data
end

# Generates all specified RSpec entities.  This is assumed to be run within a
# valid RSpec container, like `describe` or `context`.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param apply_data [Hash] The entities to generate.
# @param parent_data [Hash] Used for recursion, this is the parent of the
#  receiving entity.
def __apply_rspec_puppet_content(apply_data = {}, parent_data = {})
  __apply_rspec_puppet_subject(
    RSpec::Puppet::Yaml::DataHelpers.get_named_value(
      'subject',
      apply_data
    )
  )
  __apply_rspec_puppet_lets(
    RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
      'let',
      apply_data
    )
  )
  __apply_rspec_puppet_before(
    RSpec::Puppet::Yaml::DataHelpers.get_named_value(
      'before',
      apply_data
    )
  )
  __apply_rspec_puppet_after(
    RSpec::Puppet::Yaml::DataHelpers.get_named_value(
      'after',
      apply_data
    )
  )
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

# Attempts to load the YAML test data and return its data.
#
# @note The __ prefix denotes this as a "private" function.  Do not call this
#  directly.
#
# @param yaml_file [String] Path to the YAML file to load.
# @return [Hash] The data from the YAML file.
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
