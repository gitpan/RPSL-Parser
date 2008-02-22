package RPSL::Parser;
use strict;
use warnings;
use base qw( Object::Accessor );

our $VERSION = 0.01;

BEGIN { $Object::Accessor::FATAL = 1; }

{
    my %accessors = (
        comment  => {},
        object   => {},
        omit_key => [],
        order    => [],
    );

    sub new {
        my $class = shift;
        my $self  = $class->SUPER::new;
        $self->mk_accessors( qw(key text tokens type), keys %accessors );
        $self->$_( $accessors{$_} ) for keys %accessors;
        return $self;
    }
}

sub parse {
    my $self = shift;
    return $self->_read_text(@_)->_tokenize->_build_parse_tree->_parse_tree;
}

sub _read_text {
    my ( $self, @input ) = @_;
    my $data;
    if (   UNIVERSAL::isa( $input[0], 'GLOB' )
        or UNIVERSAL::isa( $input[0], 'IO::Handle' ) )
    {
        local $/;
        $data = <$input[0]>;
    }
    else {
        $data = join '', @input;
    }
    $self->text($data);
    return $self;
}

sub _cleanup_attribute {
    my ( $self, $value ) = @_;
    return unless $value;
    $value =~ s/\n\s+/\n/gosm;
    $value =~ s/^\s+|\s+$//go;
    return $value;
}

sub _tokenize {
    my $self = shift;
    my $text = $self->text;
    study $text;
    my @tokens = $text =~ m{
        ^(?:
	    # Look for an attribute name ...
            ( [a-z0-9][a-z0-9_-]+[a-z0-9] ):
	    # ... followed by zero or more horizontal spaces ...
            [\t ]*
	    # ... followed by a value ...
            ( .*?
		# ... and all valid continuation lines.
	        (?: \n [\s+] .* ? )*
            )
        )$
    }mixg;
    $self->tokens( \@tokens );
    return $self;
}

sub _store_attribute {
    my ( $self, $key, $value ) = @_;
    $value = $self->_cleanup_attribute($value);

    # Store the value
    if ( exists $self->object->{$key} ) {
        if ( !UNIVERSAL::isa( $self->object->{$key}, 'ARRAY' ) ) {
            $self->object->{$key} = [ $self->object->{$key} ];
        }
        push @{ $self->object->{$key} }, $value;
    }
    else {
        $self->object->{$key} = $value;
    }
    return $self;
}

