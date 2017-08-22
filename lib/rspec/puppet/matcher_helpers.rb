module Rspec::Puppet
  # A collection of static methods that simplify creating and building rodjek's
  # Rspec::Puppet::*Matchers.
  #
  # @see https://github.com/rodjek/rspec-puppet
  class MatcherHelpers
    # Attempts to create and return an appropriate Rspec::Puppet::*Matcher for a
    # known matching method and its arguments.
    #
    # @param [Enum[String,Symbol]] method A recognizable Rspec::Puppet
    #  matcher; one of: contain_*, create_*, have_*_count, compile, run, or
    #  be_valid_type.
    # @param [Enum[Hash,Array[Any]] args Arguments to pass to the
    #  matcher during construction.
    # @return [Rspec::Puppet::*Matcher] Whicher Rspec::Puppet matcher that knows
    #  how to handle `method`.
    # @raise [NameError] when `method` is unrecognizable.
    def self.get_matcher_for(method, args)
      method_str = method.to_s
      method_sym = method.to_sym

      if method_str =~ /^(contain|create)_.+$/
        matcher = Rspec::Puppet::MatcherHelpers.get_contain_matcher(
          method_sym,
          args
        )
      elsif method_str =~ /^have_.+_count$/
        matcher = Rspec::Puppet::MatcherHelpers.get_count_matcher(
          method_sym,
          args
        )
      elsif 'compile' == method_str
        matcher = Rspec::Puppet::MatcherHelpers.get_compile_matcher(
          method_sym,
          args
        )
      elsif 'run' == method_str
        matcher = Rspec::Puppet::MatcherHelpers.get_function_matcher(
          method_sym,
          args
        )
      elsif 'be_valid_type' == method_str
        matcher = Rspec::Puppet::MatcherHelpers.get_type_matcher(
          method_sym,
          args
        )
      else
        raise NameError "Unknown matcher method:  #{method_str}.  See http://rspec-puppet.com/matchers/ for valid matchers."
      end

      matcher
    end

    def self.get_contain_matcher(method, type, target, tests)
      target_tests = Rspec::Puppet::Yaml::DataHelpers.get_named_value(
        type,
        tests
      )

      matcher
    end

    def self.get_contain_matcher(method, args)
      matcher = RSpec::Puppet::ManifestMatchers::CreateGeneric.new(
        method,
        method.to_s,
        nil
      )

      if args.type_of?(Array)
        args.each { |arg| matcher.send(arg.to_sym) }
      elsif args.is_a?(Hash)
        args.each { |k,v|
          # Special Case:  *_content tests require Regular Expressions.
          if k =~ /^with(out)?_content$/

          matcher.send(k.to_sym, v)
        }
      elsif args.is_a?(String)
        matcher.send(args)
      elsif !args.nil?
        # The user specified _something_ but it isn't a method call.
        raise ArgumentError, "Unknown argument for Contain matcher:  #{args}."
      end

      matcher
    end

    def self.get_count_matcher(method, args)
      RSpec::Puppet::ManifestMatchers::CountGeneric.new(
        nil,
        args,
        method
      )
    end

    def self.get_compile_matcher(method, args)
      matcher = RSpec::Puppet::ManifestMatchers::Compile.new()

      if args.type_of?(Array)
        args.each { |arg| matcher.send(arg.to_sym) }
      elsif args.is_a?(Hash)
        args.each { |k,v| matcher.send(k.to_sym, v) }
      elsif args.is_a?(String)
        matcher.send(args)
      elsif !args.nil?
        # The user specified _something_ but it isn't a method call.
        raise ArgumentError, "Unknown argument for Compile matcher:  #{args}."
      end

      matcher
    end
  end
end
