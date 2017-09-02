module RSpec::Puppet
  module Yaml
    # A collection of static methods that help coerce data into simpler (to
    # digest) forms.  This is necessitated primarily because YAML files can be
    # written with either String or Symbol keys for the same value.
    module DataHelpers
      # Takes a Hash, checks it for a name attribute, and ensures that name
      # is a string-named, 'name', attribute.  If the Hash has no identifyable
      # name, an ArgumentError is raised.
      #
      # @param transform_hash [Hash] A Hash that may already have an explicit
      #  name attribute in either string or symbol form, or a Hash with an
      #  implicit name of form `{ 'implicit' => { key... => val... } }`.
      # @return Hash The `transform_hash` with an explicit, string key 'name'
      #  attribute.
      # @raise ArgumentError when `transform_hash` has neither an implicit nor
      #  explicit name.
      def self.make_hash_name_explicit(transform_hash = {})
        raise ArgumentError, "Cannot transform non-Hash data." unless transform_hash.is_a?(Hash)
        transformed_hash = {}
        hash_name        = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
          'name',
          transform_hash
        )

        if hash_name.nil? || hash_name.empty?
          # Could be an implicit name when { 'implicit' => { 'key' => 'val' } }
          if 1 == transform_hash.keys.count
            first_value = transform_hash.values[0]
            if !first_value.nil? && !first_value.is_a?(Hash)
              raise ArgumentError, "Cannot transform implicitly named Hash when its value is neither nil nor a Hash."
            else
              hash_name        = transform_hash.keys.first
              hash_value       = first_value ||= {}
              transformed_hash = hash_value
                .select {|k,v| k != :name}
                .merge({'name' => hash_name})
            end
          else
            # No explicit or implicit name
            raise ArgumentError, "Hash has neither an explicit nor implicit name."
          end
        else
          transformed_hash = transform_hash
            .select {|k,v| k != :name}
            .merge({'name' => hash_name})
        end

        transformed_hash
      end

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
        hashes         = RSpec::Puppet::Yaml::DataHelpers.get_named_value(
          key,
          data,
          {}
        )
        return coerced_hashes if hashes.empty?

        # Supported Cases:
        # 1. [{'this is a name' => {:key => val}}, {'this is also a name' => {:key => val}}]
        # 2. {'this is a name' => {:key => value}, 'this is also a name' => {:key => value}}
        # 3. [{:name => 'the name', :key => value}, {:name => 'another name', :key => value}]
        # 4. {:name => 'the name', :key => value}
        if hashes.kind_of?(Array)
          hashes.each { |hash|
            coerced_hashes << RSpec::Puppet::Yaml::DataHelpers
              .make_hash_name_explicit(hash)
          }
        elsif hashes.is_a?(Hash)
          # Supported Case 2 requires that each Hash attribute be a named Hash
          # when there is no explicit name attribute.
          if hashes.has_key?('name') || hashes.has_key?(:name)
            coerced_hashes << RSpec::Puppet::Yaml::DataHelpers
              .make_hash_name_explicit(hashes)
          else
            hashes.each do |k, v|
              if v.nil?
                coerced_hashes << { 'name' => k }
              elsif !v.is_a?(Hash)
                raise ArgumentError, "#{key} indicates a Hash but at least one of its attributes is neither a Hash nor nil."
              else
                coerced_hashes << v
                  .select {|m, n| m != :name}
                  .merge({'name' => k})
              end
            end
          end
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
