---
layout: post
title:  "Your first Ruby native extension: C"
date:   2013-08-28 21:59:07
categories: jekyll update
---

# Your first Ruby native extension: C
A few months back I released faye-websocket 0.4, my first gem that contained native code. After a few mis-step releases I got a working build for MRI and JRuby, but getting there was a little tricky. What follows is a quick how-to from someone who knows barely any C or Java, to explain how to wire your code up for release.  

This only covers one possible use case for native code: rewriting a pure function in native code to make it faster. It does not cover binding to native libraries, or FFI, just writing some vanilla C/Java to make some hot code faster. In faye-websocket’s case, this is the function in question:

{% highlight ruby %}
bytes = [72, 101, 108, 108, 111, 44, 32, 119, 111, 114, 108, 100, 33]
mask  = [23, 142, 94, 24]

Faye::WebSocket.mask(bytes, mask)
# => [95, 235, 50, 116, 120, 162, 126, 111, 120, 252, 50, 124, 54]
{% endhighlight %}

It takes an arbitrary list of bytes, and a list of four bytes, and XORs the first set using the second set (this is part of how data is encoded in WebSocket frames). You’d implement it in Ruby like this:

{% highlight ruby %}
def mask(payload, mask)
  result = []
  payload.each_with_index do |byte, i|
    result[i] = byte ^ mask[i % 4]
  end
  result
end
{% endhighlight %}

It turns out Ruby’s quite slow at doing this, and you get a big performance boost by writing in C. Remember that what we want to do is define a singleton method called mask(payload, mask) on the module Faye::WebSocket. I’ll just show you all the code for doing that in C, which we’re going to save in ext/faye_websocket/faye_websocket.c. All I know about the Ruby C APIs I got through Google, and I’ve annotated this code with some useful tips.

{% highlight C %}
// ext/faye_websocket/faye_websocket.c

#include <ruby.h>

// Allocate two VALUE variables to hold the modules we'll create. Ruby values
// are all of type VALUE. Qnil is the C representation of Ruby's nil.
VALUE Faye = Qnil;
VALUE FayeWebSocket = Qnil;

// Declare a couple of functions. The first is initialization code that runs
// when this file is loaded, and the second is the actual business logic we're
// implementing.
void Init_faye_websocket();
VALUE method_faye_websocket_mask(VALUE self, VALUE payload, VALUE mask);

// Initial setup function, takes no arguments and returns nothing. Some API
// notes:
// 
// * rb_define_module() creates and returns a top-level module by name
// 
// * rb_define_module_under() takes a module and a name, and creates a new
//   module within the given one
// 
// * rb_define_singleton_method() take a module, the method name, a reference to
//   a C function, and the method's arity, and exposes the C function as a
//   single method on the given module
// 
void Init_faye_websocket() {
  Faye = rb_define_module("Faye");
  FayeWebSocket = rb_define_module_under(Faye, "WebSocket");
  rb_define_singleton_method(FayeWebSocket, "mask", method_faye_websocket_mask, 2);
}

// The business logic -- this is the function we're exposing to Ruby. It returns
// a Ruby VALUE, and takes three VALUE arguments: the receiver object, and the
// method parameters. Notes on APIs used here:
// 
// * RARRAY_LEN(VALUE) returns the length of a Ruby array object
// * rb_ary_new2(int) creates a new Ruby array with the given length
// * rb_ary_entry(VALUE, int) returns the nth element of a Ruby array
// * NUM2INT converts a Ruby Fixnum object to a C int
// * INT2NUM converts a C int to a Ruby Fixnum object
// * rb_ary_store(VALUE, int, VALUE) sets the nth element of a Ruby array
// 
VALUE method_faye_websocket_mask(VALUE self, VALUE payload, VALUE mask) {
  int n = RARRAY_LEN(payload), i, p, m;
  VALUE unmasked = rb_ary_new2(n);
  
  int mask_array[] = {
    NUM2INT(rb_ary_entry(mask, 0)),
    NUM2INT(rb_ary_entry(mask, 1)),
    NUM2INT(rb_ary_entry(mask, 2)),
    NUM2INT(rb_ary_entry(mask, 3))
  };
  
  for (i = 0; i < n; i++) {
    p = NUM2INT(rb_ary_entry(payload, i));
    m = mask_array[i % 4];
    rb_ary_store(unmasked, i, INT2NUM(p ^ m));
  }
  return unmasked;
}
{% endhighlight %}

