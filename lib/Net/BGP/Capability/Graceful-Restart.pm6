use v6;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::AFI  :ALL;
use Net::BGP::SAFI :ALL;
use Net::BGP::Capability;
use Net::BGP::Capability::Graceful-Restart::Per-AF;
use Net::BGP::Conversions;

use StrictClass;
unit class Net::BGP::Capability::Graceful-Restart:ver<0.1.9>:auth<cpan:JMASLAK>
    is Net::BGP::Capability
    does StrictClass;

# Generic Types
method implemented-capability-code(-->Int) { 64 }
method implemented-capability-name(-->Str) { "Graceful-Restart" }

method capability-name(-->Str:D) { self.implemented-capability-name }

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

method from-raw(buf8:D $raw where $raw.bytes ≥ 2) {
    if $raw[0] ≠  64     { die("Can only build a Graceful-Restart capability"); }
    if $raw[1] <   2     { die("Bad capability length"); }
    if $raw[1] > 254     { die("Bad capability length"); }  # More than 63 pairs (RFC4724.3)
    if ($raw[1] - 2) % 4 { die("Bad capability length"); }

    my $obj = self.bless(:$raw);
    return $obj;
};

method from-hash(%params is copy)  {
    my @REQUIRED = «flags startup-time address-family-flags»;

    %params<flags> //= 0;

    if %params<restart-state>:exists {
        %params<flags> = %params<flags> +& 0x8;
        %params<flags> = %params<flags> +| 0x8 if %params<restart-state>;
        %params<restart-state>:delete;
    }

    if %params<graceful-restart-on-notify>:exists {
        %params<flags> = %params<flags> +& 0x4;
        %params<flags> = %params<flags> +| 0x4 if %params<graceful-restart-on-notify>;
        %params<graceful-restart-on-notify>:delete;
    }

    if %params<capability-name>:exists {
        if %params<capability-name> ne self.implemented-capability-name {
            die "Can only create a {self.implemented-capability-name} capability";
        }
        %params<capability-name>:delete;
    }

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    die "Flags value out of bounds"       unless %params<flags>        ~~ ^(2⁴);
    die "Startup Time value out of bands" unless %params<startup-time> ~~ ^(2¹⁶);

    my $afis = buf8.new;
    for %params<address-family-flags><> -> $afi {
        $afis.append: self.address-family-flags-from-hash($afi);
    }

    my $time-and-flags = (%params<flags> +< 12) + %params<startup-time>;

    my buf8 $capability = buf8.new;
    $capability.append( self.implemented-capability-code );  # Code
    $capability.append( 2 + $afis.bytes );  # Length
    $capability.append( nuint16-buf8( $time-and-flags ) );
    $capability.append( $afis );

    return self.bless(:raw( $capability ));
};

method address-family-flags-from-hash(%params is copy) {
    my @REQUIRED = «afi safi flags»;

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    die "Flags value out of bounds" unless %params<flags> ~~ ^(2¹⁶);

    my buf8 $ret = buf8.new();
    $ret.append( nuint16-buf8(afi-code(~%params<afi>)) );
    $ret.append( safi-code(~%params<safi>) );
    $ret.append( %params<flags> );

    return $ret;
}

method flags(-->Int:D) {
    return ($.raw[2] +> 4);
}

method restart(-->Bool:D) {
    if self.flags +& 0x8 {
        return True;
    } else {
        return False;
    }
}

method graceful-restart-on-notify(-->Bool:D) {
    if self.flags +& 0x4 {
        return True;
    } else {
        return False;
    }
}

method reserved-flags(-->UInt:D) {
    return self.flags +& 0x3;
}

method restart-time(-->UInt:D) {
    return ($.raw[2] * (2⁸) + $.raw[3]) +& 0x0fff;
}

method per-af-flags() { # Returns a list of per-af classes
    my $af-count = ($.raw[1] - 2) / 4;
    my Net::BGP::Capability::Graceful-Restart::Per-AF @ret;

    return @ret unless $af-count;

    for ^$af-count -> $pos {
        my $start = $pos * 4 + 4;
        @ret.push: Net::BGP::Capability::Graceful-Restart::Per-AF.new(
            :afi( $.raw[$start] * (2⁸) + $.raw[$start+1] ),
            :safi( $.raw[$start+2] ),
            :flags( $.raw[$start+3] ),
        );
    }

    return @ret;
}

method Str(-->Str:D) {
    "Graceful-Restart="
        ~ ( self.restart ?? 'RESTART ' !! '' )
        ~ ( self.reserved-flags ?? 'Reserved:' ~ self.reserved-flags ~ ' ' !! '' )
        ~ ( self.graceful-restart-on-notify ?? 'Graceful-Restart-On-Notify ' !! '' )
        ~ self.restart-time ~ "secs"
        ~ (self.per-af-flags.elems ?? ' ' !! '')
        ~ (self.per-af-flags)».Str.join(";");
}

# Register capability
INIT { Net::BGP::Capability.register(Net::BGP::Capability::Graceful-Restart) }

=begin pod

=head1 NAME

Net::BGP::Message::Capability::Graceful-Restart - BGP Graceful-Restart Capability Object

=head1 SYNOPSIS

  use Net::BGP::Capability::Graceful-Restart;

  my $cap = Net::BGP::Capability::Graceful-Restart.from-raw( $raw );
  # or
  my $cap = Net::BGP::Capability::Graceful-Restart.from-hash( %{ } );

=head1 DESCRIPTION

BGP Graceful-Restart Capability Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  This parent class looks only for
the key of C<capability-code>, C<flags> (optional if C<restart> key is present),
C<restart> (optional), C<graceful-restart-on-notify> (optional) and an
C<address-family-flags> array of hashes.  This array of hashes uses the keys
C<afi>, C<safi>, and C<flags> to generate the per-AFI/SAFI flags.

=head1 Methods

=head2 capability-code

Capability code of the object.

=head2 capability-name

The capability name of the object.

=head2 raw

Returns the raw (wire format) data for this capability.

=head2 payload

The raw byte buffer (C<buf8>) corresponding to the RFC definition of C<value>.

=head2 flags

Returns the four bit flag value.

=head2 graceful-restart-on-notify

Returns C<True> or C<False> based on whether the remote end complies with
RFC8538 (with support for graceful restart on receipt of a notify message).

=head2 restart

Returns C<True> or C<False> based on whether the restart flag is set.

=head2 reserved-flags

Returns the value of the three bits of reserved flags.

=head2 restart-time

Returns the value of the peer's BGP startup time.

=head2 per-af-flags

Returns a list of objects, each of which has an C<afi>, C<safi>, C<afi-name>,
C<safi-name>, and C<flags> value.  The C<-name> types are human-decoded strings.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2020 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
