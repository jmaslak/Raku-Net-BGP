use v6;

#
# Copyright © 2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Path-Attribute;

use StrictClass;
unit class Net::BGP::Path-Attribute::Long-Community:ver<0.5.0>:auth<cpan:JMASLAK>
    is Net::BGP::Path-Attribute
    does StrictClass;

use Net::BGP::Conversions;
use Net::BGP::IP;

# Long-Community Types
method implemented-path-attribute-code(-->Int) { 32 }
method implemented-path-attribute-name(-->Str) { "Long-Community" }

method path-attribute-name(-->Str:D) { "Long-Community" }

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

method offset(-->Int:D) {
    return ($.raw[0] +& 0x10) ?? 4 !! 3;
}

method payload-length(-->Int:D) {
    return ($.raw[0] +& 0x10) ?? nuint16($.raw[2],$.raw[3]) !! $.raw[2];
}

method from-raw(buf8:D $raw where { $^r.bytes ≥ 3 }, Bool:D :$asn32) {
    if ! $raw[0] +& 0x80 { die("Optional flag must be set on Long-Community attribute") }
    if ! $raw[0] +& 0x40 { die("Transitive flag must be set on Long-Community attribute") }
    # Partial flag is not tested

    my $offset = ($raw[0] +& 0x10) ?? 4 !! 3;
    my $len    = ($raw[0] +& 0x10) ?? nuint16($raw[2],$raw[3]) !! $raw[2];

    if   $raw[1] ≠ 32 { die("Can only create a Long-Community attribute") }

    if ($raw.bytes - $offset) ≠ $len { die("Invalid path-attribute payload length ({$raw.bytes}, $offset, {$len}") }

    my $obj = self.bless(:$raw, :$asn32);
    return $obj;
};

method from-hash(%params is copy, Bool:D :$asn32)  {
    my @REQUIRED = «long-community»;

    # Remove path attributes
    if %params<path-attribute-code>:exists {
        if %params<path-attribute-code> ≠ 32 {
            die("Can only create an Long-Community attribute");
        }
        %params<path-attribute-code>:delete;
    }
    if %params<path-attribute-name>:exists {
        if %params<path-attribute-name> ≠ 'Long-Community' {
            die("Can only create an Long-Community attribute");
        }
        %params<path-attribute-name>:delete;
    }

    # Check to make sure attributes are correct
    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    my $long-community-list = buf8.new;
    for @(%params<long-community>) -> $comm {
        my @parts = $comm.split(':');
        $long-community-list.append: nuint32-buf8(Int(@parts[0]));
        $long-community-list.append: nuint32-buf8(Int(@parts[1]));
        $long-community-list.append: nuint32-buf8(Int(@parts[2]));
    }

    my $flag = 0xC0;  # Optional, Transitive
    if $long-community-list.bytes > 255 { $flag += 0x10 }  # Extended length?

    my buf8 $path-attribute = buf8.new();
    $path-attribute.append( $flag );
    $path-attribute.append( 32 );

    if $long-community-list.bytes > 255 {
        $path-attribute.append: nuint16-buf8( $long-community-list.bytes );
    } else {
        $path-attribute.append: $long-community-list.bytes;
    }

    $path-attribute.append: $long-community-list;

    return self.bless(:raw( $path-attribute ), :$asn32);
};

method long-community-list(-->Array[Str:D]) {
    my Str:D @elems = gather {
        for ^(self.payload-length / 12) -> $i {
            my $base = self.offset + $i * 12;
            take nuint32( self.raw.subbuf( $base, 4 ) ) ~ ':'
                ~ nuint32( self.raw.subbuf( $base+4, 4 ) ) ~ ':'
                ~ nuint32( self.raw.subbuf( $base+8, 4 ) );
        }
    }

    return @elems;
}

method Str(-->Str:D) { "Long-Community=" ~ self.long-community-list.join(" ") }

# Register path-attribute
INIT { Net::BGP::Path-Attribute.register(Net::BGP::Path-Attribute::Long-Community) }

=begin pod

=head1 NAME

Net::BGP::Message::Path-Attribute::Long-Community - BGP Long-Community Path-Attribute Object

=head1 SYNOPSIS

  use Net::BGP::Path-Attribute::Long-Community;

  my $cap = Net::BGP::Path-Attribute::Long-Community.from-raw( $raw );
  # or …
  my $cap = Net::BGP::Path-Attribute::Long-Community.from-hash(
    %{ long-community => '1:2:3' }
  );

=head1 DESCRIPTION

BGP Path-Attribute Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  This requires elements with keys of
C<path-attribute-code> and C<value>.  Path-Attribute code should represent the
desired path-attribute code.  Value should be a C<buf8> containing the payload
data (C<value> in RFC standards).

It also accepts values for C<optional>, C<transitive>, and C<partial>, which
are used to populate the C<flags> field in the attribute.  These all default to
C<False> if they are not provided by the caller.

=head1 Methods

=head2 path-attribute-code

Cpaability code of the object.

=head2 path-attribute-name

The path-attribute name of the object.

=head2 flags

The value of the attribute flags (as a packed integer).

=head2 optional

True if the attribute is an optional (not well-known).

=head2 transitive

True if the attribute is a transitive attribute.

=head2 partial

True if the attribute is a partial attribute, I.E. this attribute was seen on
an intermediate router that does not understand how to process it.

=head2 extended-length

True if the attribute uses a two digit length

=head2 reserved-flags

The four flags not defined in RFC4271, represented as a packed integer (values
will be 0 through 15).

=head2 data-length

The length of the attribute's data.

=head2 data

This returns a C<buf8> containing the data in the attribute.

=head2 raw

Returns the raw (wire format) data for this path-attribute.

=head2 ip

The IP address (in string format) of the next hop.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
