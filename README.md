# RSpec::Puppet::Yaml

This gem enables Puppet module authors to write RSpec unit tests as YAML instead of Ruby (omitting the single, trivial line of code necessary to pass your YAML to RSpec).  If you're more comfortable with YAML than Ruby, or are looking for a way to automate RSpec test generation and find YAML easier to serialize into than RSpec, then you'll want this gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rspec-puppet-yaml'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rspec-puppet-yaml

## Usage

As per the [existing documentation for rspec-puppet](https://github.com/rodjek/rspec-puppet/blob/master/README.md#naming-conventions), you will still create RSpec entry-point files at `your_module/spec/**/*_spec.rb` (else `rake` won't find your tests, YAML or otherwise).  However, these files now need only two lines of Ruby code (usually) and no RSpec code.  You'll still require your `spec_helper` as always, and then just call the global-scope entry-point function to parse your YAML into RSpec.

For example:

```ruby
require 'spec_helper'
parse_yaml_from_spec(__FILE__)
```

Yes, that's it!  You can copy-paste those two lines into every `*_spec.rb` file and then spend your time writing RSpec Puppet tests in YAML rather than Ruby.

To do so, create another file with the same base name as your `*_spec.rb` file except change the extension to `.yaml` or `.yml`.  In fact, you don't even need the `_spec` part of the name, so for an RSpec file named `my_module_spec.rb`, you can use any of these YAML file-names:  `my_module_spec.yaml`, `my_module_spec.yml`, `my_module.yaml`, and `my_module.yml`.  Fair warning:  the parser will look for *all* of these file-names, so if you create more than one of them, they will all be processed, in turn.

### Defining RSpec Puppet YAML Tests

While this gem spares you from needing to learn Ruby just to test your Puppet module, you still need to do a little research into what RSpec tests are available to your YAML.  The good news is [that very knowledge is already documented for the rspec-puppet gem](https://github.com/rodjek/rspec-puppet/blob/master/README.md#matchers) and you just need to know how to translate it into YAML.  While not initially obvious, it is easy.  Users should "get the hang of it" after building their first few tests.

These examples are expanded or direct translations of each of the matcher samples that are shown in the above-linked rspec-puppet README.  Copyright for the original examples is owned by the maintainers of that gem and are duplicated here in good faith that my translations into YAML will benefit our common audience.  This rpsec-puppet-yaml gem extends the reach of the rspec-puppet gem to include users who speak YAML better than Ruby; it does not replace it.

#### Setting custom facts, parameters, titles, and any other `let` setting

Ruby:

```ruby
describe 'my_module' do
  let(:title) { 'baz' }

  let(:params) do
    { 'value'   => 'foo',
      'user'    => :undef,
      'require' => ref('Package', 'sudoku'),
      'nodes'   => {
        ref('Node', 'dbnode') => ref('Myapp::Mycomponent', 'myapp')
      }
    }
  end

  let(:node) { 'testhost.example.com' }

  let(:environment) { 'production' }

  let(:facts) do
    { 'os' => {
        'family'  => 'RedHat',
        'release' => {
          'major' => '7',
          'minor' => '1',
          'full'  => '7.1.1503'
        }
      }
    }
  end

  let(:node_params) do
    { 'hostgroup' => 'webservers',
      'rack'      => 'KK04',
      'status'    => 'maintenance' }
  end

  let(:pre_condition) { 'include other_class' }

  let(:post_condition) { 'include another_class' }

  let(:module_path) { '/path/to/your/module/dir' }

  let(:trusted_facts) do
    { 'pp_uuid' => 'ED803750-E3C7-44F5-BB08-41A04433FE2E',
      '1.3.6.1.4.1.34380.1.2.1' => 'ssl-termination' }
  end
end
```

YAML:

```yaml
describe:
  name: my_module
  let:
    title: baz
    node: testhost.example.com
    environment: production
    params:
      value: foo
      user: !ruby/symbol undef  # The symbol-form of `undef` must be used to specify an :undef value
      require: '%{eval:ref("Package", "my-package")}': # %{eval:...} expands into a command and its arguments which is run via `eval`, capturing its return value.  `'` or `"` demarcation of `%{}` is required only because YAML values are forbidden from starting with a `%`.
      nodes:
        '%{eval:ref("Node", "dbnode")}': '%{eval:ref("Myapp::Mycomponent", "myapp")}'
    facts:
      os:
        family: RedHat
        release:
          major: 7
          minor: 1
          full: 7.1.1503
    node_params:
      hostgroup: webservers
      rack: KK04
      status: maintenance
    pre_condition: include other_class
    post_condition: include another_class
    module_path: /path/to/your/module/dir
    trusted_facts:
      pp_uuid: ED803750-E3C7-44F5-BB08-41A04433FE2E
      '1.3.6.1.4.1.34380.1.2.1': ssl-termination
```

#### The compile matcher

Ruby:

```ruby
# Plain test to ensure the module compiles without error
describe "my_module" {
  it { is_expected.to compile }
}

# Expanded test to ensure it compiles with all dependencies
describe "my_module" {
  it { is_expected.to compile.with_all_deps }
}

# Ensure the module *fails* to compile, issuing an expected error message
describe "my_module" {
  it { is_expected.to compile.and_raise_error(/error message match/) }
}
```

YAML:
```yaml
# Plain test to ensure the module compiles without error
describe:
  name: my_module
  tests:
    compile: {}


# Expanded test to ensure it compiles with all dependencies
# Multiple ways to achieve the same net effect!
describe:
  name: my_module
  tests:
    compile: true  # `with_all_deps` is the default test when the `compile` matcher is given any "truthy" value

describe:
  name: my_module
  tests:
    compile:  # Methods that don't accept arguments can be called from an Array
      - with_all_deps

describe:
  name: my_module
  tests:
    compile:  # Methods that don't accept arguments can be called from a Hash with nil as their value
      with_all_deps: nil


# Ensure the module *fails* to compile, issuing an expected error message.
# Method 1:  Use a Regular Expression to match part of the error message.  Note
# that in this case, you must identify your value as being a Ruby Regular
# Expression data type with the leading `!ruby/regexp` marker.
describe:
  name: my_module
  tests:
    compile:
      and_raise_error: !ruby/regexp /error message match/

# Method 2:  Match the *entire* error message, not just part of it.  This
# employs a normal String value that requires no additional marker.
describe:
  name: my_module
  tests:
    compile:
      and_raise_error: FULL text of the error message to match
```

#### The contain (or create) matcher

Ruby:

```ruby
# Ensure a set of resources exist in the manifest, some with specific attributes
describe "my_module" {
  it { is_expected.to contain_augeas('bleh') }

  it { is_expected.to contain_class('foo') }

  it { is_expected.to contain_foo__bar('baz') }

  it { is_expected.to contain_package('mysql-server').with_ensure('present') }

  it { is_expected.to contain_package('httpd').only_with_ensure('latest') }

  it do
    is_expected.to contain_service('keystone').with(
      'ensure'     => 'running',
      'enable'     => 'true',
      'hasstatus'  => 'true',
      'hasrestart' => 'true'
    )
  end

  it do
    is_expected.to contain_user('luke').only_with(
      'ensure' => 'present',
      'uid'    => '501'
    )
  end

  it { is_expected.to contain_file('/foo/bar').without_mode }

  it { is_expected.to contain_service('keystone_2').without(
    ['restart', 'status']
  )}
}
```

YAML:

```yaml
# Ensure a set of resources exist in the manifest, some with specific attributes
describe:
  name: my_module
  tests:
    contain_augeas:
      bleh: {}
    contain_class:
      foo: {}
    contain_foo__bar:
      baz: {}
    contain_package:
      mysql-server: present  # `with_ensure` is the default test when packages are given any scalar value
      httpd:
        only_with_ensure: latest
    contain_service:
      keystone:
        with:
          ensure: running
          enable: true
          hasstatus: true
          hasrestart: true
      keystone_2:
        without:
          - restart
          - status
    contain_user:
      luke:
        only_with:
          ensure: present
          uid: 501
    contain_file:
      /foo/bar:
        - without_mode
```

##### With stipulated resource relationships

Ruby:

```ruby
describe "my_module" {
  # Ensure the file, foo, has specific relationships with other resources
  it { is_expected.to contain_file('foo').that_requires('File[bar]') }

  it { is_expected.to contain_file('foo').that_comes_before('File[baz]') }

  it { is_expected.to contain_file('foo').that_notifies('File[bim]') }

  it { is_expected.to contain_file('foo').that_subscribes_to('File[bom]') }


  # Ensure the file, bar, has specific relationships with many other resources
  it { is_expected.to contain_file('bar').that_requires(['File[fim]', 'File[fu]']) }

  it { is_expected.to contain_file('bar').that_comes_before(['File[fam]','File[far]']) }

  it { is_expected.to contain_file('bar').that_notifies(['File[fiz]', 'File[faz]']) }

  it { is_expected.to contain_file('bar').that_subscribes_to(['File[fuz]', 'File[fez]']) }

  # Other relationship example
  it { is_expected.to contain_notify('bar').that_comes_before('Notify[foo]') }

  it { is_expected.to contain_notify('foo').that_requires('Notify[bar]') }
}
```

YAML:

```yaml
describe:
  name: my_module
  tests:
    contain_file:
      # Ensure the file, foo, has specific relationships with other resources
      foo:
        that_requires: File[bar]
        that_comes_before: File[baz]
        that_notifies: File[bim]
        that_subscribes_to: File[bom]

      # Ensure the file, bar, has specific relationships with many other resources
      bar:
        that_requires:
          - File[fim]
          - File[fu]
        that_comes_before:
          - File[fam]
          - File[far]
        that_notifies:
          - File[fiz]
          - File[faz]
        that_subscribes_to:
          - File[fuz]
          - File[fez]

    contain_notify:
      bar:
        that_comes_before: Notify[foo]
      foo:
        that_requires: Notify[bar]
```

#### The count matcher

Ruby:

```ruby
# Ensure certain resource counts are true
describe "my_module" {
  it { is_expected.to have_resource_count(2) }

  it { is_expected.to have_class_count(2) }

  it { is_expected.to have_exec_resource_count(1) }

  it { is_expected.to have_logrotate__rule_resource_count(3) }
}
```

YAML:

```yaml
# Ensure certain resource counts are true
describe:
  name: my_module
  tests:
    have_resource_count: 2
    have_class_count: 2
    have_exec_resource_count: 1
    have_logrotate__rule_resource_count: 3
```

#### Type alias matchers

Ruby:

```ruby
describe 'MyModule::Shape' do
  it { is_expected.to allow_value('square') }
  it { is_expected.to allow_values('circle', 'triangle') }
  it { is_expected.not_to allow_value('blue') }
end
```

YAML:

```yaml
describe:
  name: MyModule::Shape
  tests:
    be_valid_type:
      allow_value: square
      allow_values:
          - circle
          - triangle
    '!be_valid_type':  # The leading ! switches is_expected.to to is_expected.not_to
      allow_value: blue
```

#### Function matchers

Ruby:

```ruby
describe 'my_function' {
  it { is_expected.to run.with_params('foo').and_return('bar') }
}

describe 'my_other_function' {
  it { is_expected.to run.with_params('foo', 'bar', ['baz']) }
}
```

YAML:

```yaml
describe:
  'my_function':
    tests:
      run:
        with_params: foo
        and_return: bar
      run:
  'my_other_function':
    tests:
      run:
        with_params:
          - foo
          - bar
          - ['baz']
```

##### Negative tests and error matching

Ruby:

```ruby
describe 'my_function' {
  it { is_expected.not_to run.with_params('a').and_raise_error(Puppet::ParseError) }
}
```

YAML:

```yaml
describe:
  name: my_function
  tests:
    '!run':  # Negate a test with a ! prefix, but `'` or `"` demarcate the matcher name becaus a leading ! in YAML denotes a data-type specification.
      with_params: a
      and_raise_error: !ruby/exception Puppet::ParseError
    run:
```

#### Using `before` and `after`

Ruby:

```ruby
describe 'my_function' {
  before(:each) { scope.expects(:lookupvar).with('some_variable').returns('some_value') }
  it { is_expected.to run.with_params('...').and_return('...') }
}
```

YAML:

YAML indirectly supports executable code in RSpec's `before` and `after` blocks.  It is emulated by first writing a *global* scope function in your `*_spec.rb` file and then calling that function from the YAML file, as shown in these two snippets:

spec/function/my_function_spec.rb
```ruby
require 'spec_helper'

def my_before
  scope.expects(:lookupvar).with('some_variable').returns('some_value')
end

parse_yaml_from_spec(__FILE__)
```

spec/function/my_function_spec.yaml
```yaml
describe:
  name: my_function
  let:
    before: my_before
  tests:
    run:
      with_params: ...
      and_return: ...
```

Note that `let:before:` can specify an Array of global-scope functions to call,
though it may be simpler to just define a global-scope function which calls all
of the other functions you need to chain together.

This technique also helps define custom functions for your tests.

#### Hiera integration

Apart from ensuring that your `metadata.json` file is valid, you just don't need to do anything at all to enable module-level Hiera data integration; it's already built into rspec-puppet and it runs quite well without any additional configuration.  If however, you have a valid use-case for customizing Hiera in order to test out-of-module data -- which should be a really hard sell since you should be testing your Module's code, not any out-of-module Hiera data -- the above documentation should be adequate to express such custom Hiera configuration, whether via `let` settings or custom functions run during `begin`.  Should you find the existing support to be inadequate, feel free to open a qualifying Pull Request that adds whatever additional support you need.

#### Unsupported RSpec Puppet Features

This extension does not support the following features found in rspec-puppet:

1. There is no way to create an example `it` that uses the `expect()` function instead of `is_expected`.
2. With the highest available version of rspec-puppet at the time of this writing, there doesn't seem to be any way to use `subject { exported_resources }` because rspec-puppet throws an error message when you try, even when you follow its advice as to where to place the `subject`.
3. In the Function matcher, lambda are not known to be supported via YAML.  So, the rspec-puppet example showing `run.with_lambda` has no obvious equivalent in rspec-puppet-yaml.  A clever application of the `%{eval:...}` expander might help in some cases, but feel free to experiment and share back if you find a way to make this work.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rspec-puppet-yaml. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RSpec::Puppet::Yaml project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rspec-puppet-yaml/blob/master/CODE_OF_CONDUCT.md).
