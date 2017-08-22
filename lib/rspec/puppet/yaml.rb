require 'rspec-puppet/yaml/version'
require 'yaml'

module Rspec::Puppet
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

        # Apply any top-level lets
        apply_lets(@test_data)

        # The top-most entity must be a 'describe', which must have both name
        # and type.
        apply_describe(
          Rspec::Puppet::Yaml::DataHelpers.get_named_hash(
            'describe',
            @test_data
          ),
          { 'name' => get_eut_name,
            'type' => get_eut_type }
        )
      end

      private
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

        def apply_describe(apply_attrs = {}, default_attrs = {})
          full_attrs = default_attrs.merge(apply_attrs)
          desc_name  = Rspec::Puppet::Yaml::DataHelpers.get_named_value(
            'name',
            full_attrs
          )
          desc_type  = Rspec::Puppet::Yaml::DataHelpers.get_named_value(
            'type',
            full_attrs
          )
          if desc_type.nil?
            # Probably an inner describe
            describe(desc_name) do
              apply_content(full_attrs)
            end
          else
            # Probably the outer-most describe
            describe(desc_name, :type => desc_type) do
              apply_content(full_attrs)
            end
          end
        end

        def apply_context(apply_attrs = {}, default_attrs = {})
          full_attrs    = default_attrs.merge(apply_attrs)
          context_name  = Rspec::Puppet::Yaml::DataHelpers.get_named_value(
            'name', full_attrs
          )
          context(context_name) do
            apply_content(full_attrs)
          end
        end

        def apply_describes(data = {})
          Rspec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
            'describe',
            data
          ).each { |container| apply_describe(container) }
        end

        def apply_contexts(data = {})
          Rspec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
            'context',
            data
          ).each { |container| apply_context(container) }
        end

        def apply_examples(data = {})
          #  it { is_expected.to matcher }
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
          apply_subject(apply_data)
          apply_lets(apply_data)
          #apply_before(apply_data)
          #apply_after(apply_data)
          apply_examples(apply_data)
          apply_describes(apply_data)
          apply_contexts(apply_data)
          #apply_variants(apply_data)
        end

        def apply_subject(data = {})
          subject = Rspec::Puppet::Yaml::DataHelpers.get_named_value('subject', data)
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
        def apply_lets(data = {})
          Rspec::Puppet::Yaml::DataHelpers.get_named_hash(
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
