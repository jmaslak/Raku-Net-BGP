use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

module Net::BGP::IP:ver<0.0.1>:auth<cpan:JMASLAK> {
    # IPv4
    #
    #

    our @octet = ^256;
    our subset ipv4 of Str where / ^ @octet**4 % '.' $ /;
    our subset ipv4_int of UInt where * < 2³²;

    our sub ipv4-to-int(ipv4:D $ip -->uint32) is export {
        my uint32 $ipval = 0;
        for $ip.split('.') -> Int(Str) $part {
            $ipval = $ipval +< 8 + $part;
        }

        return $ipval;
    }

    our sub ipv4-to-buf8(ipv4:D $ip -->buf8:D) is export {
        return buf8.new( $ip.split('.')».Int );
    }

    our sub int-to-ipv4(ipv4_int:D $i -->Str:D) is export {
        my uint32 $ip = $i;
        return join('.', $ip +> 24, $ip +> 16 +& 255, $ip +> 8 +& 255, $ip +& 255);
    }

    # IPv6
    #
    #

    # Take from Rosetacode
    #   https://rosettacode.org/wiki/Parse_an_IP_Address#Perl_6
    grammar IPv6 {
        token TOP { ^ <IPv6Addr> $ }

        token IPv6Addr {
            | <h16> +% ':' <?{ $<h16> == 8}>
                { @*by16 = @$<h16> }

            | [ (<h16>) +% ':']? '::' [ (<h16>) +% ':' ]? <?{ @$0 + @$1 ≤ 8 }>
                { @*by16 = |@$0, |('0' xx 8 - (@$0 + @$1)), |@$1; }
        }

        token h16 { (<:hexdigit>+) <?{ @$0 ≤ 4 }> }
    }

    # Need to define @*by16 to use the IPv6.parse() routine
    our subset ipv6 of Str where { my @*by16; IPv6.parse($_) };
    our subset ipv6_int of UInt where * < 2¹²⁸;

    our sub ipv6-to-int(ipv6:D $ip -->ipv6_int) is export {
        my @*by16;
        IPv6.parse($ip);
        return :16(@*by16.map({:16(~$_)})».fmt("%04x").join);
    }

    our sub ipv6-to-buf8(
        ipv6:D $ip,
        Int :$bits? = 128
        -->buf8:D
    ) is export {
        my $bytes = (($bits + 7) / 8).Int;
        my @storage;

        my $int = ipv6-to-int($ip);
        $int = $int +> (128-$bits) +< (128-$bits);

        for ^16 -> $byte {
            @storage.unshift($int +& 255);
            $int = $int +> 8;
        }

        return buf8.new( @storage[^$bytes] );
    }

    our sub buf8-to-ipv6(
        buf8:D $buf,
        Int :$bits? = 128
        --> ipv6:D
    ) is export {
        my $bytes = (($bits + 7) / 8).Int;
        if $buf.bytes ≠ $bytes {
            die("buf8-to-ipv6 called with wrong length buffer ($bytes ≠ {$buf.bytes})");
        }

        my $int = 0;
        for ^16 -> $byte {
            $int  = $int +< 8;
            $int += $buf[$byte] unless $byte ≥ $bytes;
        }
        $int = $int +> (128-$bits) +< (128-$bits);

        return int-to-ipv6($int);
    }

    our sub int-to-ipv6(ipv6_int:D $i -->ipv6:D) is export {
        return ipv6-compact($i.fmt("%032x").comb(4).join(':'));
    }

    our sub ipv6-expand(ipv6:D $ip -->ipv6:D) is export {
        my @*by16;
        IPv6.parse($ip);
        return @*by16.map({:16(~$_)})».fmt("%04x").join(':');
    }

    our sub ipv6-compact(ipv6:D $ip -->ipv6:D) is export {
        my @*by16;
        IPv6.parse($ip);
        my $compact = @*by16.map({:16(~$_)})».fmt("%x").join(':');

        # This looks weird - basically we try matching from most to
        # least.
        if $compact ~~ s/^ '0:0:0:0:0:0:0:0' $/::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0:0:0:0:0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0:0:0:0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0:0:0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0:0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0:0' [ ':' | $ ] /::/ {
        } elsif $compact ~~ s/ [ ^ || ':' ] '0' [ ':' | $ ] /::/ {
        }

        return $compact;
    }

    our subset ipv4_as_ipv6 of Str where m:i/ ^ '::ffff:' @octet**4 % '.' $ /;

    sub ip-cannonical(Str:D $ip -->Str) is export {
        state %cached;

        return %cached{$ip} || ( %cached{$ip} = _ip-cannonical($ip) );
    }

    multi _ip-cannonical(ipv6:D $ip -->Str) {
        return ipv6-compact($ip);
    }
    multi _ip-cannonical(ipv4:D $ip -->Str) {
        return $ip;
    }
    multi _ip-cannonical(ipv4_as_ipv6:D $ip -->Str) {
        return S:i/^ '::ffff:' // given $ip;
    }

    our proto ip-valid(Str:D $ip -->Bool) is export {*};

    multi ip-valid(ipv6:D $ip         -->Bool) { True }
    multi ip-valid(ipv4:D $ip         -->Bool) { True }
    multi ip-valid(ipv4_as_ipv6:D $ip -->Bool) { True }
    multi ip-valid(Str:D $ip          -->Bool) { False }
};

=begin pod

=head1 NAME

Net::BGP::IP - IP Address Handling Functionality

=head1 SYNOPSIS

=head2 IPv4

  use Net::BGP::IP;

  my $ip = int-to-ipv4(1000);         # Converts 1000 to an IPv4 string
  my $int = ipv4-to-int('192.0.2.4'); # Converts to an integer
  
  # Returns 192.0.2.1
  my $cannonical = ip-cannonical('192.0.2.'1);
  my $cannonical = ip-cannonical('::ffff:192.0.2.'1);

=head2 IPv6    

  use Net::BGP::IP;

  # Returns 2001:db8::1
  my $ip = int-to-ipv6(42540766411282592856903984951653826561); # 2001:db8::1

  # Returns the integer value of 2001:db8::1
  my $int = ipv6-to-int('2001:db8::1');

  # Will return: 2001:0db8:0000:0000:0000:0000:0000:0000
  my $expanded = ipv6-expand('2001:db8::1');

  # Will return 2001:db8::1
  my $compact = ipv6-compact('2001:0db8:0:000:0::01');

  # Returns 2001:db8::1
  my $cannonical = ip-cannonical('2001:0db8:0::0:1');

=head1 SUBROUTINES

=head2 int-to-ipv4

Converts an integer into a string representation of an IPv4 address.

=head2 ipv4-to-int

Converts an IPv4 string into an integer.

=head2 ipv4-to-buf8

Converts an IPv4 string into a buf8 object (in network byte order).

=head2 int-to-ipv6

Converts an integer into a string representation of an IPv6 address.

=head2 ipv6-to-int

Converts an IPv6 string into an integer.

=head2 ipv6-to-buf8

Converts an IPv6 string into a buf8 object (in network byte order).

=head2 ipv6-expand

Expands an IPv6 address by expanding "::" and adding leading zeros.

=head2 ipv6-compact

Produces the shortest possible string representation of an IPv6 address.

=head2 ip-cannonical

Returns the shortest possible string representation of an IPv4 or IPv6
address.

=head2 ip-valid

Returns true if the IP address is a valid IPv4 or IPv6 address.

=head1 IPv4 

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

