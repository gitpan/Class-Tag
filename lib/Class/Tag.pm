package Class::Tag;

#use 5.006; 

use strict qw[vars subs];
$Class::Tag::VERSION = '0.10';  

=head1 NAME

Class::Tag - programmatically label (mark) classes, methods, roles and modules with meta-data tags (key/value pairs) and query those tags

=head1 Warning

Any specific interface that Class::Tag exposes may change (as it already did) until version 1.0 is reached. 

=head1 SYNOPSIS 

	{
		package Foo;
		use Class::Tag 'tagged'; # tagging Foo class with 'tagged' tag
	}

	# query 'tagged' tag on the Foo and Bar...
	Class::Tag->tagged('Foo'); # true
	Class::Tag->tagged('Bar'); # false

	{
		package Bar;
		use Class::Tag { class => 'is cool', author => 'metadoo' }; 
	}

	Class::Tag->class( 'Bar') eq 'is cool'; # true
	Class::Tag->author('Bar') eq 'metadoo'; # true

See DESCRIPTION for more options.

=head1 DESCRIPTION

Sometimes it is necessary to programmatically tag modules and classes with some meta-data tags (arbitrary labels or key/value pairs) to be able to assert that you deal with proper classes (modules), methods and roles. Such need typically arises for plug-in modules, application component modules, complex class inheritance hierarchies, etc. 

Class::Tag allows programmatically label (mark) classes and modules with arbitrary inheritable tags (key/value pairs) without collision with methods/attributes/functions of the class/module and query those tags on arbitrary classes and modules.

The syntax of Class::Tag usage is an interaction of B<tag>, B<tagger> (class) and B<target> (class): tagger applies tag to a target class. Names of tagger class (except Class::Tag itself) and tag can be chosen almost freely (with usual restrictions) to be read together as (subject and predicate in a) self-explanatory English sentence, with question semantics (e.g. in conditionals) optionally toggled by direct/indirect method call notation. The following synopsis illustrates.

Directly using Class::Tag as tagger: 

	{
		package   Foo;
		use Class::Tag 'tagged'; # tagging Foo class with 'tagged' tag
		tag Class::Tag 'tagged'; # same, but at run-time
	}

	# query 'tagged' tag on the Foo and Bar...
	Class::Tag->tagged('Foo'); # true
	Class::Tag->tagged('Bar'); # false

Tag can be removed completely from within the scope of the same package Foo:

	{
		package   Foo;
		# remove 'tagged' tag from Foo...
		#no   Class::Tag 'tagged'; # at compile-time, so will not work - instead...
		untag Class::Tag 'tagged'; # at run-time
		Class::Tag->tagged('Foo'); # false
	}

However, since tagged() is now the read-write accessor for tag value, it may be easier to alter tag's value instead:

	Class::Tag->tagged('Foo' => 0);
	Class::Tag->tagged('Foo'); # false

If no tags are given, the 'is' tag is assumed:

	package Foo;
	use Class::Tag;      # equivalent to...
	use Class::Tag 'is'; # same
	use Class::Tag ();   # no tagging

New tagger class can be created by simply tagging package with special 'tagger_class' tag using either Class::Tag or any other tagger class, and then declaring specific tags to be used with that new tagger class. Declaration of specific tag is done by new tagger class applying this tag to itself. Declaring special 'AUTOLOAD' tag this way effectively declares that any tag can be used with new tagger class:

	{
		# this block can be used as "inline" tagger class definition
		# or contents of this block can be loaded from Awesome.pm

		package Awesome;                # new tagger class
		use  Class::Tag 'tagger_class'; # must be before following declarations
		use     Awesome 'specific_tag'; # declares 'specific_tag' for use
		use     Awesome 'AUTOLOAD';     # declares that any tag can be used

		1;
	}

	Class::Tag->tagger_class('Awesome'); # true

Note that Awesome class is not required to be loaded from .pm file with use() or require(), it can be simply defined as above at any point in the code prior to using it as tagger class. Such tagger class definition is referred to as "inline" tagger class.

