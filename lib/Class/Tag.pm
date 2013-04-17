package Class::Tag;

#use 5.006; 

use strict qw[vars subs];
$Class::Tag::VERSION = '0.02_01';  

=head1 NAME

Class::Tag - programmatically label (mark) classes and modules with tags (key/value pairs) and query those tags

=head1 SYNOPSIS

Directly using Class::Tag as tagger class: 

	package Foo;
	use Class::Tag 'tagged'; 
	tag Class::Tag 'tagged'; # same, but at run-time

	Class::Tag->tagged('Foo'); # true
	Class::Tag->tagged('Bar'); # false

	#no   Class::Tag 'tagged'; # at compile-time, so will not work - instead...
	untag Class::Tag 'tagged'; # at run-time
	Class::Tag->tagged('Foo'); # false

If no tags are give, the 'is' tag is assumed:

	package Foo;
	use Class::Tag;      # equivalent to...
	use Class::Tag 'is'; # same
	use Class::Tag ();   # no tagging

New tagger class can be created by simply tagging package with special 'tagger_class' tag using Class::Tag or any other tagger class, and then declaring specific tags or any tag to be used with that new tagger class. Tags declaration is done by tagger class tagging itself with those specific tags or special 'AUTOLOAD' tag (tag values are irrelevant in case of declaration):

	package Awesome; # new tagger class
	use  Class::Tag 'tagger_class'; # must be before following declarations
	use     Awesome 'specific_tag'; # declare 'specific_tag' for use
	use     Awesome 'AUTOLOAD';     # declares that any tag can be used

	Class::Tag->tagger_class('Awesome'); # true

The Class::Tag itself is somewhat similar to the following implicit declaration:

	package Class::Tag; 
	use     Class::Tag 'tagger_class';
	use     Class::Tag 'AUTOLOAD';

Attempt to use tag that has not been declared (assuming 'AUTOLOAD' declares any tag) raises exception.

Any tagger class can be used as follows (in all following examples the original Class::Tag and Awesome tagger classes are interchangeable), assuming tags have been declared: 

Using default 'is' tag: 

	package Foo;
	use Awesome;
	use Awesome  'is';       # same
	use Awesome { is => 1 }; # same

	Awesome->is('Foo'); # true
	Awesome->is('Bar'); # false

Using tags 'class' and 'pureperl': 

	package Foo; 
	# tagging class Foo with tags 'class' and 'pureperl' of Awesome tagger class...
	use Awesome  'class';
	use Awesome              'pureperl';
	use Awesome  'class',    'pureperl';       # same
	use Awesome { class => 1, pureperl => 1 }; # same

	Awesome->class(   'Foo'); # true
	Awesome->pureperl('Foo'); # true
	Awesome->class(   'Bar'); # false
	Awesome->pureperl('Bar'); # false

Using key/value pairs as tags (tag values):

	package Foo;
	use Awesome { class => 'is cool', author => 'metadoo' }; 

	Awesome->class( 'Foo') eq 'is cool'; # true
	Awesome->author('Foo') eq 'metadoo'; # true

Modifying tag values with accessors...

	Awesome->class( 'Foo', 'is pupe-perl') eq 'is pupe-perl'; # true
	Awesome->class( 'Foo')                 eq 'is pupe-perl'; # true

Inheriting tags, using for example the default 'is' tag:

	package Foo;
	use Awesome;
	use Awesome 'is'; # same

	@Bar::ISA = 'Foo';

	Awesome->is('Foo'); # true
	Awesome->is('Bar'); # true ('is' tag inherited)
	Awesome::is('Foo'); # true
	Awesome::is('Bar'); # false (no tag inheritance)

=head1 DESCRIPTION

Sometimes it is necessary to programmatically tag modules and classes with some tags (arbitrary labels or key/value pairs) to be able to assert that you deal with proper class or module. Such need typically arises for plug-in modules, application component modules, complex class inheritance hierarchies, etc. 

Often tags need to be inheritable (but it is not always the case), and consequently there are two natural solutions: classes-as-tags and methods-as-tags. The classes-as-tags solution is using universal isa() method to see if class has specific parent and effectively using specific parent classes as tags. However, using parent classes just as tags is a limited solution since @ISA is used for different things and better be used for those things exclusively to avoid interferences. 

Using methods-as-tags approach is about defining and using specific methods as tags. It is way better then classes-as-tags, but suffers from two problems: 

=over

=item Name collision

Possibility of collision of readable short tag names with methods in class they are supposed to tag and (most risky) in its subclasses.

=item Tagging and tag check timing

If one tries to check tag before tagging, there will be no tag method yet, so call of tag method will raise an exception. This suggests can() or eval{} to be always used as a precaution:

	my $tag_value = eval{ $class->tag }; # or...
	my $tag_value =       $class->tag 
	if               $class->can('tag');

