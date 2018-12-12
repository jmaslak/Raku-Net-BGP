use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

unit class Net::BGP::AS-List:ver<0.0.1>:auth<cpan:JMASLAK>;

use Net::BGP::Conversions;

# Public Attributes
has Bool:D $.asn32 is required;
has buf8:D $.raw   is required where { $^a.bytes ≥ 2 };

method check(-->Bool:D) {
    if $.raw[0] !~~ 1..2 { die("AS type must be 1 or 2") }
    if $.raw.bytes ≠ 2 + self.asn-size * self.asn-count {
        die("Path segment wrong length ({$.raw.bytes} ≠ {2+ self.asn-size * self.asn-count})");
    }

    return True;
}

method ordered(-->Bool:D)  { return ($.raw[0] == 2) }
method asn-size(-->Int:D)  { return $!asn32 ?? 4 !! 2 }
method asn-count(-->Int:D) { return $.raw[1] }

method asns(-->Array[Int:D]) {
    if self.asn-size * self.asn-count + 2 ≠ $!raw.bytes {
        die("AS Path List too short");
    }

    my Int:D @result = (^(self.asn-count)).map: -> $i {
        if $!asn32 {
            nuint32( buf8.new($!raw.subbuf(2+$i*4, 4)) );
        } else {
            nuint16( $!raw[2+$i*2], $!raw[3+$i*2] );
        }
    };

   return @result;
} 

method Str(-->Str:D) {
    if ! self.defined { return "Net::BGP::AS-List" }

    my $sep   = self.ordered ?? " " !! ",";
    my $start = self.ordered ?? ""  !! '{';
    my $end   = self.ordered ?? ""  !! '}';
    
    return $start ~ self.asns.join($sep) ~ $end;
}

method from-str(Str:D $str, Bool:D $asn32 -->Array[Net::BGP::AS-List:D]) {
    grammar AS-Path {
        token TOP {
            ^ \s* <AS-LIST> +% \s+ \s* $
            { make $<AS-LIST>».made }
        }

        token AS-LIST {
            | <AS-Set>
                { make $<AS-Set>.made }


            | <AS-Sequence>
                { make $<AS-Sequence>.made }
        }

        token AS-Set {
            '{' \s* <ASN> +% [[\s*] ',' [\s*]] \s* '}'
                { make Net::BGP::AS-List.from-list(False, $<ASN>».Int, $asn32) }
        }

        token AS-Sequence {
            <ASN> +% \s+
                { make Net::BGP::AS-List.from-list(True, $<ASN>».Int, $asn32) }
        }

        token ASN          { <[ 0 .. 9 ]>+ }
    }

    my $match = AS-Path.parse($str);
    my Net::BGP::AS-List:D @asns = $match.made;
    
    return @asns;
}

# Internal only for now, not documented
method from-list(
    Bool:D $ordered,
    @list,
    Bool:D $asn32
    -->Net::BGP::AS-List:D
) {
    if @list.elems > 255 { die("Too many ASNs in path element") }

    my $buf = buf8.new;
    $buf.append( $ordered ?? 2 !! 1 );
    $buf.append( @list.elems );

    for @list -> $ele {
        if  $asn32 { die unless $ele ~~ ^(2³²) };
        if !$asn32 { die unless $ele ~~ ^(2¹⁶) };

        $buf.append( $asn32 ?? nuint32-buf8($ele) !! nuint16-buf8($ele) );
    }

    return Net::BGP::AS-List.new(:raw($buf), :$asn32);
}

method as-lists(
    buf8:D $raw where { $^a.bytes ≥ 2 },
    Bool:D $asn32
    -->Array[Net::BGP::AS-List:D]
) {
    my $aslen = $asn32 ?? 4 !! 2;

    my $pos = 0;
    my Net::BGP::AS-List:D @return = gather {
        while $pos < $raw.bytes {
            my $size = $raw[$pos+1] * $aslen;
            if ($pos+2+$size) > $raw.bytes { die("Too few bytes") }

            take Net::BGP::AS-List.new( :raw( $raw.subbuf($pos, 2+$size) ), :$asn32 );

            $pos += 2 + $size;
        }
    }

    return @return;
}

=begin pod

=head1 NAME

Net::BGP::AS-List - AS-List Handling Functionality

=head1 SYNOPSIS

  use Net::BGP::AS-List;

  my $aslist = IP::BGP::AS-List( :raw($raw), :asn32 );

=head1 ATTRIBUTES

=head2 asn32

If C<True>, parse the C<AS-List> using 4 byte ASNs.  Otherwise, use 2 byte
ASNs.

=head2 raw

A C<buf8> containing the raw packed AS-Set or AS-Sequence.

=head1 METHODS

method check(-->Bool:D) {
    if $.raw !~~ 1..2 { die("AS type must be 1 or 2" }
    if $.raw.bytes ≠ 2 + self.asn-size * self.asn-count {
        die("Path segment wrong length");
    }
    return True;
}

method ordered(-->Bool:D)  { return ($.raw[0] == 2) }
method asn-size(-->Int:D)  { return $!asn32 ?? 4 !! 2 }
method asn-count(-->Int:D) { return $.raw[1] }

method asns(-->Array[Int:D]) {

=head2 check

Returns true if C<raw> processes correctly, otherwise throws an exception.

=head2 asn-size

Returns 4 if C<asn32> is set to C<True>, 2 otherwise.

=head2 asn-count

Returns the number of ASNs present in the packed raw structure.

=head2 asns

Returns a list of the ASNs in this AS list.

=head2 Str

Returns a string representation of the ASNs.

=head2 as-lists

Returns the AS-Sequence and AS-Sets in the packed binary buffer, as would be
representated in an AS-Path BGP attribute.

=head2 from-str

Takes an AS Path string and converts it to an array of AS-List objects.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