The Class::Tag itself is somewhat similar to the following implicit declaration:

	package Class::Tag; 
	use     Class::Tag 'tagger_class';
	use     Class::Tag 'AUTOLOAD';

Attempt to use tag that has not been declared (assuming 'AUTOLOAD' declares any tag) raises exception. Values of declaration tags can be used to modify behavior of tags - see L</"Declaration of tags"> section for details.

Any tagger class can be used as follows (in all following examples the original Class::Tag and Awesome tagger classes are interchangeable), assuming tags have been declared: 

Using default 'is' tag: 

	{
		package Foo;
		use Awesome;
		use Awesome  'is';       # same
		use Awesome { is => 1 }; # same
	}

	is Awesome  'Foo';  # true
	is Awesome  'Bar';  # false

	Awesome->is('Foo'); # true
	Awesome->is('Bar'); # false

	$obj = bless {}, 'Foo';

	is Awesome  $obj;  # true
	Awesome->is($obj); # true

	$obj = bless {}, 'Bar';

	is Awesome  $obj;  # false
	Awesome->is($obj); # false

Using tags 'class' and 'pureperl': 

	{
		package Foo; 
		# tag class Foo with tags 'class' and 'pureperl' of Awesome tagger class...
		use Awesome  'class';
		use Awesome              'pureperl';
		use Awesome  'class',    'pureperl';       # same
		use Awesome { class => 1, pureperl => 1 }; # same
	}

	Awesome->class(   'Foo'); # true
	Awesome->pureperl('Foo'); # true
	Awesome->class(   'Bar'); # false
	Awesome->pureperl('Bar'); # false

Using key/value pairs as tags (tag values) and using read-write tag accessors:

	{
		package Foo;
		use Awesome { class => 'is cool', author => 'metadoo' }; 
	}

	Awesome->author('Foo')                    eq 'metadoo'  ;     # true
	Awesome->class( 'Foo')                    eq 'is cool'  ;     # true
	Awesome->class( 'Foo'  => 'pupe-perl')    eq 'pupe-perl';     # true
	Awesome->class( 'Foo')                    eq 'pupe-perl';     # true

	$foo = bless {}, 'Foo';

	Awesome->class( $foo) eq 'is cool'; # true
	Awesome->author($foo) eq 'metadoo'; # true (inheriting)

	Awesome->class( $foo)                     eq 'pupe-perl';     # true (inheriting)
	Awesome->class( $foo  => 'pupe-perl too') eq 'pupe-perl too'; # true (copy-on-write)
	Awesome->class( $foo)                     eq 'pupe-perl too'; # true (copy-on-write)
	Awesome->class( 'Foo')                    eq 'pupe-perl';     # true (unmodified)	

In other words, tag values can be modified with samename accessors. Object instances from the class inherit tags from the class, so that modifying tag value on instance modifies that of a class and vice versa, except blessed-hash objects get their own, instance-specific values when modifying tag value on instance - copy-on-write approach.

Inheriting tags, using for example the default 'is' tag:

	{
		package Foo;
		use Awesome;
		use Awesome 'is'; # same
	}

	@Bar::ISA = 'Foo';

	Awesome->is('Foo'); # true
	Awesome->is('Bar'); # true ('is' tag inherited)
	Awesome::is('Foo'); # true
	Awesome::is('Bar'); # false (no tag inheritance)

By design, Class::Tag is a generalized framework for managing meta information (tags) about inheritable behaviors. Inheritable behaviors that can have meta-data tags attached include methods, classes, roles, etc. Tags are by necessity inheritable, as they need to be inherited together with behaviors they are supposed to describe.

Simple example of the meta-data tag is a class name, with tag's (boolean) value returned by isa(). Another simple example of meta-data tag is a method name, with its value returned by can(). Yet another meta-data tag example is a role name, with tag's value supposed to be returned by DOES(). But classes, methods and roles may also have other meta-data tags apart from their names. In particular, Class::Tag can easily be used to implement method attributes and even multiple "layers" of method attributes, for example:

	package Zoo;

	sub       foo    { 1 }
	use Meta  foo => { is => 'ro', returns => 'boolean' };              # 1-st "meta-layer"
	use Meta2 foo => { author => 'metadoo', doc => 'is dead-simple' };  # 2-nd "meta-layer"

