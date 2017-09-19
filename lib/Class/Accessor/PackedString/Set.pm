package Class::Accessor::PackedString::Set;

# DATE
# VERSION

#IFUNBUILT
use strict 'subs', 'vars';
use warnings;
#END IFUNBUILT

sub import {
    my ($class0, $spec) = @_;
    my $caller = caller();

    my $class = $caller;

#IFUNBUILT
    no warnings 'redefine';
#END IFUNBUILT

    my $attrs = $spec->{accessors};

    # store list of accessors in the package
    {
#IFUNBUILT
        no warnings 'once';
#END IFUNBUILT
        @{"$class\::HAS_PACKED"} = @$attrs;
    }

    # generate accessors
    my %idx     ; # key = attribute name, value = index
    my %tmpl    ; # key = attribute name, value = pack() template
    my %tmplsize; # key = attribute name, value = pack() data size
    my @attrs = @$attrs;
    while (my ($name, $template) = splice @attrs, 0, 2) {
        $idx{$name}      = keys %idx;
        $tmpl{$name}     = $template;
        $tmplsize{$name} = length(pack $template);
    }

    @attrs = @$attrs;
    while (my ($name, $template) = splice @attrs, 0, 2) {
        my $idx = $idx{$name};
        my $code_str = 'sub (;$) {';
        $code_str .= qq( my \$self = shift;);

        $code_str .= qq( my \$val; my \$pos = 0; while (1) { last if \$pos >= length(\$\$self); my \$idx = ord(substr(\$\$self, \$pos++, 1)););
        for my $attr (sort {$idx{$a} <=> $idx{$b}} keys %idx) {
            my $idx = $idx{$attr};
            $code_str .= qq| if (\$idx == $idx) { my \$v = unpack("| . $tmpl{$attr} . qq|", substr(\$\$self, \$pos, | . $tmplsize{$attr} . qq|)); \$pos += | . $tmplsize{$attr} . qq|;|;
            if ($attr eq $name) {
                $code_str .= qq| \$val = \$v; last;|;
            } else {
                $code_str .= qq| next;|;
            }
            $code_str .= qq| }|;
        }
        $code_str .= qq(} );

        # TODO
        #$code_str .= qq( if (\@_) { \$attrs[$idx] = \$_[0]; \$\$self = pack("$pack_template", \@attrs) });
        #$code_str .= qq( return \$attrs[$idx];);
        $code_str .= " }";
        print "D:accessor code for $name: ", $code_str, "\n";
        *{"$class\::$name"} = eval $code_str;
        die if $@;
    }

    # generate constructor
    {
        my $code_str;

        $code_str = 'sub { my $o = ""; bless \$o, shift }';

        # TODO

        #$code_str  = 'sub { my ($class, %args) = @_;';
        #$code_str .= qq( no warnings 'uninitialized';);
        #$code_str .= qq( my \@attrs = map { undef } 1..$num_attrs;);
        #for my $attr (sort keys %$attrs) {
        #    my $idx = $idx{$attr};
        #    $code_str .= qq( if (exists \$args{'$attr'}) { \$attrs[$idx] = delete \$args{'$attr'} });
        #}
        #$code_str .= ' die "Unknown $class attributes in constructor: ".join(", ", sort keys %args) if keys %args;';
        #$code_str .= qq( my \$self = pack('$pack_template', \@attrs); bless \\\$self, '$class';);
        #$code_str .= ' }';

        #print "D:constructor code for class $class: ", $code_str, "\n";
        my $constructor = $spec->{constructor} || "new";
        unless (*{"$class\::$constructor"}{CODE}) {
            *{"$class\::$constructor"} = eval $code_str;
            die if $@;
        };
    }
}

1;
# ABSTRACT: Generate accessors/constructor for object that use pack()-ed string as storage backend

=for Pod::Coverage .+

=head1 SYNOPSIS

In F<lib/Your/Class.pm>:

 package Your::Class;
 use Class::Accessor::PackedString::Set {
     # constructor => 'new',
     accessors => [
         foo => "f",
         bar => "c",
     ],
 };

In code that uses your class:

 use Your::Class;

 my $obj = Your::Class->new;

C<$obj> is now:

 bless(do{\(my $o = "")}, "Your::Class")

After:

 $obj->bar(34);

C<$obj> is now:

 bless(do{\(my $o = join("", chr(1), pack("c", 34)))}, "Your::Class")

After:

 $obj->foo(1.2);

C<$obj> is now:

 bless(do{\(my $o = join("", chr(1), pack("c", 34), chr(0), pack("f", 1.2)))}, "Your::Class")

After:

 $obj->bar(undef);

C<$obj> is now:

 bless(do{\(my $o = join("", chr(0), pack("f", 1.2)))}, "Your::Class")

To subclass, in F<lib/Your/Subclass.pm>:

 package Your::Subclass;
 use parent 'Your::Class';
 use Class::Accessor::PackedString::Set {
     accessors => [
         @Your::Class::HAS_PACKED,
         baz => "a8",
         qux => "a8",
     ],
 };


=head1 DESCRIPTION

This module is a builder for classes that use string as memory storage backend.
The string is initially empty when there are no attributes set. When an
attribute is set, string will be appended with this data:

 | size        | description                        |
 +-------------+------------------------------------+
 | 1 byte      | index of attribute                 |
 | (pack size) | attribute value, encoded by pack() |

When another attribute is set, string will be further appended with similar
data. When an attribute is unset (undef'd), its entry will be removed in the
string.

Using string (of pack()-ed data) is useful in situations where you need to
create many (e.g. thousands+) objects in memory and want to reduce memory usage,
because string-based objects are more space-efficient than the commonly used
hash-based objects. Space is further saved by only storing set attributes and
not unset attributes. This particularly saves significant space if you happen to
have many attributes with usually only a few of them set.

The downsides are: 1) you have to predeclare all the attributes of your class
along with their types (pack() templates); 2) you can only store data which can
be pack()-ed; 3) slower speed, because unpack()-ing and re-pack()-ing are done
everytime an attribute is accessed or set.

Caveats:

There is a maximum of 256 attributes.


=head1 SEE ALSO

L<Class::Accessor::PackedString>
