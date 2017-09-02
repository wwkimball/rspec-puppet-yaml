require 'spec_helper'

# Common sample data for these tests
sample_data = {
  'string_key'    => 'string_key_value',
  :symbol_key     => 'symbol_key_value',
  'merge_hash'    => { 'key1' => 'value1' },
  :merge_hash     => { 'key2' => 'value2' },
  'merge_array'   => [ 'value1' ],
  :merge_array    => [ 'value2' ],
  'collision_key' => 'scalar_value',
  :collision_key  => 'any_other_scalar_value',
  :gaonh1         => [{'this is a name' => {:key => 'val'}}, {'this is also a name' => {:key => 'val'}}],
  :gaonh2         => {'this is a name' => {:key => 'value'}, 'this is also a name' => {:key => 'value'}},
  :gaonh3         => [{:name => 'the name', :key => 'value'}, {:name => 'another name', :key => 'value'}],
  :gaonh4         => {:name => 'the name', :key => 'value'},
  :gaonh5         => [{'name' => 'explicit name', :key => 'value'}, {'name' => 'explicit name', :key => 'value'}],
  :nonamehash     => {'key1' => 'value', 'key2' => 'value2'},
  :unnamedarray   => [{'key1' => 'value'}, {'key2' => 'value2'}],
  :scalararray    => [1, 2, 3]
}.freeze



RSpec.describe '.get_named_value' do
  it 'should get a named scalar value from a string key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        'string_key',
        sample_data
      )
    ).to eq 'string_key_value'
  end

  it 'should get a named scalar value from a stringified symbol key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :string_key,
        sample_data
      )
    ).to eq 'string_key_value'
  end

  it 'should get a named scalar value from a symbol key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :symbol_key,
        sample_data
      )
    ).to eq 'symbol_key_value'
  end

  it 'should get a named scalar value from a symbolified key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        'symbol_key',
        sample_data
      )
    ).to eq 'symbol_key_value'
  end

  it 'should get a named, merged hash value from a string key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        'merge_hash',
        sample_data
      )
    ).to include({
      'key1' => 'value1',
      'key2' => 'value2'
    })
  end

  it 'should get a named, merged hash value from a symbol key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :merge_hash,
        sample_data
      )
    ).to include({
      'key1' => 'value1',
      'key2' => 'value2'
    })
  end

  it 'should get a named, merged array value from a string key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        'merge_array',
        sample_data
      )
    ).to include('value1', 'value2')
  end

  it 'should get a named, merged array value from a symbol key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :merge_array,
        sample_data
      )
    ).to include('value1', 'value2')
  end

  it 'should return supplied default when string key does not exist' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        'no such key',
        sample_data,
        'default value'
      )
    ).to eq('default value')
  end

  it 'should return supplied default when symbol key does not exist' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :missingkey,
        sample_data,
        'default value'
      )
    ).to eq('default value')
  end

  it 'should raise NameError when string key collides with same-named symbol key for scalar values' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :collision_key,
        sample_data
      )
    }.to raise_error(NameError)
  end

  it 'should raise NameError when symbol key collides with same-named string key for scalar values' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_named_value(
        :collision_key,
        sample_data
      )
    }.to raise_error(NameError)
  end
end



RSpec.describe '.get_named_hash' do
  it 'should get a named, merged hash value from a string key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
        'merge_hash',
        sample_data
      )
    ).to include({
      'key1' => 'value1',
      'key2' => 'value2'
    })
  end

  it 'should get a named, merged hash value from a symbol key' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
        :merge_hash,
        sample_data
      )
    ).to include({
      'key1' => 'value1',
      'key2' => 'value2'
    })
  end

  it 'should raise NameError when string named key is not for a hash value' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
        'string_key',
        sample_data
      )
    }.to raise_error(NameError)
  end

  it 'should raise NameError when symbol named key is not for a hash value' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_named_hash(
        :symbol_key,
        sample_data
      )
    }.to raise_error(NameError)
  end
end



