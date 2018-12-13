use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

unit class Net::BGP::CIDR:ver<0.0.1>:auth<cpan:JMASLAK>;

use Net::BGP::IP;

# Public Attributes
has UInt:D $.prefix-int32  is required where ^(2³²);
has UInt:D $.prefix-length is required where ^33;

# Private
has Str $!cached-str;

method from-int(UInt() $ip where ^(2³²), UInt() $len where ^33) {
    return self.bless(:prefix-int32($ip), :prefix-length($len));
}

method from-str(Str:D $ip) {
    my @parts = $ip.split('/');
    if @parts.elems ≠ 2 { die("Invalid CIDR"); }

    return self.from-int(ipv4-to-int(@parts[0]), @parts[1].Int);
}

method packed-to-array(buf8:D $buf -->Array[Net::BGP::CIDR:D]) {
     my Net::BGP::CIDR:D @nlri = gather {
        while $buf.bytes {
            my $len = $buf[0];
            if $len > 32 { die("Pack length too long"); }

            my $bytes = (($len+7) / 8).truncate;
            if $buf.bytes < (1 + $bytes) { die("Pack payload too short") }

            my uint32 $ip = 0;
            if ($bytes > 0) { $ip += $buf[1] +< 24; }
            if ($bytes > 1) { $ip += $buf[2] +< 16; }
            if ($bytes > 2) { $ip += $buf[3] +< 8; }
            if ($bytes > 3) { $ip += $buf[4]; }

            $ip = $ip +> (32 - $len) +< (32 - $len);  # Zero any trailing bits
            take self.from-int($ip, $len);

            $buf.splice: 0, $bytes+1, ();
        }
    }

    return @nlri;
}

method to-packed(-->buf8:D) {
    my int32 $ip = $!prefix-int32 +> (32 - $!prefix-length);
    $ip = $ip +< (32 - $!prefix-length);

    my $buf = buf8.new;

    $buf.append: $!prefix-length;
    $buf.append(  $ip +> 24        ) if $!prefix-length >  0;
    $buf.append( ($ip +> 16) % 256 ) if $!prefix-length >  8;
    $buf.append( ($ip +>  8) % 256 ) if $!prefix-length > 16;
    $buf.append(  $ip        % 256 ) if $!prefix-length > 24;

    return $buf;
}

method str-to-packed(Str:D $ip -->buf8:D) { return self.from-str($ip).to-packed }

method Str(-->Str:D) {
    if ! self.defined { return "Net::BGP::CIDR" }
    return $!cached-str if $!cached-str.defined;

    $!cached-str = int-to-ipv4($!prefix-int32) ~ "/$!prefix-length"
}

=begin pod

=head1 NAME

Net::BGP::CIDR - IPv4 CIDR Handling Functionality

=head1 SYNOPSIS

  use Net::BGP::CIDR;

  my $ip1 = IP::BGP::CIDR->from-str('192.0.2.0/24');
  my $ip2 = IP::BGP::CIDR->from-int(0, 0);
  
  say $ip1;

=head1 ATTRIBUTES

=head2 prefix-int32

The integer value of the prefix address.

=head2 prefix-length

The integer value of the prefix length.

method packed-to-array

Takes a "packed" buffer of length + prefix and converts it into an array of
C<Net::BGP::CIDR> objects.  These "packed" buffers are common in BGP structures.

method to-packed

Takes a C<Net::BGP::CIDR> object and produces a packed representation.

=head1 METHODS

=head2 from-int

Converts an integer prefix and integer length into a CIDR object.

=head2 from-str

Converts a CIDR in format C<0.1.2.3/4> into a CIDR object.

=head2 Str

Returns a string representation of a CIDR object.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

