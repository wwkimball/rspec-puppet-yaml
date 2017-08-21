require 'rspec-puppet/yaml/version'
require 'rspec-puppet/support'
require 'yaml'

module Rspec::Puppet
  # Simply creates the necessary parser and runs it against a supplied YAML data
  # file.
  #
  # @since 0.1.0
  def parse_yaml(rspec_yaml_file)
    parser = Rspec::Puppet::Yaml::Parser.new(rspec_yaml_file)
    parser.parse
  end

  # Adds YAML processing capabilities to Rspec::Puppet for the purpose of
  # defining rspec examples.
  module Yaml
    # Converts YAML-defined rspec tests into examples.
    #
    # @author William W. Kimball, Jr., MBA, MSIS
    # @since 0.1.0
    # @attr_reader [String] rspec_yaml Path to the source YAML data file.
    # @attr_reader [Hash] Contents of `rspec_yaml`.
    class Parser
      attr_reader :rspec_yaml, :test_data

      def initialize(rspec_yaml)
        @rspec_yaml = rspec_yaml
      end

      # Converts the supplied YAML data into rspec examples.
      def parse
        if @test_data.nil?
          load_test_data
        end

        # Initialize any top-level lets
        apply_lets(@test_data)

        # Create the 'describe' asset container
        describe_attrs = get_describe(@test_data)
        describe(
          Rspec::Puppet::Yaml::Parser.get_named_value('name', describe_attrs),
          :type => Rspec::Puppet::Yaml::Parser.get_named_value(
            'type', describe_attrs
          )
        ) do
          apply_lets(describe_attrs)
          apply_examples(describe_attrs)
          apply_contexts(describe_attrs)
        end
      end

      # Attempts to get an immediate child Hash from a parent Hash that is
      # named according to a given key.  The key may be supplied in either
      # String or Symbol form and both are searched for.  When both forms
      # exist in the parent Hash, a shallow merge is attempted, favoring the
      # String form.
      #
      # @summary Gets a named Hash child from a supplied Hash parent.
      # @param [Enum[String,Symbol]] key The name of the child Hash.
      # @param [Optional[Hash]] data The parent Hash.
      # @param [Optional[Hash]] default The result when `key` not found.
      # @return [Hash] The selected child Hash if it exists, else `default`.
      # @raise NameError when the value for `key` is not a Hash.
      def self.get_named_hash(key, data = {}, default = {})
        hash_value = Rspec::Puppet::Yaml::Parser.get_named_value(
          key, data, default
        )
        if !hash_value.is_a(Hash)
          raise NameError, "The value of #{key} is not a Hash."
        end
        hash_value
      end

      # Searches a Hash for a key by both its String and Symbol names.  When
      # both are found, they are merged as long as their values are both Hash
      # (shallow) or Array (unique).  An exception is raised when the values are
      # scalar or of different data types.
      #
      # @summary Gets a named value from a Hash by its String and Symbol names.
      # @param [Enum[String,Symbol]] key The name of the child.
      # @param [Optional[Hash]] data The parent Hash.
      # @param [Optional[Hash]] default The result when `key` not found.
      # @return [Any] The selected value if it exists, else `default`
      # @raise NameError when both String and Symbol forms `key` exist but one
      #  cannot be merged into the other.
      def self.get_named_value(key, data = {}, default = nil)
        return default unless !data.nil? && data.respond_to?(:has_key?)
        str_key     = key.to_s
        sym_key     = key.to_sym
        has_str_key = data.has_key?(str_key)
        has_sym_key = data.has_key?(sym_key)

        if has_str_key && has_sym_key
          str_value = data[str_key]
          sym_value = data[sym_key]
          if str_value.is_a?(Hash) && sym_value.is_a?(Hash)
            begin
              sym_value.merge(str_value)
            rescue
              raise NameError, "Both symbolic and string forms of '#{str_key}' Hash declarations exist but one cannot be merged into the other.  Pick one form or the other or ensure both are Hashes that can be merged."
            end
          elsif str_value.kind_of?(Array) && sym_value.kind_of?(Array)
            str_value | sym_value
          else
            raise NameError, "Both symbolic and string forms of '#{str_key}' scalar declarations exist and they cannot be combined.  Pick one form or the other."
          end
        elsif has_str_key
          data[str_key]
        elsif has_sym_key
          data[sym_key]
        else
          default
        end
      end

      private:
        # Identify the name of the entity under test.
        #
        # @private
        # @param [Hash] describe A Hash of describe {} attributes.
        # @return [String] Name of the entity under test.
        def get_eut_name(describe = {})
          base_yaml   = File.basename(@rspec_yaml)
          base_caller = File.basename(caller_locations.first.path)
          desc_name   =
            if !describe.respond_to?(:has_key?)
              nil
            elsif describe.has_key?(:name)
              describe[:name]
            elsif describe.has_key?('name')
              describe['name']
            else
              nil
            end

          if !desc_name.nil?
            desc_name.to_s
          elsif base_yaml =~ /^(.+)(_spec)?\.ya?ml$/
            $1.to_s
          elsif base_caller =~ /^(.+)_spec\.rb$/
            $1.to_s
          else
            'unknown'
          end
        end

        # Identify the type of the entity under test.
        #
        # @private
        # @param [Hash] describe A Hash of describe {} attributes.
        # @return [Symbol] One of :class, :define, :function, :provider, etc.
        def get_eut_type(describe = {})
          desc_type =
            if describe.has_key?(:type)
              describe[:type]
            elsif describe.has_key?('type')
              describe['type']
            else
              nil
            end

          if !desc_type.nil?
            desc_type.to_sym
          else
            RSpec::Puppet::Support.guess_type_from_path(
              caller_locations.first.path
            )
          end
        end

        # Gets the required top-level 'describe' entity descriptor from the
        # sample data.
        #
        # @private
        # @param data [Hash] The data to scan for a 'describe' element.
        # @return [Hash] The source data, unchanged
        # @example As YAML
        #  ---
        #  describe:
        #    :type: :class   # or type: class (both must be .to_sym)
        #    :name: my_class # or name: my_class
        def NONONOget_describe(data = {})
          default_name = get_eut_name
          default_type = get_eut_type
          default_desc = {
            :name = default_name,
            :type = default_type
          }
          desc = Rspec::Puppet::Yaml::Parser.get_named_hash(
            'describe',
            data,
            default_desc
          )

          # A descriptor is required
          if desc.empty?
            desc = default_desc
          else
            # Ensure name and type are set
            if !desc.has_key?('name') and !desc.has_key?(:name)
              desc['name'] = default_name
            end
            if !desc.has_key?('type') and !desc.has_key?(:type)
              desc['type'] = default_type
            end
          end

          desc
        end

        def apply_contexts(data = {})
          Rspec::Puppet::Yaml::Parser.get_named_hash('context', data)
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
        def apply_lets(data = {})
          Rspec::Puppet::Yaml::Parser.get_named_hash(
            'let',
            data
          ).each { |k,v| let(k.to_sym) { v } }
        end

        # Attempts to load the YAML test data.
        #
        # @private
        # @raise IOError when the source file is not valid YAML or does not
        #  contain a Hash.
        def load_test_data
          # The test data file must exist
          if !File.exists?(@rspec_yaml)
            raise IOError, "#{@rspec_yaml} does not exit."
          end

          begin
            @test_data = YAML.load_file(@rspec_yaml)
          rescue Psych::SyntaxError => ex
            raise IOError, "#{@rspec_yaml} contains a YAML syntax error."
          rescue ArgumentError => ex
            raise IOError, "#{@rspec_yaml} contains missing or undefined entities."
          rescue
            raise IOError, "#{@rspec_yaml} could not be read or is not YAML."
          end

          # Must be a populated Hash
          if @test_data.nil? || !@test_data.is_a?(Hash)
            @test_data = nil
            raise IOError, "#{@rspec_yaml} is not a valid YAML Hash data structure."
          elsif @test_data.empty?
            @test_data = nil
            raise IOError, "#{@rspec_yaml} contains no legible tests."
          end
        end
    end
  end
end
