use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Path-Attribute;

unit class Net::BGP::Path-Attribute::MP-NLRI:ver<0.0.0>:auth<cpan:JMASLAK>
is Net::BGP::Path-Attribute;

use Net::BGP::AFI :ALL;
use Net::BGP::Conversions;
use Net::BGP::IP;
use Net::BGP::SAFI :ALL;

# MP-NLRI Types
method implemented-path-attribute-code(-->Int) { 14 }
method implemented-path-attribute-name(-->Str) { "MP-NLRI" }

method path-attribute-name(-->Str:D) { "MP-NLRI" }

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

method from-raw(buf8:D $raw where $raw.bytes ≥ 7, :$asn32) {
    if ! $raw[0] +& 0x80 { die("Optional flag must be set on MP-NLRI attribute") }
    if   $raw[0] +& 0x40 { die("Transitive flag not valid on MP-NLRI attribute") }
    if   $raw[0] +& 0x20 { die("Partial flag not valid on MP-NLRI attribute") }

    if $raw[1] ≠ 14 { die("Can only create a MP-NLRI attribute") }

    my $len;
    if $raw[0] +& 0x10 {
        $len = nuint16($raw[2], $raw[3]);
        if $raw.bytes ≠ ($len + 4) { die("MP-NLRI attribute has bad payload length") }
    } else {
        $len = $raw[2];
        if $raw.bytes ≠ ($len + 3) { die("MP-NLRI attribute has bad payload length") }
    }

    if $len < 2 { die("MP-NLRI attribute too short") }

    my $obj = self.bless(:$raw, :$asn32);
    return $obj;
};

method from-hash(%params is copy, Bool:D :$asn32)  {
    my @REQUIRED = «cluster-list»;

    # Remove path attributes
    if %params<path-attribute-code>:exists {
        if %params<path-attribute-code> ≠ 10 {
            die("Can only create an MP-NLRI attribute");
        }
        %params<path-attribute-code>:delete;
    }
    if %params<path-attribute-name>:exists {
        if %params<path-attribute-name> ≠ 'MP-NLRI' {
            die("Can only create an MP-NLRI attribute");
        }
        %params<path-attribute-name>:delete;
    }

    my @clusters = %params<cluster-list>.split(/\s+/);
    
    my $cluster-list-buf = buf8.new;
    for @clusters -> $cluster { $cluster-list-buf.append: ipv4-to-buf8($cluster) }

    # Check to make sure attributes are correct
    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    if $cluster-list-buf.bytes > 65535 { die "Value is longer than 65535 bytes" }

    my $flag = 0x80;  # Optional, Non-Transitive
    if $cluster-list-buf.bytes > 255 { $flag += 0x10 }  # Extended length?

    my buf8 $path-attribute = buf8.new();
    $path-attribute.append( $flag );
    $path-attribute.append( 10 );

    if $cluster-list-buf.bytes > 255 {
        $path-attribute.append( nuint16-buf8( $cluster-list-buf.bytes ) );
    } else {
        $path-attribute.append( $cluster-list-buf.bytes );
    }
    $path-attribute.append( $cluster-list-buf );

    return self.bless( :raw( $path-attribute ), :$asn32 );
};

method afi(-->Str:D) {
    ### XXX Should do length check
    return afi-name( nuint16(self.data[0], self.data[1]) );
}

method safi(-->Str:D) {
    ### XXX Should do length check
    return safi-name( self.data[2] );
}

method reserved(-->Int:D) {
    ### XXX Should do length check
    return self.data[ 4 + self.data[3] ];
}

method next-hop-start(-->Int:D) { 4 }
method nlri-start(-->Int:D) {
    ### XXX Should do length check
    return 5 + self.data[3];
}