RSpec.describe '.make_hash_name_explicit' do
  it 'should not transform Hash with symbol name key' do
    sample = { :name => 'a name', :key => 'value' }
    expect(
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    ).to include(
      'name' => 'a name',
      :key => 'value'
    )
  end

  it 'should not transform Hash with string name key' do
    sample = { 'name' => 'a name', :key => 'value' }
    expect(
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    ).to include(
      'name' => 'a name',
      :key => 'value'
    )
  end

  it 'should push implicit name key into Hash' do
    sample = { 'a name' => { :key => 'value' } }
    expect(
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    ).to include(
      'name' => 'a name',
      :key => 'value'
    )
  end

  it 'should transform implicity named Hashes that are empty' do
    sample = { 'a name' => {} }
    expect(
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    ).to include(
      'name' => 'a name'
    )
  end

  it 'should transform implicity named Hashes that can be assumed empty' do
    sample = { 'a name' => nil }
    expect(
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    ).to include(
      'name' => 'a name'
    )
  end

  it 'should throw ArgumentError for non-Hash argument' do
    sample = [ { :name => 'a name', :key => 'value' } ]
    expect {
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    }.to raise_error(ArgumentError)
  end

  it 'should throw ArgumentError for Hash with no name' do
    sample = { :notnamed => 'value' }
    expect {
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    }.to raise_error(ArgumentError)
  end

  it 'should throw ArgumentError for malformed Hash' do
    sample = { 'implicit name' => 1 }
    expect {
      RSpec::Puppet::Yaml::DataHelpers.make_hash_name_explicit(sample)
    }.to raise_error(ArgumentError)
  end
end



RSpec.describe '.get_array_of_named_hashes' do
  # Expected cases:
  # 1. [{'this is a name' => {:key => val}}, {'this is also a name' => {:key => val}}]
  # from YAML:
  # - this is a name:
  #     :key: val
  # - this is also a name:
  #     :key: val
  it 'should transform implicitly named hashes in arrays' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :gaonh1,
        sample_data
      )
    ).to include(
      { 'name' => 'this is a name', :key => 'val' },
      { 'name' => 'this is also a name', :key => 'val' }
    )
  end

  # 2. {'this is a name' => {:key => value}, 'this is also a name' => {:key => value}}
  # from YAML:
  # 'this is a name':
  #   :key: value
  # 'this is also a name':
  #   :key: value
  it 'should transform implicitly named hashes in hashes' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :gaonh2,
        sample_data
      )
    ).to include(
      { 'name' => 'this is a name', :key => 'value' },
      { 'name' => 'this is also a name', :key => 'value' }
    )
  end

  # 3. [{:name => 'the name', :key => value}, {:name => 'another name', :key => value}]
  # from YAML:
  # - :name: the name
  #   :key: value
  # - :name: another name
  #   :key: value
  it 'should transform explicitly named hashes in arrays' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :gaonh3,
        sample_data
      )
    ).to include(
      { 'name' => 'the name', :key => 'value' },
      { 'name' => 'another name', :key => 'value' }
    )
  end

  # 4. {:name => 'the name', :key => value}
  # from YAML:
  # :name: the name
  # :key: value
  it 'should transform explicitly named, solitary hashes' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :gaonh4,
        sample_data
      )
    ).to include(
      { 'name' => 'the name', :key => 'value' },
    )
  end

  # Data not needing transformation
  it 'should not transform an array of explicity string-named hashes' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :gaonh5,
        sample_data
      )
    ).to include(
      { 'name' => 'explicit name', :key => 'value' },
      { 'name' => 'explicit name', :key => 'value' }
    )
  end

  #
  # Negative tests
  #

  it 'should return an empty array when key does not exist' do
    expect(
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        'no-such-key',
        sample_data
      )
    ).to include()
  end

  # 1. {'key1' => 'value', 'key2' => 'value2'}
  # from YAML:
  # key1: value
  # key2: value2
  it 'should raise ArgumentError when selected Hash has neither implicit nor explicit name' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :nonamehash,
        sample_data
      )
    }.to raise_error(ArgumentError)
  end

  # 2. [{'key1' => 'value'}, {'key2' => 'value2'}]
  # from YAML:
  # - key1: value
  # - key2: value2
  it 'should raise ArgumentError when selected array has unnamed Hashes' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :unnamedarray,
        sample_data
      )
    }.to raise_error(ArgumentError)
  end

  # 3. [1, 2, 3]
  # from YAML:
  # - 1
  # - 2
  # - 3
  it 'should raise ArgumentError when selected array is not of Hashes' do
    expect {
      RSpec::Puppet::Yaml::DataHelpers.get_array_of_named_hashes(
        :scalararray,
        sample_data
      )
    }.to raise_error(ArgumentError)
  end
end
