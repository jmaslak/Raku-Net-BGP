use v6;

#
# Copyright © 2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Path-Attribute;

use StrictClass;
unit class Net::BGP::Path-Attribute::Extended-Community:ver<0.6.0>:auth<cpan:JMASLAK>
    is Net::BGP::Path-Attribute
    does StrictClass;

use Net::BGP::Conversions;
use Net::BGP::IP;

# Extended-Community Types
method implemented-path-attribute-code(-->Int) { 16 }
method implemented-path-attribute-name(-->Str) { "Extended-Community" }

method path-attribute-name(-->Str:D) { "Extended-Community" }

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
    if ! $raw[0] +& 0x80 { die("Optional flag must be set on Extended-Community attribute") }
    if ! $raw[0] +& 0x40 { die("Transitive flag must be set on Extended-Community attribute") }
    # Partial flag is not tested

    my $offset = ($raw[0] +& 0x10) ?? 4 !! 3;
    my $len    = ($raw[0] +& 0x10) ?? nuint16($raw[2],$raw[3]) !! $raw[2];

    if   $raw[1] ≠ 16 { die("Can only create a Extended-Community attribute") }

    if ($raw.bytes - $offset) ≠ $len { die("Invalid path-attribute payload length ({$raw.bytes}, $offset, {$len}") }

    my $obj = self.bless(:$raw, :$asn32);
    return $obj;
};

method from-hash(%params is copy, Bool:D :$asn32)  {
    my @REQUIRED = «extended-community»;

    # Remove path attributes
    if %params<path-attribute-code>:exists {
        if %params<path-attribute-code> ≠ 16 {
            die("Can only create an Extended-Community attribute");
        }
        %params<path-attribute-code>:delete;
    }
    if %params<path-attribute-name>:exists {
        if %params<path-attribute-name> ≠ 'Extended-Community' {
            die("Can only create an Extended-Community attribute");
        }
        %params<path-attribute-name>:delete;
    }

    # Check to make sure attributes are correct
    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        dd %params.keys.sort.list;
        die("Did not provide proper options");
    }

    my $extended-community-list = buf8.new;
    for @(%params<extended-community>) -> $comm {
        my @parts = $comm.split(':');
        if @parts.elems == 2 and @parts[0] eq 'ET' {
                $extended-community-list.append: 0x03;
                $extended-community-list.append: 0x0c;
                $extended-community-list.append: nuint32-buf8(0);
                $extended-community-list.append: nuint16-buf8(Int(@parts[1]));
        } elsif @parts.elems == 3 and @parts[0] eq 'ET' {
                $extended-community-list.append: 0x03;
                $extended-community-list.append: 0x0c;
                $extended-community-list.append: nuint32-buf8(Int(@parts[1]));
                $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
        } elsif @parts.elems == 3 and @parts[0] eq 'RT' {
            if (@parts[1] ~~ Net::BGP::IP::ipv4) {
                $extended-community-list.append: 0x01;
                $extended-community-list.append: 0x02;
                $extended-community-list.append: nuint32-buf8(ipv4-to-int(@parts[1]));
                $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
            } elsif Int(@parts[1]) < 2¹⁶ {
                $extended-community-list.append: 0x00;
                $extended-community-list.append: 0x02;
                $extended-community-list.append: nuint16-buf8(Int(@parts[1]));
                $extended-community-list.append: nuint32-buf8(Int(@parts[2]));
            } else {
                $extended-community-list.append: 0x02;
                $extended-community-list.append: 0x02;
                $extended-community-list.append: nuint32-buf8(Int(@parts[1]));
                $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
            }
        } elsif @parts.elems == 3 and @parts[0] eq 'SoO' {
            if (@parts[1] ~~ Net::BGP::IP::ipv4) {
                $extended-community-list.append: 0x01;
                $extended-community-list.append: 0x03;
                $extended-community-list.append: nuint32-buf8(ipv4-to-int(@parts[1]));
                $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
            } elsif Int(@parts[1]) < 2¹⁶ {
                $extended-community-list.append: 0x00;
                $extended-community-list.append: 0x03;
                $extended-community-list.append: nuint16-buf8(Int(@parts[1]));
                $extended-community-list.append: nuint32-buf8(Int(@parts[2]));
            } else {
                $extended-community-list.append: 0x02;
                $extended-community-list.append: 0x03;
                $extended-community-list.append: nuint32-buf8(Int(@parts[1]));
                $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
            }
        } elsif @parts.elems == 4 and @parts[0] eq 'OSPF-Route-Type' {
            $extended-community-list.append: 0x03;
            $extended-community-list.append: 0x06;
            $extended-community-list.append: nuint32-buf8(Int(@parts[1]));
            $extended-community-list.append: Int(@parts[2]);
            $extended-community-list.append: Int(@parts[3]);
        } else {
            $extended-community-list.append: Int(@parts[0]);
            $extended-community-list.append: Int(@parts[1]);
            $extended-community-list.append: nuint16-buf8(Int(@parts[2]));
            $extended-community-list.append: nuint32-buf8(Int(@parts[3]));
        }
    }

    my $flag = 0xC0;  # Optional, Transitive
    if $extended-community-list.bytes > 255 { $flag += 0x10 }  # Extended length?

    my buf8 $path-attribute = buf8.new();
    $path-attribute.append( $flag );
    $path-attribute.append( 16 );

    if $extended-community-list.bytes > 255 {
        $path-attribute.append: nuint16-buf8( $extended-community-list.bytes );
    } else {
        $path-attribute.append: $extended-community-list.bytes;
    }

    $path-attribute.append: $extended-community-list;

    return self.bless(:raw( $path-attribute ), :$asn32);
};

