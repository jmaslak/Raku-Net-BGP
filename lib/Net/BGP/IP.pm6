use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

module Net::BGP::IP:ver<0.0.1>:auth<cpan:JMASLAK> {

    our @octet = ^256;
    our subset ipv4_int of UInt where * < 2³²;
    our subset ipv4 of Str where / ^ @octet**4 % '.' $ /;

    our sub ipv4-to-int(ipv4:D $ip) is export { # XXX We need to handle invalid IPs
        my int $ipval = 0;
        for $ip.split('.') -> Int(Str) $part {
            $ipval = $ipval +< 8 + $part;
        }

        return $ipval;
    }

    our sub int-to-ipv4(ipv4_int:D $i) is export {
        my uint32 $ip = $i;
        return join('.', $ip +> 24, $ip +> 16 +& 255, $ip +> 8 +& 255, $ip +& 255);
    }
};

=begin pod

=head1 NAME

Net::BGP::IP - IP Address Handling Functionality

=head1 SYNOPSIS

  ues Net::BGP::IP;

  my $ip = int-to-ipv4(1000);       # Converts 1000 to an IPv4 string
  my $int = ipv4-to-int('1.2.3.4'); # Converts to an integer

=head1 SUBROUTINES

=head2 int-to-ipv4

Converts an integer into a string representation of an IPv4 address.

=head2 ipv4-to-int

Converts an IPv4 string into an integer.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