Now we’ve got our C code done, we need some glue to compile it and load it from Ruby. I use rake-compiler for this. Your project needs an extconf.rb, in the same directory as the C code:

{% highlight ruby %}
# ext/faye_websocket/extconf.rb

require 'mkmf'
extension_name = 'faye_websocket'
dir_config(extension_name)
create_makefile(extension_name)
{% endhighlight %}

Now let’s make a skeleton gemspec and Rakefile for the project. For a C extension, you ship the source code as part of the gem and it gets compiled on site using the extensions field from the gemspec.

{% highlight ruby %}
# faye-websocket.gemspec

Gem::Specification.new do |s|
  s.name    = "faye-websocket"
  s.version = "0.4.0"
  s.summary = "WebSockets for Ruby"
  s.author  = "James Coglan"
  
  s.files = Dir.glob("ext/**/*.{c,rb}") +  Dir.glob("lib/**/*.rb")
  
  s.extensions << "ext/faye_websocket/extconf.rb"
  
  s.add_development_dependency "rake-compiler"
end
{% endhighlight %}

{% highlight ruby %}
# Rakefile

require 'rake/extensiontask'
spec = Gem::Specification.load('faye-websocket.gemspec')
Rake::ExtensionTask.new('faye_websocket', spec)
{% endhighlight %}

So the project looks like this at this point:

{% highlight ruby %}
ext/
    faye_websocket/
        extconf.rb
        faye_websocket.c
faye-websocket.gemspec
Rakefile

{% endhighlight %}

This is now enough to run rake compile, wherein rake-compiler works its magic. This will create a Makefile, and some *.o and *.so files. You should not check these into git, or ship them as part of the gem – these compilation artifacts are created on install.
{% highlight C %}
$ rake compile
mkdir -p lib
mkdir -p tmp/x86_64-linux/faye_websocket/1.9.3
cd tmp/x86_64-linux/faye_websocket/1.9.3
/home/james/.rbenv/versions/1.9.3-p194/bin/ruby -I. ../../../../ext/faye_websocket/extconf.rb
creating Makefile
cd -
cd tmp/x86_64-linux/faye_websocket/1.9.3
make
compiling ../../../../ext/faye_websocket/faye_websocket.c
linking shared-object faye_websocket.so
cd -
install -c tmp/x86_64-linux/faye_websocket/1.9.3/faye_websocket.so lib/faye_websocket.so

{% endhighlight %}

The file lib/faye_websocket.so is directly loadable from Ruby – let’s try it out:

{% highlight ruby %}

$ irb -r ./lib/faye_websocket
>> Faye::WebSocket.mask [1,2,3,4], [5,6,7,8]
=> [4, 4, 4, 12]

{% endhighlight %}

So the final part of the process is to load this file from our main library code, for example:

{% highlight ruby %}
# lib/faye/websocket.rb

require File.expand_path('../../faye_websocket', __FILE__)

module Faye
  module WebSocket
    # all your Ruby logic
  end
end

{% endhighlight %}

And that’s all there is to it. Just a few points to remember:
  * By convention, rake-compiler expects extensions to be in ext/
  * Make sure the C source and extconf.rb are included in the gemspec
  * Don’t put compilation output in the gem or in source control
  * Remember to recompile between editing C code and running tests

# Thanks
[Your first Ruby native extension: C](http://blog.jcoglan.com/2012/07/29/your-first-ruby-native-extension-c/) by James Coglan.