Such use opens possibilities for meta-programming and introspection. For example, method can access its own meta-data as follows:

	sub foo { Meta->foo( ref($_[0])||$_[0] ) }
	sub foo { Meta->foo(     $_[0]         ) } # nearly (but not exactly) same

Technically, Class::Tag is the constructor for special variety of class/object attributes that are orthogonal to (isolated from) conventional attributes/methods of the class. Being the same and being orthogonal at the same time is what required to be good carrier of meta information about inheritable behavior. And use of tagger classes is a way to extend and partition class's namespace into meaningful orthogonal domains, as well as to extend the notion of the meta-data tag in the domain-specific way.

=head1 Tagger classes

Class::Tag itself serves as tagger class, and each tagger class is a "constructor" for other tagger classes, either loadable or inlined.

The use() of tagger class looks as if it exports chosen named tags into packages, but in fact it doesn't - tagger class itself provides samename accessor methods for those tags. As a result, tag names can be arbitrary without risk of collision, so that together with name of tagger class they can be selected to read somewhat meaningful (see examples in L</"SYNOPSIS">) in the problem area domain that uses that specific tagger.

=head2 Tagger class construction

See L</"SYNOPSIS"> for description of new tagger class creation. Tagger class can be created "inline", without using separate .pm file for it.

The value of 'tagger_class' tag is reserved for special use in the future, so it should not be used for anything to avoid incompatibility with future versions.

=head2 Tagger class benefits

There are a few reasons to use multiple tagger classes in addition to or instead of Class::Tag itself:

=over

=item Name

Name of the tagger class can be chosen to read naturally and meaningful, in either direct or indirect method call notations i.e. reversing order of tagger and tag names (doubling readability options), with semantically meaningful tags used in the context of given application or problem area domain.

=item Restricted tagspace

The original Class::Tag tagger class allows to use any tag, except tag(), untag() and Perl's specials, like import(), can(), etc. are still reserved. In contrast, custom tagger classes may allow only specific tags to be used.

=item Isolated (orthogonal) tagspace

Each tagger class has its own orthogonal tags namespace (tagspace), so that same tags of different tagger classes do not collide:

	{
		package Awesome;
		use  Class::Tag 'tagger_class';
		use     Awesome 'AUTOLOAD';

		package     Bad; 
		use  Class::Tag 'tagger_class';
		use         Bad 'AUTOLOAD';

		package Foo;
		use     Awesome 'really';
		use     Awesome { orthogonal => 'awesome' }; 
		use         Bad { orthogonal => 'bad' };
	}

	really  Awesome 'Foo';                           # true
	really      Bad 'Foo';                           # false
	            Bad->orthogonal('Foo') eq 'bad';     # true
	        Awesome->orthogonal('Foo') eq 'awesome'; # true

Without other tagger classes the tags namespace of Class::Tag would be exposed to higher risk of tags collision, since due to global nature of Perl classes there is always a possibility of collision when same tag is used for unrelated purposes (e.g. in the same inheritance chain, etc.).

Since tagger class tags upon use() and classes usually do not export anything, it is often useful and possible to make some existing class a tagger to tag classes that use() it. Moreover, it can be done from a distance, without cognizance of the existing class. The same also applies to modules that are not classes.

However, making existing (non-empty) class/module a tagger class requires care to not collide with methods of that class - Class::Tag will raise an exception when such collision happens. It is better not to declare 'AUTOLOAD' for such tagger class.

=item Meta-data domains

Tags of different tagger classes are intended to be dedicated to defining, managing and documenting different meta-data domains. It can be meta-data associated with specific module, application, problem, algorithm, etc. In particular, tagger class is an ideal place where to document its tags.

