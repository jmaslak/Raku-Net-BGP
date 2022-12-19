use v6;

#
# Copyright © 2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Capability;

use StrictClass;
unit class Net::BGP::Capability::FQDN:ver<0.9.0>:auth<zef:jmaslak>
    is Net::BGP::Capability
    does StrictClass;

# Generic Types
method implemented-capability-code(-->Int) { 73 }
method implemented-capability-name(-->Str) { "FQDN" }

method capability-name(-->Str:D) { self.implemented-capability-name }

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

method from-raw(buf8:D $raw where $raw.bytes ≥ 4) {
    if $raw[0] ≠ 73 { die("Can only build a FQDN capability"); }
    if $raw[1] ≤  3 { die("Bad capability length"); }

    if $raw.bytes ≠ ($raw[1] + 2) { die("Bad capability length") }

    if $raw[2] > ($raw.bytes - 4) { die("Bad hostname length") }
    if $raw[ $raw[2] + 3 ] > ($raw.bytes - $raw[2] - 4) {
        die("Bad domain name length");
    }

    my $obj = self.bless(:$raw);
    return $obj;
};

method from-hash(%params is copy)  {
    my @REQUIRED = «hostname domain»;

    if %params<capability-code>:exists {
        if %params<capability-code> ≠ 73 {
            die "Can only create a FQDN capability";
        }
        %params<capability-code>:delete;
    }

    if %params<capability-name>:exists {
        if %params<capability-name> ne "FQDN" {
            die "Can only create a FQDN capability";
        }
        %params<capability-name>:delete;
    }

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    my $hostname = %params<hostname>.encode('UTF-8');
    my $domain   = %params<domain>\ .encode('UTF-8');

    if ($hostname.bytes + $domain.bytes) > (255-4) {
        die("FQDN is too long");
    }

    my $payload-len = 2 + $hostname.bytes + $domain.bytes;

    my buf8 $capability = buf8.new();
    $capability.append( 73 );  # Code
    $capability.append( $payload-len );  # Length
    $capability.append( $hostname.bytes );
    $capability.append( $hostname );
    $capability.append( $domain.bytes );
    $capability.append( $domain );

    return self.bless(:raw( $capability ));
};

method hostname(-->Str:D) {
    return '' unless $.raw[2] > 0;
    return $.raw.subbuf(3, $.raw[2]).decode('UTF-8');
}

method domain(-->Str:D) {
    my $pos = 3 + $.raw[2];

    return '' unless $.raw[$pos] > 0;
    return $.raw.subbuf($pos + 1, $.raw[$pos]).decode('UTF-8');
}

method Str(-->Str:D) {
    "FQDN={self.hostname},{self.domain}";
}

# Register capability
INIT { Net::BGP::Capability.register(Net::BGP::Capability::FQDN) }

=begin pod

=head1 NAME

Net::BGP::Message::Capability::FQDN - BGP FQDN Capability Object

=head1 SYNOPSIS

  use Net::BGP::Capability::FQDN;

  my $cap = Net::BGP::Capability::FQDN.from-raw( $raw );
  # or …
  my $cap = Net::BGP::Capability::FQDN.from-hash(
    %{ hostname => 'foo', domain => 'example.com' }
  );

=head1 DESCRIPTION

BGP FQDN Capability Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  This class looks only for
C<capability-code>, C<hostname>, and C<domain>.  Capability code should represent
the desired capability code (73).  Hostname and domain should be a string
containing the payload data.

=head1 Methods

=head2 capability-code

Capability code of the object.

=head2 capability-name

The capability name of the object.

=head2 hostname

The hostname of the object.

=head2 domain

The domain name of the object.

=head2 raw

Returns the raw (wire format) data for this capability.

=head2 payload

The raw byte buffer (C<buf8>) corresponding to the RFC definition of C<value>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2020 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
