# Gratuitously copied from the following and slamming everything into the global
# scope because I couldn't find a Ruby way to call this function from my own
# code while keeping RSpec happy from a namespaced context.  I tried a Class-
# based approach.  I tried a Module-extend approach.  While I was able to make
# calls to this function from the appropriate scope in either model, doing so
# either broke RSpec's ability to find its own `it` or my `apply_content` (when
# it was either a Class member or Module function).  Why does Ruby make this so
# damn difficult?!  Many ways to do one thing and NONE OF THEM WORK?  I've now
# uterly burned over 30 hours of my life on this problem, so I'm "throwing in
# the towel" and just copying this code.  I'm DONE fighting with Ruby on this
# issue!  It SUCKS to be blocked from using any namespaces but I just can't find
# any other way to move forward at this point...  if YOU (yes, YOU) can refactor
# all this code into proper namespaced modules, FEEL FREE to open a Pull Request
# that that effect.  I'd love to learn how you pull it off!
#
# @author Tim Sharpe
# @license MIT
#
# @summary Attempts to identify the nature of an entity-under-test from the path
#  of the spec file that defines its unit tests.
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
# @param [String] type reference type
# @param [String] title reference title
# @return [RSpec::Puppet::RawString] return a new RawString with the type/title populated correctly
#
# @author Tim Sharpe
# @license MIT
# @see https://github.com/rodjek/rspec-puppet/blob/434653f8a143e047a082019975b66fb2323051eb/lib/rspec-puppet/support.rb#L404-L412
def ref(type, title)
  return RSpec::Puppet::RawString.new("#{type}['#{title}']")
end