=back

=head2 Declaration of tags

Attempt to use tag that has not been declared (assuming 'AUTOLOAD' declares any tag) raises exception. 

In addition, values of declaration tags can be used to modify behavior of tags and, thus, redefine/evolve the whole notion of the tag. If tag is declared with subroutine reference value, that subroutine is called when tag is accessed:

	{
		package Awesome;                             # new tagger class
		use  Class::Tag 'tagger_class';              # must be before following declarations
		use     Awesome  specific_tag => \&accessor; # use \&accessor for 'specific_tag' 
		use     Awesome  AUTOLOAD     => \&ACCESSOR; # use \&ACCESSOR for any tag
	}

	Awesome->specific_tag( $class_or_obj, @args); # is equivalent to...
	&accessor('Awesome',   $class_or_obj, @args); 

	Awesome::specific_tag( $class_or_obj, @args); # is equivalent to...
	&accessor( undef,      $class_or_obj, @args); 

	Awesome->any_other_tag($class_or_obj, @args); # is equivalent to...
	&ACCESSOR('Awesome',   $class_or_obj, @args); 

	Awesome::any_other_tag($class_or_obj, @args); # is equivalent to...
	&ACCESSOR( undef,      $class_or_obj, @args); 

The Awesome class in above code may also be replaced with object of Awesome class. With custom accessors as above the entire tag syntax can be used for something different.

=head1 Traditional alternatives

There are three natural alternative solutions: classes-as-tags, roles-as-tags and methods-as-tags. The classes-as-tags solution uses universal isa() method to see if class has specific parent, it effectively uses specific parent classes as tags. However, using parent classes just as tags is a limited solution since @ISA is used for different things and better be used for those things exclusively to avoid interferences. 

Using roles as tags do not involve modifying @ISA, but this approach relies on using single shared congested namespace, which means possibility of accidental collision, unless you specifically choose unnatural names (long, prefixed, capitalized, etc.) that are unlikely to collide or use unique names of existing modules as tags, which is an overkill in many cases.

Moreover, classes-as-tags and roles-as-tags solutions do not allow using values for tags (unless properly overridden). 

Using methods-as-tags approach is about defining and using specific methods as tags. This approach is far better than classes-as-tags and roles-as-tags, but if specific method-tag need to be queried on unknown class/module, the following problems may arise: 

=over

=item Name collision

It may be that class/module have defined samename method/attribute by coincidence. Possibility of collision is considerable for short readable names (like 'is'), especially for undocumented tags that are used internally and in case of subclassing. To avoid collision method-tags usually have some unique prefix and may be in upper-case and/or starting with '_', etc. The typical solution is using name of some module as unique suffix/prefix, and this is exactly what Class::Tag does in its own flexible way:

	Foo->is_Awesome;

	Awesome->is('Foo');

Class::Tag allows to either dedicate specific tagger class, either loadable or inlined, just to serve as effective "prefix" with arbitrary risk-free tag names, or use some existing class/module as tagger.

=item AUTOLOAD()ing of methods and non-tagged classes/modules

If one tries to check tag on non-tagged class/module, there will be no tag method, so call of tag method will raise an exception. This suggests can() or eval{} wrap to be always used as a precaution.

Moreover, potential use of AUTOLOAD defeats unique prefixes in tag method names and requires always calling tag method conditional on result of prior can() (eval{} will not help in this case) checking if tag is defined:

	$tag_value = $class->is 
	if      $class->can('is');

	Awesome->is($class);

Class::Tag solve this problem.

=item Tagging

Tagging is essentially defining an attribute. Applying read-only tag to class is simple enough, but applying writable tag or  applying tag to blessed-hash objects either ends up in writing accessor or requires use of some attributes construction module, of which Class::Tag is essentially the one:

	{
		package Foo;
		my $writable = 'variable';
		sub writable { @_ > 1 ?        $writable  = $_[1] :        $writable  }
		sub instance { @_ > 1 ? $_[0]->{instance} = $_[1] : $_[0]->{instance} }
	}

	{
		package Foo;
		use Class::Tag writable => 'variable', instance => undef;
	}

	bless $obj = {}, 'Foo';
	Class::Tag->writable('Foo') eq 'variable';
	Class::Tag->writable('Foo'  => 'new value');
	Class::Tag->writable('Foo') eq 'new value';
	Class::Tag->instance($foo   => 'init value');
	Class::Tag->instance('Foo') eq 'init value';