method extended-community-list(-->Array[Str:D]) {
    my Str:D @elems = gather {
        for ^(self.payload-length / 8) -> $i {
            my $base = self.offset + $i * 8;

            if self.raw[$base] == 0x00 {
                # Two-octet AS-specific Transitive
                if self.raw[$base+1] == 0x02 {
                    # RT
                    take "RT:"
                        ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                        ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
                } elsif self.raw[$base+1] == 0x03 {
                    # Route Origin
                    take "SoO:"
                        ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                        ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
                } else {
                    take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                        ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
                }
            } elsif self.raw[$base] == 0x01 {
                # Two-octet IPv4-Specific Transitive
                if self.raw[$base+1] == 0x02 {
                    # RT
                    take "RT:"
                        ~ buf8-to-ipv4( self.raw.subbuf( $base+2, 4 ).list ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                } elsif self.raw[$base+1] == 0x03 {
                    # Route Origin
                    take "SoO:"
                        ~ buf8-to-ipv4( self.raw.subbuf( $base+2, 4 ).list ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                } else {
                    take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                        ~ buf8-to-ipv4( self.raw.subbuf( $base+2, 4 ).list ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                }
            } elsif self.raw[$base] == 0x02 {
                # Four-octet AS-specific Transitive
                if self.raw[$base+1] == 0x02 {
                    # RT
                    take "RT:"
                        ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                } elsif self.raw[$base+1] == 0x03 {
                    # Route Origin
                    take "SoO:"
                        ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                } else {
                    take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                        ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                }
            } elsif self.raw[$base] == 0x03 {
                if self.raw[$base+1] == 0x0c {
                    # Encapsulation Type
                    my $reserved = nuint32( self.raw.subbuf( $base+2, 4 ) );
                    if $reserved == 0 {
                        take "ET:" ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                    } else {
                        take "ET:"
                            ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                            ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
                    }
                } elsif self.raw[$base+1] == 0x06 {
                    # OSPF Route Type
                    take "OSPF-Route-Type:"
                        ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                        ~ self.raw[ $base+6 ] ~ ':'
                        ~ self.raw[ $base+7 ];
                } else {
                    take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                        ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                        ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
                }
            } elsif self.raw[$base] == 0x40 {
                # Two-octet AS-Specific Non-transitive
                take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                    ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                    ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
            } elsif self.raw[$base] == 0x41 {
                # Two-octet IPv4-Specific Non-transitive
                take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                    ~ buf8-to-ipv4( self.raw.subbuf( $base+2, 4 ).list ) ~ ':'
                    ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
            } elsif self.raw[$base] == 0x42 {
                # Four-octet AS-specific Non-transitive
                take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                    ~ nuint32( self.raw.subbuf( $base+2, 4 ) ) ~ ':'
                    ~ nuint16( self.raw.subbuf( $base+6, 2 ) );
            } else {
                # Everything Else
                take self.raw[$base] ~ ':' ~ self.raw[$base+1] ~ ':'
                    ~ nuint16( self.raw.subbuf( $base+2, 2 ) ) ~ ':'
                    ~ nuint32( self.raw.subbuf( $base+4, 4 ) );
            }
        }
    }

    return @elems;
}

method Str(-->Str:D) { "Extended-Community=" ~ self.extended-community-list.join(" ") }

# Register path-attribute
INIT { Net::BGP::Path-Attribute.register(Net::BGP::Path-Attribute::Extended-Community) }

=begin pod

=head1 NAME

Net::BGP::Message::Path-Attribute::Extended-Community - BGP Extended-Community Path-Attribute Object

=head1 SYNOPSIS

  use Net::BGP::Path-Attribute::Extended-Community;

  my $cap = Net::BGP::Path-Attribute::Extended-Community.from-raw( $raw );
  # or …
  my $cap = Net::BGP::Path-Attribute::Extended-Community.from-hash(
    %{ Extended-community => 'RT:65000:123456' }
  );

=head1 DESCRIPTION

BGP Path-Attribute Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  This requires elements with keys of
C<path-attribute-code> and C<extended-community>.  Path-Attribute code
should represent the desired path-attribute code.  The extended-community
should be a list of attributes in the format T:S:V1:V2 where T is the
type value (including transitive and IETF bits), S is the subtype value (or
first byte of data where applicable), V1 is the first 16 bits of the value,
and V2 is the last 32 bits of the value.

Optionally, instead of providing T and S,i

=item "ET" can be used to specify an encapsulation type when followed by the type integer.
=item "RT" can be used to specify a route target type with transitive set.
=item "SoO" can be used to specify a route origin.
=item "OSPF-Route-Type" can be used to specify an OSPF route type, when followed by the OSPF area, OSPF route type, and OSPF route options (for example, "OSPF-Route-Type:0:5:1" for an OSPF route in area 0, with a type of 5, and an option indicating a type 1 metric).

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
