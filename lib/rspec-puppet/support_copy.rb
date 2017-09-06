# I was *forced* to copy the `guess_type_from_path` and `ref` functions from
# rspec-puppet/support (see the respective `see` references) and then slam
# everything into the global scope because I couldn't find a Ruby way to call
# these two function from my own namespaced code while keeping RSpec happy from
# the namespaced context.  I tried a Class-based approach.  I tried a
# Module-extend approach.  Neither worked well.  While I was able to make calls
# to these rspec-puppet functions from the appropriate scope in either model,
# doing so either broke RSpec's ability to find its own `it` or my namedspaced
# `apply_content` method (Class) or function (Module).  I've now uterly burned
# over 30 hours of my life on this problem, so I'm "throwing in the towel" and
# just copying this code.  I'm DONE fighting with Ruby on this issue!  I'm sorry
# I wasn't smart enough to appease Ruby.  Yes, it SUCKS to be blocked from using
# an OOP model or any namespaces but I just can't find any other way to move
# forward at this point...  if YOU (yes, YOU) can refactor the necessary code
# into proper namespaces, then by all means; PLEASE feel free to open a Pull
# Request that that effect.  I'd love to learn how you pull it off!
module RSpec::Puppet end

# Attempts to identify the nature of an entity-under-test from the path of the
# spec file that defines its unit tests.
#
# License:  MIT
# @author Tim Sharpe
#
# @param path [String] Fully-qualified path to the *_spec.rb file that defines
#  RSpec (Puppet) tests.
# @return [Symbol] Presumed nature of the entity-under-test.
#
# @see https://github.com/rodjek/rspec-puppet/blob/434653f8a143e047a082019975b66fb2323051eb/lib/rspec-puppet/support.rb#L25-L46
def guess_type_from_path(path)
  case path
  when /spec\/defines/
    :define
  when /spec\/classes/
    :class
  when /spec\/functions/
    :function
  when /spec\/hosts/
    :host
  when /spec\/types/
    :type
  when /spec\/type_aliases/
    :type_alias
  when /spec\/provider/
    :provider
  when /spec\/applications/
    :application
  else
    :unknown
  end
end

# Helper to return a resource/node reference, so it gets translated in params to a raw string
# without quotes.
#
# License:  MIT
# @author Tim Sharpe
#
# @param [String] type reference type
# @param [String] title reference title
# @return [RSpec::Puppet::RawString] return a new RawString with the type/title populated correctly
#
# @see https://github.com/rodjek/rspec-puppet/blob/434653f8a143e047a082019975b66fb2323051eb/lib/rspec-puppet/support.rb#L404-L412
def ref(type, title)
  return RSpec::Puppet::RawString.new("#{type}['#{title}']")
end
