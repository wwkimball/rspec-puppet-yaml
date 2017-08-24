module RSpec::Puppet
  # A collection of static methods that simplify creating and building rodjek's
  # RSpec::Puppet::*Matchers.
  #
  # @see https://github.com/rodjek/rspec-puppet
  class MatcherHelpers
    # Attempts to create and return an appropriate RSpec::Puppet::*Matcher for a
    # known matching method and its arguments.
    #
    # @param method [Variant[String,Symbol]] A recognizable RSpec::Puppet
    #  matcher; one of: contain_*, create_*, have_*_count, compile, run, or
    #  be_valid_type (where * is a known resource type).
    # @param args [Array[Any]] Arguments to pass to the matcher during
    #  construction, if it accepts any.
    # @param tests [Optional[Hash[Variant[String,Symbol],Any]]] Set of unit
    #  tests to apply to the matcher, expressed as `:method_call => value(s)`
    #  tuples.  Use `nil` as the value for method_calls that don't accept
    #  arguments.
    # @return [Object] An RSpec::Puppet matcher that knows how to handle
    #  `method` and is loaded with `tests`.
    # @raise [NameError] when `method` is unrecognizable.
    def self.get_matcher_for(method, args, tests = {})
      method_str = method.to_s
      method_sym = method.to_sym

      if method_str =~ /^(contain|create)_.+$/
        matcher = RSpec::Puppet::MatcherHelpers.get_contain_matcher(
          method_sym,
          args,
          tests
        )
      elsif method_str =~ /^have_.+_resource_count$/
        matcher = RSpec::Puppet::MatcherHelpers.get_count_matcher(
          method_sym,
          args,
          tests
        )
      elsif 'compile' == method_str
        matcher = RSpec::Puppet::MatcherHelpers.get_compile_matcher(
          method_sym,
          args,
          tests
        )
      elsif 'run' == method_str
        matcher = RSpec::Puppet::MatcherHelpers.get_function_matcher(
          method_sym,
          args,
          tests
        )
      elsif 'be_valid_type' == method_str
        matcher = RSpec::Puppet::MatcherHelpers.get_type_matcher(
          method_sym,
          args,
          tests
        )
      else
        raise NameError "Unknown matcher method:  #{method_str}.  See http://rspec-puppet.com/matchers/ for valid matchers."
      end

      matcher
    end

    # Gets a matcher for :create_* and :contain_* tests.
    #
    # @param method [Symbol] The full :create_* or :contain_* matcher type.
    # @param args [Array[Any]] Must be at least an Array with one element and
    #  the first element must be the title of the resource under test.  So, for
    #  `package { 'my-package': ensure => 'latest', provider => 'apt' }`, this
    #  must be set to `[ "my-package" ]`.
    # @param tests [Optional[Hash[Variant[String,Symbol],Any]]] Set of unit
    #  tests to apply to the matcher, expressed as `:method_call => value(s)`
    #  tuples.  Use `nil` as the value for method_calls that don't accept
    #  arguments.
    # @raise [ArgumentError] when a resource title is not supplied at args[0].
    #
    # @example package { 'my-package': ensure => 'latest', provider => 'apt' }
    #  # Using the all-in-one `with` test
    #  matcher = RSpec::Puppet::MatcherHelpers.get_contain_matcher(
    #    :contain_package,
    #    [ 'my-package' ],
    #    { :with => {
    #      :ensure   => 'latest',
    #      :provider => 'apt' }
    #    }
    #  )
    #
    #  # Using individual with_* tests
    #  matcher = RSpec::Puppet::MatcherHelpers.get_contain_matcher(
    #    :contain_package,
    #    [ 'my-package' ],
    #    { :with_ensure   => 'latest',
    #      :with_provider => 'apt'
    #    }
    #  )
    def self.get_contain_matcher(method, args, tests = {})
      # For this matcher, args[0] must be a String value that is the title for
      # the resource under test.
      if args.nil? || !args
        raise ArgumentError, "Contain/Create matchers require that the first argument be the title of the resource under test."
      elsif !args.kind_of(Array)
        args = [ args.to_s ]
      end

      matcher = RSpec::Puppet::ManifestMatchers::CreateGeneric.new(
        method,
        args
      )

      # Try to be lenient on the Hash requirement for tests
      if tests.type_of?(Array)
        tests.each { |test| matcher.send(test.to_sym) }
      elsif tests.is_a?(Hash)
        tests.each do |k,v|
          if v.nil?
            matcher.send(k.to_sym)
          else
            matcher.send(k.to_sym, v)
          end
        end
      elsif tests.is_a?(String) || tests.is_a?(Symbol)
        matcher.send(tests)
      elsif !tests.nil?
        # Anything left is assumed to be an 'ensure' test
        matcher.send(:with_ensure, tests)
      end

      matcher
    end

    # Gets a matcher for have_*_resource_count tests.
    #
    # @param method [Symbol] The full :have_*_resource_count matcher type.
    # @param args [Variant[Integer,Array[Integer]]] May be either an Integer or
    #  an Array with exactly one element that is an Integer.  This is the number
    #  of the expected resource counted.
    # @param tests [Optional[Hash[Variant[String,Symbol],Any]]] *IGNORED* in
    #  this version!  Should this matcher ever later support additional tests,
    #  this will become the set of unit tests to apply to the matcher, expressed
    #  as `:method_call => value(s)`` tuples.  Use `nil` as the value for
    #  method_calls that don't accept arguments.
    #
    # @example 1 package expected (count as an Array element)
    #  matcher = RSpec::Puppet::MatcherHelpers.get_count_matcher(
    #    :have_package_resource_count,
    #    [ 1 ]
    #  )
    #
    # @example 12 files expected (count as a bare Integer)
    #  matcher = RSpec::Puppet::MatcherHelpers.get_count_matcher(
    #    :have_file_resource_count,
    #    12
    #  )
    def self.get_count_matcher(method, args, tests = {})
      # This constructor is backward from all the rest and a bit qwirky in that
      # it inexplicably expects method to be an Array and args to be an Integer
      # rather than an Array like all the other matchers.  Further, this one
      # expects to receive method twice, as the first and third parameters or
      # part of method as the first and the whole method as the third or nil as
      # the first and method as the third.  Quite qwirky, indeed!  This helper
      # will steer clear of this qwirkiness by simply passing nil as the first
      # and ensuring that args can be cast as an Integer.
      begin
        if args.type_of(Array)
          # Assume the first element of an args array is the intended count
          count = args[0].to_i
        else
          count = args.to_i
        end
      rescue
        raise ArgumentError, "The argument to Count matchers must be a single Integer value."
      end

      RSpec::Puppet::ManifestMatchers::CountGeneric.new(
        nil,
        count,
        method
      )
    end

    # Gets a matcher for compile tests.
    #
    # @param method [Symbol] The :compile matcher type.
    # @param args [Optional[Variant[Integer,Array[Integer]]]] **IGNORED** in
    #  this version!  Should a future version of the compile matcher support
    #  constructor arguments, this will become useful.
    # @param tests [Optional[Hash[Variant[String,Symbol],Any]]] Set of unit
    #  tests to apply to the matcher, expressed as `:method_call => value(s)`
    #  tuples.  Use `nil` as the value for method_calls that don't accept
    #  arguments.
    #
    # @example The class compiles with all dependencies, spelled out
    #  matcher = RSpec::Puppet::MatcherHelpers.get_compile_matcher(
    #    :compile,
    #    nil,
    #    { :with_all_deps => nil }
    #  )
    #
    # @example The class compiles with all dependencies, simpler
    #  matcher = RSpec::Puppet::MatcherHelpers.get_count_matcher(
    #    :have_file_resource_count,
    #    nil,
    #    true
    #  )
    def self.get_compile_matcher(method, args = [], tests = {})
      matcher = RSpec::Puppet::ManifestMatchers::Compile.new

      if tests.type_of?(Array)
        tests.each { |test| matcher.send(test.to_sym) }
      elsif tests.is_a?(Hash)
        tests.each do |k,v|
          if v.nil?
            matcher.send(k.to_sym)
          else
            matcher.send(k.to_sym, v)
          end
        end
      elsif tests.is_a?(String) || tests.is_a?(Symbol)
        matcher.send(tests)
      elsif !tests.nil?
        # Anything left is assumed to be a 'with_all_deps' test...
        if tests
          # ...as long as it is "truthy"
          matcher.send(:with_all_deps)
        end
      end

      matcher
    end

    # Gets a matcher for function (:run) tests.
    #
    # @param method [Symbol] The :run matcher type.
    # @param args [Optional[Variant[Integer,Array[Integer]]]] **IGNORED** in
    #  this version!  Should a future version of the compile matcher support
    #  constructor arguments, this will become useful.
    # @param tests [Optional[Variant[Symbol,String,Array[Any],Hash[Any,Any]]]]
    #  Set of unit tests to apply to the matcher.  Many forms of expressing
    #  these tests is supported, though the best fit is Array[Any], which is
    #  passed as-is to the function under test as its parameters.
    #
    # @example Test a function that strips known extensions off file-names
    #  matcher = RSpec::Puppet::MatcherHelpers.get_function_matcher(
    #    :run,
    #    nil,
    #    [ '/some/arbitrary/path.ext', 'ext' ]
    #  )
    def self.get_function_matcher(method, args = [], tests = [])
      matcher = RSpec::Puppet::FunctionMatchers::Run.new

      if tests.is_a?(Hash)
        tests.each do |k,v|
          if v.nil?
            matcher.send(k.to_sym)
          else
            matcher.send(k.to_sym, v)
          end
        end
      elsif tests.is_a?(String) || tests.is_a?(Symbol)
        matcher.send(tests)
      elsif !tests.nil?
        # Anything left is assumed to be a 'with_params' test, which expects an
        # Array.
        if tests.type_of(Array)
          matcher.send(:with_params, tests)
        else
          matcher.send(:with_params, [tests])
        end
      end

      matcher
    end

    # Gets a matcher for custom type (:be_valid_type) tests.
    #
    # @param method [Symbol] The :be_valid_type matcher type.
    # @param args [Optional[Variant[Integer,Array[Integer]]]] **IGNORED** in
    #  this version!  Should a future version of the compile matcher support
    #  constructor arguments, this will become useful.
    # @param tests [Optional[Hash[Variant[String,Symbol],Any]]] Set of unit
    #  tests to apply to the matcher, expressed as `:method_call => value(s)`
    #  tuples.  Use `nil` as the value for method_calls that don't accept
    #  arguments.
    #
    # @example With a particular provider (simple)
    #  matcher = RSpec::Puppet::MatcherHelpers.get_type_matcher(
    #    :be_valid_type,
    #    nil,
    #    :apt
    #  )
    #
    # @example With a particular provider (spelled out)
    #  matcher = RSpec::Puppet::MatcherHelpers.get_type_matcher(
    #    :be_valid_type,
    #    nil,
    #    { :with_provider => :apt }
    #  )
    def self.get_type_matcher(method, args = [], tests = {})
      matcher = RSpec::Puppet::ManifestMatchers::CreateGeneric.new(
        method,
        args
      )

      if tests.type_of?(Array)
        tests.each { |test| matcher.send(test.to_sym) }
      elsif tests.is_a?(Hash)
        tests.each do |k,v|
          if v.nil?
            matcher.send(k.to_sym)
          else
            matcher.send(k.to_sym, v)
          end
        end
      elsif !tests.nil?
        # Anything left is assumed to be a 'with_provider' test
        matcher.send(:with_provider, tests)
      end

      matcher
    end
  end
end