=item AUTOLOAD()ing of methods

Potential use of AUTOLOAD requires can() to be used to check if tag is defined, making tag value checks rather cumbersome:

	my $tag_value = $class->tag 
	if         $class->can('tag');

=over

Class::Tag solves these problems by moving tag creation and tag accessors to "tagger classes".

Class::Tag itself serves as tagger class, and each tagger class is a "constructor" for other tagger classes, either loadable or inlined. Tagger class "exports" chosen named tags into packages that are tagged by use()ing it and provide its own samename accessor methods for those tags. Name of tagger class (except for collision with already existing classes) and its tags can be arbitrary, so they can be selected to read meaningful (see examples in L</"SYNOPSIS">).

=head1 Constructing tagger classes

See L</"SYNOPSIS"> for description of new tagger class creation. Tagger class can be created "inline", without using separate .pm file for it.

The value of 'tagger_class' is reserved for special use in the future, so it should not be used for anything to avoid collision with future versions.

There are a few reasons to use multiple tagger classes in addition to Class::Tag itself:

=over

=item Name

Name of the tagger class can be chosen to read meaningful with specific tags used in the context of given application or problem area domain.

=item Collision with Class::Tag guts

The original Class::Tag tagger class is not empty, so that not every tag can be used. In contrast, any empty package can be used as tagger classes.

=item Orthogonality of tags

Each tagger class has its own orthogonal tags namespace, so that same tags of different tagger classes do not collide:

	package Awesome;
	use Class::Tag 'tagger_class';
	use    Awesome 'AUTOLOAD';

	package Bad; 
	use Class::Tag 'tagger_class';
	use        Bad 'AUTOLOAD';

	package Foo;
	use    Awesome 'really';
	use    Awesome { orthogonal => 'awesome' }; 
	use        Bad { orthogonal => 'bad' };

	really Awesome 'Foo';                           # true
	really     Bad 'Foo';                           # false
	           Bad->orthogonal('Foo') eq 'bad';     # true
	       Awesome->orthogonal('Foo') eq 'awesome'; # true

Without other tagger classes the tags namespace of Class::Tag would be exposed to higher risk of tags collision, since due to global nature of Perl classes there is always a possibility of collision when same tag is used for unrelated purposes (e.g. in the same inheritance chain, etc.).

=item Making existing class/module a tagger class

Since tagger class tags upon use() and classes usually do not export anything, it is often useful and possible to make some existing class a tagger to tag classes that use() it. Moreover, it can be done from a distance, without cognizance of the existing class. The same also applies to modules that are not classes.

However, making existing class/module a tagger class requires care to not collide with methods of that class - Class::Tag will raise an exception when such collision happens. It is better not to declare 'AUTOLOAD' for such tagger class.

=back

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

sub _ANTICOLLIDER () { 'aixfHgvpm7hgVziaO' }

sub _tagged_accessor  { _subnames( join '_', $_[0], _ANTICOLLIDER(), $_[1] ) }

sub _subnames { my $a; ($a = $_[0]) =~ s/:/_/g; return $a }

*unimport = *untag = __PACKAGE__->new_import('unimport');
  *import = *tag   = __PACKAGE__->new_import();
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
			my $tagged_accessor 
			=  _tagged_accessor($tagger_class, $tag);
			my $tag_value = $tags->{$tag}; 

			# bless()ings below are just for labeling (safe enough as nobody would check ref *GLOB{CODE} eq 'CODE', which becomes false unexpectedly)...

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
				*$tagged_accessor2 = sub{ @_ > 1 ? $tag_value = $_[1] : $tag_value }; 

				if ( $tagged_class 
				eq   $tagger_class) {
					*$tagger_accessor{CODE} and ref 
					*$tagger_accessor{CODE} ne  $tagger_class and croak("Error: tag accessor collision - tagger class $tagger_class already defines or stubs $tag()");
					*$tagger_accessor{CODE} or
					*$tagger_accessor = bless sub{
						my $tagged_accessor 
						=  $tagged_accessor; 
						if ($tag eq 'AUTOLOAD') {
							(my $AUTOLOAD =     $Class::Tag::AUTOLOAD) =~ s/^.*:://;
							$tagged_accessor = 
							_tagged_accessor($tagger_class, $AUTOLOAD);
						}

						return @_ > 1  # called as method
						? &{ shift; $_[0]->can($tagged_accessor) or return undef }
						: &{ *{"$_[0]::$tagged_accessor"}{CODE}  or return undef }; 
					}
					, $tagger_class; 
				}
				else {
					$tagger_class->isa( ref
					$tagger_class->can($tag) ) or
					$tagger_class->isa( ref
					$tagger_class->can('AUTOLOAD') ) 
					or confess("Error: tagger class $tagger_class declares no '$tag' tag: ", $tagged_class);
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

				if (0 and $unimport) { 
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

1;