sub _store_comment {
    my ( $self, $order, $value ) = @_;
    return unless defined $value;
    if ( $value =~ s{#(.*)}{} ) {
        $self->comment->{$order} = $self->_cleanup_attribute($1);
    }
    return $value;
}

sub _build_parse_tree {
    my $self   = shift;
    my @tokens = @{ $self->tokens };
    my ( @order, @omit_key );
    while ( my ( $key, $value ) = splice @tokens, 0, 2 ) {

        # Save the order
        push @order, $key;

        # Handle multi-line comments
        if ( defined $value ) {
            my @parts = split qr{\n\+?\s*}, $value;
            if ( @parts > 1 ) {    # too much, put it back.
                unshift @tokens, $key, $_ for reverse @parts[ 1 .. $#parts ];
                $value = $parts[0];
                my $count = $#order;
                map { push @omit_key, $count + $_ } 1 .. $#parts;
            }
        }

        $value = $self->_store_comment( $#order, $value );
        $self->_store_attribute( $key, $value );
    }    # end while

    # Fill in the object's meta-attributes
    $self->order( \@order );
    $self->omit_key( \@omit_key );
    $self->type( $order[0] );

    # Stores the object primary key value
    my $primary_key = $self->object->{ $order[0] };
    $primary_key = $primary_key->[0] if UNIVERSAL::isa( $primary_key, 'ARRAY' );
    $primary_key =~ s{\s*\#.*$}{};
    $self->key($primary_key);

    # Done!
    return $self;
}

sub _parse_tree {
    my $self = shift;
    return {
        data     => $self->object,
        order    => $self->order,
        type     => $self->type,
        key      => $self->key,
        comment  => $self->comment,
        omit_key => $self->omit_key,
    };
}

1;
__END__

=head1 NAME

RPSL::Parser - Router Policy Specification Language (RFC2622) Parser

=head1 SYNOPSIS

	use RPSL::Parser;
	# Create a parser
	my $parser = new RPSL::Parser;
	# Use it
	my $data_structure = $parser->parse($data);

=head1 DESCRIPTION

This is a rather simplistic lexer and tokenizer for the RPSL language.

It currently does not validate the object in any way, it just tries (rather
hard) to grab the biggest ammount of information it can from the text presented
and place it in a Parse Tree (that can be passed to other objects from the
I<RPSL> namespace for validation and more RFC2622 related functionality).

=head1 METHODS

=head2 Public Interface 

=over 4

=item B<C<new()>>

Constructor. Handles the accessor creation and returns a new L<RPSL::Parser> object.

=item B<C<parse( [ $rpsl_source | IO::Handle | GLOB ] )>>

Parses B<one> RPSL object for each call, uses the parser internal fields to
store the data gathered. This is the method you need to call to transform your
RPSL text into a Perl data structure.

It accepts a list or a scalar containing the strings representing the RPSL
source code you want to parse, and can read it directly from any L<IO::Handle>
or C<GLOB> representing an open file handle.

=back

=head2 Accessor Methods

=over 4

=item B<C<comment()>>

Stores an array reference containing all the inline comments found in the RPSL
text.

=item B<C<object>>

Stores a hash reference containing all the RPSL attributes found in the RPSL
text.

=item B<C<omit_key>>

Stores an array reference containing all the position of the keys we must omit
from the original RPSL text.

=item B<C<order>>

Stores an array reference containing an ordered list of RPSL attribute names,
to enable the RPSL to be rebuilt from the parsed data version.

=item B<C<key>>

Stores the value found in the first RPSL attribute parsed. This is sometimes
refered as the RPSL object key.

=item B<C<text>>

Stores an scalar containing the RPSL text to be parsed.

=item B<C<tokens>>

Stores an array reference containing an ordered list of tokens and token values
produced by the tokenize method.

=item B<C<type>>

Stores a string representing the name of the first RPSL attribute found in the
RPSL text parsed. The RFC 2622 requires that the first attribute declares the
"data type" of the RPSL object declared. 

=back

=head2 Private Interface 

=over 4

=item B<C<_read_text( @input )>>

Checks if the first element from C<@input> is a L<IO::Handle> or a C<GLOB>, and
reads from it. If the first element is not any type of file handle, assumes
it's an array of scalars containing the text for the RPSL object to be parsed,
C<join()> it all toghether and feed it to the parser.

=item B<C<_tokenize()>>

This method breaks down the RPSL source code read by C<read_text()> into
tokens, and store them internally. For commodity, it returs a reference to the
object itself, so you can chain up method calls.

=item B<C<_cleanup_attribute( $value )>>

Returns a cleaned-up version of the attribute passed in: no trailling or
leading whitespace or newlines.

=item B<C<_store_attribute( $attribute_name, $attribute_value )>>

Auxiliary method. It clean up the value and store the attribute in the data
structure being built, and does the necessary storage upkeep.

=item B<C<_store_comment( $comment_position_index, $attribute_and_comment_text )>>

This method extracts inline comments from the inline part of an object and
store those comments into the parse tree being built. It returns the attribute
passed in with the comments stripped, so it can be stored into the appropriated
place afterwards.

=item B<C<_build_parse_tree()>>

This method consumes the tokens produced by C<_tokenize()> and builds a data
structure containing all the information needed to re-build the RPSL object
back.

It returns a reference to the parser object itself, making easy to chain method
calls again.

=item B<C<_parse_tree()>>

This method assembles all the information gathered during the RPSL source code
tokenization and parsing into a hash reference containing the following keys:

=over 4

=item B<data>

Holds a hash reference whose keys are the RPSL attributes found, and the values
are the string passed in as values to the respective attributes in the RPSL
text. Multi-valued attributes are represented by array references. As this
parser doesn't enforces all the RPSL business rules, you must take care when
fiddling with this structure, as any value could be an array reference.

=item B<order>

Holds an array reference containing the key names from the B<data> hash, in the
order they where found in the RPSL text. This is stored here because the RFC
2622 commands that the order of the attributes in a RPSL object is important.

=item B<type>

Holds a string containing the name of the first RPSL attribute found in the
RPSL text. RFC 2622 commands that the first attribute must be the type of the
object declared. Knowing the type of object can allow proper manipulation of
the different RPSL object types by other RPSL namespace modules.

=item B<key>

Holds the value contained by the first attribute of an RPSL object. This is
sometimes the "primary key" of a RPSL object, but not always. 

=item B<comment>

Comment is a hash structure where the keys are index positions in the B<order>
array, and values are the inline comments extracted during the parsing stage.
Preserving inline comments is not a requirement from RFC 2622, just a nice
thing to have.

=item B<omit_key>

RFC 2622 allows some attribute names to contain multiple values. For every new
value, a new line must be inserted into the RPSL object. For brevity, and to
allow humans to read and write RPSL, the RFC 2622 allows the attribute name to
be omited and replaced by whitespace. It also dictates that lines begining with
a "+" sign must be considered as being part of a multi-line RPSL attribute.

This array reference stores integers representing index positions in the
B<order> array signaling attribute positions that must be omited when
generating RPSL text back from this parse tree. As RFC 2622 doesn't request
that attributes omited by starting a line with whitespace or "+" must preserve
this characteristic, this is only a nice-to-have feature.  =back

=back

=back

=head1 SEE ALSO

RFC2622 L<http://www.ietf.org/rfc/rfc2622.txt>, for the full RPSL specification.

L<Object::Accessor>, for the accessor implementation used in this module.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Luis Motta Campos, E<lt>lmc@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Luis Motta Campos

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