except Class::Tag's default accessor implements copy-on-write tag values on blessed-hash object instances (and simple tag inheritance from class for blessed-non-hashes), rather than simplistic accessor in above alternative.

=back

Class::Tag solves these problems by moving tag constructors and accessors to tagger class, which is far more predictable and controlled environment.

=head1 SEE ALSO

The Class::DOES module provide the ability to use DOES() for tagging classes with role names - see discussion in L</"Traditional alternatives">.

=head1 SUPPORT

Send bug reports, patches, ideas, suggestions, feature requests or any module-related information to L<mailto:parsels@mail.ru>. They are welcome and each carefully considered.

In particular, if you find certain portions of this documentation either unclear, complicated or incomplete, please let me know, so that I can try to make it better. 

If you have examples of a neat usage of Class::Tag, drop a line too.

=head1 AUTHOR

Alexandr Kononoff (L<mailto:parsels@mail.ru>)

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010 Alexandr Kononoff (L<mailto:parsels@mail.ru>). All rights reserved.

This program is free software; you can use, redistribute and/or modify it either under the same terms as Perl itself or, at your discretion, under following Simplified (2-clause) BSD License terms:

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

no warnings;  

use Carp;
use Scalar::Util qw(blessed);

sub NAMESPACE () { 'aixfHgvpm7hgVziaO' }

sub _tagged_accessor { _subnames( join '_', $_[0], NAMESPACE, $_[1] ) }

sub _subnames { my $a; ($a = $_[0]) =~ s/:/_/g; return $a }

*unimport = *untag = __PACKAGE__->new_import('unimport');
  *import =   *tag = __PACKAGE__->new_import();
   import          { __PACKAGE__ } 'AUTOLOAD';

