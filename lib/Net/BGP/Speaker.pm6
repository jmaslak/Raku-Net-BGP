#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

unit class Net::BGP::Speaker:ver<0.8.2>:auth<cpan:JMASLAK>;

use Net::BGP;
use Net::BGP::CIDR;
use Net::BGP::IP;
use Net::BGP::Speaker::Display;
use Sys::HostAddr;

our subset Asn  of Int where ^2³²;
our subset Port of Int where ^2¹⁶;

has Bool:D                       $.allow-unknown-peers = False;
has Net::BGP                     $.bgp;
has Str:D                        @.communities;
has Net::BGP::Speaker::Display:D $.display = Net::BGP::Speaker::Display.new();
has Str                          $.listen-host where { (! $_.defined) || Net::BGP::IP::ip-valid($_) };
has Port:D                       $.listen-port = 179;
has Asn:D                        $.my-asn is required;
has Net::BGP::IP::ipv4           $.my-bgp-id = Sys::HostAddr.new.guess-ip-for-host('0.0.0.0');
has Str                          $.my-domain;
has Str                          $.my-hostname;
has Net::BGP::CIDR:D             @.wanted-cidr;
has Asn:D                        @.wanted-asn;

submethod TWEAK(
    Bool:D :$colored = False,
    Str    :$asn-filter,
    Str    :$cidr-filter,
) {
    $!display.colored = $colored;

    # Set @!wanted-cidr from string
    if $cidr-filter.defined {
        @!wanted-cidr = gather {
            for $cidr-filter.split(",") -> $cidr {
                take Net::BGP::CIDR.from-str($cidr);
            }
        }
    }

    # Set @!wanted-asn from string
    if $asn-filter.defined {
        @!wanted-asn = gather {
            for $asn-filter.split(",") -> $ele {
                my Asn $asn = Int($ele);
                take $asn;
            }
        }
    }

    if ! $!listen-host.defined { $!listen-host = '0.0.0.0' }

    # Create BGP object
    $!bgp = Net::BGP.new(
        port              => $!listen-port,
        listen-host       => $!listen-host,
        my-asn            => $!my-asn,
        domain            => $!my-domain,
        hostname          => $!my-hostname,
        identifier        => ipv4-to-int($!my-bgp-id),
        add-unknown-peers => $!allow-unknown-peers,
    )
}

# We simulate an attribute here.
multi method colored(                -->Bool:D) { $!display.colored }
multi method colored(Bool:D $colored -->Bool:D) { $!display.colored = $colored }

method peer-add(
    UInt:D :$peer-asn,
    Str:D  :$peer-ip,
    UInt:D :$peer-port,
    Bool:D :$passive,
    Bool:D :$ipv4,
    Bool:D :$ipv6,
    Str    :$md5?,
    UInt:D :$my-hold-time where { $^h == 0 or $^h ~~ 3..65535 } = 60,
) {
    self.bgp.peer-add(
        :$peer-asn,
        :$peer-ip,
        :$peer-port,
        :$passive,
        :$ipv4,
        :$ipv6,
        :$md5,
        :$my-hold-time,
    );
}


=begin pod

=head1 NAME

=head1 SYNOPSIS

    use Net::BGP::Speaker;
    
    $speaker = Net::BGP::Speaker.new(
        allow-unknown-peers => False,
        asn-filter => 65000,
        cidr-filter => "10.0.0.0/16,192.168.0.0/16",
        colored => True,
    )

=head1 TYPES

=head2 our subset Asn of Int:D where ^2³²

Defines a subset covering legal ASN numbers.

=head2 our subset Port of Int:D where ^2¹⁶

Defines a subset covering legal TCP/IP port numbers.

=head1 ATTRIBUTES

=head1 allow-unwanted-peers

Allow unknown peers to be able to connect without having been pre-configured.

=head2 colored

Note that this attribute can't be set directly except at construction time,
however it can be changed via a helper method:

  say "Colored!" if $speaker.colored;
  $speaker.colored(True);  # Make colored

If this is set to true, log messages will be displayed using ANSI-compatible
colored text.

=head2 communities

A list of communities to use when advertising routes.  Communities are
specified in string form (I.E. "65000:1000").

=head2 display

This is a L<Net::BGP::Speaker::Display> object.  It's intended to be
created during object construction, but it can be overriden by a subclass
of this object during construction.

=head2 listen-host

The host to listen on for BGP connections on (defaults to C<0.0.0.0>).  This
is a string.

=head2 listen-port

The port number to listen for BGP connections on (defaults to C<179>).

=head2 my-asn

Our Autonymous System Number.

=head2 my-domain

Domain name of local system, to be sent in FQDN capability during OPEN.
Can be undefined, which will result in L<Net::BGP> attempting to guess
the domain name.

=head2 my-hostname

Hostname of local system, to be sent in FQDN capability during OPEN.
Can be undefined, which will result in L<Net::BGP> attempting to guess
the host name.

=head2 my-asn

Our Autonymous System Number.

=head2 wanted-asn

A list of C<Asn> objects that we are interested in observing.
This can also be set by passing the constructor a comma-seperated string
of ASNs the :asn-filter pseudo-attribute.

=head2 wanted-cidr

A list of L<Net::BGP::CIDR> objects that we are interested in observing.
This can also be set by passing the constructor a comma-seperated string
of CIDRs as the :cidr-filter pseudo-attribute.

=head1 METHODS

=head2 peer-add

  $bgp.peer-add(
      :peer-asn(65001),
      :peer-ip("192.0.2.1"),
      :peer-port(179),
      :passive(False),
      :ipv4(True),
      :ipv6(False),
      :md5($key),
  );

Add a new peer to the BGP server.

Provide the peer information (C<peer-asn>, C<peer-ip>, and C<peer-port>),
along with whether this should be a C<passive> session, whether the
C<ipv4> and C<ipv6> address families should be negotiated, and, if necessary,
an C<md5> key.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitic License 2.0.

=end pod
