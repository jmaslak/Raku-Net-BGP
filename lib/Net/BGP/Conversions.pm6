use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

module Net::BGP::Conversions:ver<0.0.1>:auth<cpan:JMASLAK> {

    multi sub nuint16(@a where @a.elems == 2 --> Int) is export {
        return nuint16(@a[0], @a[1]);
    }
    multi sub nuint16(buf8 $b where $b.bytes == 2 --> Int) is export {
        return nuint16($b[0], $b[1]);
    }
    multi sub nuint16(byte $a, byte $b --> Int) is export {
        return $a × 2⁸ + $b;
    }


    multi sub nuint32(@a where @a.elems == 4 --> Int) is export {
        return nuint32(@a[0], @a[1], @a[2], @a[3]);
    }
    multi sub nuint32(buf8 $b where $b.bytes == 4 --> Int) is export {
        return nuint32($b[0], $b[1], $b[2], $b[3]);
    }
    multi sub nuint32(byte $a, byte $b, byte $c, byte $d --> Int) is export {
        return $a × 2²⁴ + $b × 2¹⁶ + $c × 2⁸ + $d;
    }

};

=begin pod

=head1 NAME

Net::BGP::Conversions - Convert between bytes and integer formats

=head1 SYNOPSIS

  ues Net::BGP::Conversions;

  my $val1 = nuint16(10, 20);
  my $val2 = nuint32(10, 20, 30, 40);

=head1 SUBROUTINES

=head2 nuint16

  my $val1 = nuint16(10, 20);
  my $val2 = nuint16(@array); # Must be a 2 element array
  my $val2 = nuint16($buf);   # Must be a buf8 that is 2 bytes long

Converts the byte values in the parameter to a 16 bit UInt, assuming network
ordering (first byte is MSB).

=head2 nuint32

  my $val1 = nuint32(10, 20, 30, 40);
  my $val2 = nuint32(@array); # Must be a 4 element array
  my $val2 = nuint32($buf);   # Must be a buf8 that is 4 bytes long

Converts the byte values in the parameter to a 32 bit UInt, assuming network
ordering (first byte is MSB).

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

