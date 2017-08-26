module RSpec::Puppet
  module Yaml
    # A collection of static methods that help coerce data into simpler (to
    # digest) forms.  This is necessitated primarily because YAML files can be
    # written with either String or Symbol keys for the same value.
    module DataHelpers
      # Accepts Hashes-of-Hashes -- where each key is the entry's :name and --
      # Arrays-of-Hashes -- where each Hash has a :name element -- returning
      # both forms as an Array-of-Hashes with a guaranteed 'name' element.  Any
      # entry without a :name generates an exception.
      #
      # @summary Condenses a collection of named Hashes into an Array-of-Hashes.
      # @param [Enum[String,Symbol]] key The name of the collection to copy.
      # @param [Optional[Hash]] data The Hash to copy `key` from.
      # @return [Array[Hash]] Array-of-Hashes, each with a 'name' attribute.
      # @raise [ArgumentError] when an element has no name or is not a Hash.
      def self.get_array_of_named_hashes(key, data = {})
        coerced_hashes = []
        hashes = RSpec::Puppet::Yaml::DataHelpers.get_named_hash(key, data, {})
        return coerced_hashes if hashes.empty?  # Do nothing when there is nothing to do

        if hashes.kind_of?(Array)
          hashes.each { |hash|
            if hash.is_a?(Hash)
              hash_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value('name', hash)
              if hash_name.nil?
                raise ArgumentError, "At least one child of #{key} has no name."
              else
                coerced_hashes << hash.merge({'name' => hash_name})
              end
            else
              raise ArgumentError, "At least one child of #{key} is not a Hash value."
            end
          }
        elsif hashes.is_a?(Hash)
          hashes.each { |hash_name, hash|
            # Permit name overrides, but force the String key type
            alt_name = RSpec::Puppet::Yaml::DataHelpers.get_named_value('name', hash)
            if alt_name.nil? || alt_name.empty?
              coerced_hashes << hash.merge({'name' => hash_name})
            else
              coerced_hashes << hash.delete(:name).merge({'name' => alt_name})
            end
          }
        else
          raise ArgumentError, "#{key} is for neither an Array nor a Hash value."
        end

        coerced_hashes
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
        hash_value = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
          key, data, default
        )
        if !hash_value.is_a?(Hash)
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
    end
  end
end