sub new_import {
	my (undef, $unimport) = @_;

	return sub{
		my $self         = shift;
		my $tagger_class = ref($self)||$self;
		my $tagged_class = 
		$Class::Tag::caller||caller;
		$Class::Tag::caller = undef;

		my   $tags;
		ref          $_[0] eq 'HASH' 
		? (  $tags = $_[0] ) 
		: ( @$tags{  @_ } = (1) x @_ );

		%$tags or $tags->{is} = 1;

		foreach my $tag (keys %$tags) { 

			# bless()ings below are just for labeling (safe enough as nobody would check ref *GLOB{CODE} eq 'CODE', which becomes false unexpectedly)...

			my $tagged_accessor 
			=  _tagged_accessor($tagger_class, $tag);
			my $tag_value = bless \$tags->{$tag}, $tagger_class;

			my $tagger_accessor  = join '::', $tagger_class, $tag;
			my $tagged_accessor2 = join '::', $tagged_class, $tagged_accessor;
			if ($unimport) {
				croak("Error: tag accessor collision - alien $tag() in tagger class $tagger_class")
				if      *$tagger_accessor{CODE}
				and ref *$tagger_accessor{CODE} ne $tagger_class; # means we may have been using alien thing as accessor

				undef   *$tagger_accessor 
				and      $tagged_class 
				eq       $tagger_class;

				undef   *$tagged_accessor2; # has rare name, so safe to unconditionally undef entire glob
			}
			else {
				*$tagged_accessor2 = sub{ 
					@_ > 1 
					? ( _ref_type($_[0]) eq 'HASH' 
					?    bless  \($_[0]->{$tagger_accessor} = $_[1]), $tagger_class 
					:           \($$tag_value               = $_[1]) ) 
					: ( _ref_type($_[0]) eq 'HASH' 
					?    exists   $_[0]->{$tagger_accessor} 
					?    bless   \$_[0]->{$tagger_accessor},          $tagger_class 
					: $tag_value 
					: $tag_value ) 
				}; 

				if ( $tagged_class 
				eq   $tagger_class) {
					*$tagger_accessor{CODE} and ref 
					*$tagger_accessor{CODE} ne  $tagger_class and croak("Error: tag accessor collision - tagger class $tagger_class already defines or stubs $tag()");
					*$tagger_accessor{CODE} or
					*$tagger_accessor = bless sub{

						my $sub_accessor;
						unless (@_ == 2 and $_[0] eq $_[1]) { 
							local $Class::Tag::AUTOLOAD 
							=                 'AUTOLOAD' 
							if        $tag eq 'AUTOLOAD'; 
							$sub_accessor = $tagger_class->$tag($tagger_class);
						}

						unshift @_, undef # if called as function
						unless  @_ > 1
						and ref($_[0])||$_[0] eq $tagger_class;

						goto  &$sub_accessor
						if ref $sub_accessor eq 'CODE';

						ref $_[1] 
						or  $_[1] =~ /^\w[\w\:]*$/
						or return undef;
						#or croak("Error: No valid class specified as first argument: '$_[1]'");

						my  $tagged_accessor 
						=   $tagged_accessor; 
						if ($tag eq 'AUTOLOAD') {
							(my $AUTOLOAD    =  $Class::Tag::AUTOLOAD) =~ s/^.*:://;
							$tagged_accessor = 
							_tagged_accessor($tagger_class, $AUTOLOAD);
						}

						my $scalar_value =   defined $_[0] # called as method
						? &{  shift;                 $_[0]->can($tagged_accessor)       or return undef }
						: &{*{join '::', ref($_[1])||$_[1],     $tagged_accessor}{CODE} or return undef } 
						if   $_[1] and (!ref $_[1] or blessed($_[1])) 
						or   croak("Querying tag of untagable $_[1]");
						return ref $scalar_value eq $tagger_class ? $$scalar_value : undef

					}
					, $tagger_class; 
				}
				else {
					$tagger_class->isa( ref
					$tagger_class->can($tag) ) or
					$tagger_class->isa( ref
					$tagger_class->can('AUTOLOAD') ) 
					or croak("Error: tagger class $tagger_class declares no '$tag' tag: ", $tagged_class);
				}
			}

			if ($tag eq  'tagger_class') {

				my $new_tagger_class = $tagged_class;
				$INC{ join '/', split '::', "$new_tagger_class.pm" } ||= 1; # support inlined tag classes
				my $new_import    = join '::',  $new_tagger_class, 'import';
				my $new_import2   = join '::',  $new_tagger_class, 'tag';
				my $sub_import    = *$new_import{CODE};
				my $sub_import2   = *$new_import2{CODE};
				my $new_unimport  = join '::',  $new_tagger_class, 'unimport';
				my $new_unimport2 = join '::',  $new_tagger_class, 'untag';
				my $sub_unimport  = *$new_unimport{CODE};
				my $sub_unimport2 = *$new_unimport2{CODE};

				if ($unimport) { 
				}
				else {
					my $sub_new_import = sub{
						my ($sub_import, $sub_wasimport) = @_;

						return #bless 
						! $sub_wasimport
						? $sub_import
						: sub{ 

							#goto &$sub_import;

							local $Class::Tag::caller = caller; # let &$sub_import know original caller...
							   # &$sub_import; 
							     &$sub_import(@_);
							goto &$sub_wasimport 
							if    $sub_wasimport;
						};
						#, $tagger_class;
					};

					*$new_import =
					*$new_import2   
					= __PACKAGE__->new_import();

					*$new_unimport  =
					*$new_unimport2 
					= __PACKAGE__->new_import('unimport');
				}
			}
		}
	}
}

sub _ref_type {
	return undef if !ref $_[0];
	return $1    if      $_[0] =~ /=(\w+)/;
	return           ref $_[0]
}

1;