method next-hop-global(-->Str:D) {
    ### XXX Should do length check
    my $buf = buf8.new: self.data.subbuf( self.next-hop-start, self.data[3] );

    # We go different ways based on AFI - this might make sense to
    # subclass. XXX
    # We also don't handle IPv4 in MP-NLRIs because, in theory, nobody
    # does that.  I'll probably be proven wrong.
    if self.afi eq 'IPv6' and self.safi eq 'unicast' {
        if self.data[3] == 16 {
            # Has a global unicast address only
            return buf8-to-ipv6($buf);
        } elsif self.data[3] == 32 {
            # Has a local and a global unicast address
            return buf8-to-ipv6($buf.subbuf(0,16));
        } else {
            die("Invalid IPv6 next-hop length ({self.data[3]})");
        }
    } elsif self.afi eq 'L2VPN' and self.safi eq 'VPLS' {
        if self.data[3] ≠ 4 { die("Invalid VPLS next hop length") }
        return int-to-ipv4(nuint32($buf));
    } else {
        return $buf».fmt("%02x").join;
    }
}

method next-hop-local(-->Str) {
    ### XXX Should do length check
    my $buf = buf8.new: self.data.subbuf( self.next-hop-start, self.data[3] );

    # We go different ways based on AFI - this might make sense to
    # subclass. XXX
    # We also don't handle IPv4 in MP-NLRIs because, in theory, nobody
    # does that.  I'll probably be proven wrong.
    if self.afi eq 'IPv6' and self.safi eq 'unicast' {
        if self.data[3] == 16 {
            # Has a global unicast address only
            return Str;
        } elsif self.data[3] == 32 {
            # Has a local and a global unicast address
            return buf8-to-ipv6($buf.subbuf(16));
        } else {
            die("Invalid IPv6 next-hop length ({self.data[3]})");
        }
    } else {
        return Str;
    }
}

method nlri(-->Array[Str:D]) {
    ### XXX Should do length check
    my $buf = buf8.new: self.data.subbuf( self.nlri-start );
    my Str:D @return;

    # We go different ways based on AFI - this might make sense to
    # subclass. XXX
    # We also don't handle IPv4 in MP-NLRIs because, in theory, nobody
    # does that.  I'll probably be proven wrong.
    if self.afi eq 'IPv6' and self.safi eq 'unicast' {
        while $buf.bytes > 0 {
            my $bits  = $buf[0];
            my $bytes = (($bits + 7) / 8).Int;
            if $buf.bytes < ($bytes+1) {
                die("Invalid length of NLRI information {$buf.bytes} ≠ $bytes");
            }

            @return.push: buf8-to-ipv6($buf.subbuf(1, $bytes), :$bits) ~ "/" ~ $bits;
            $buf = $buf.subbuf($bytes+1);
        }
    } else {
        @return.push: $buf».fmt("%02x").join;
    }
    return @return;
}

method Str(-->Str:D) {
    "MP-NLRI={ self.afi }/{self.safi } {self.nlri.join(" ")} via { self.next-hop-global }";
}

# Register path-attribute
INIT { Net::BGP::Path-Attribute.register(Net::BGP::Path-Attribute::MP-NLRI) }

=begin pod

=head1 NAME

Net::BGP::Message::Path-Attribute::MP-NLRI - BGP MP-NLRI Path-Attribute Object

=head1 SYNOPSIS

  use Net::BGP::Path-Attribute::MP-NLRI;

  my $cap = Net::BGP::Path-Attribute::MP-NLRI.from-raw( $raw );
  # or …
  my $cap = Net::BGP::Path-Attribute::MP-NLRI.from-hash(
    cluster-list => '192.0.2.1 192.0.2.2'
  );

=head1 DESCRIPTION

BGP MP-NLRI Path-Attribute Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  Thakes a hash with a single key,
C<cluster-list>, a string that contains space-seperated human-readable IP
addresses.

=head1 Methods

=head2 path-attribute-code

Capability code of the object.

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

=head2 cluster-list

Returns an array of strings representing each cluster member in the cluster
list.

=head2 data-length

The length of the attribute's data.

=head2 data

This returns a C<buf8> containing the data in the attribute.

=head2 raw

Returns the raw (wire format) data for this path-attribute.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
