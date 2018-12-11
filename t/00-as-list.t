use v6.d;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::AS-List;

my $buf = buf8.new( 1, 2, 9, 8, 7, 6 );
my $aslist = Net::BGP::AS-List.new( :raw($buf), :!asn32 );
is $aslist.ordered,    False,  "(1) ordered";
is $aslist.asn-size,   2,      "(1) asn-size";
is $aslist.asn-count,  2,      "(1) asn-count";
is $aslist.asns.elems, 2,      "(1) elems";
is $aslist.asns[0],    0x0908, "(1) First ASN";
is $aslist.asns[1],    0x0706, "(1) Second ASN";

$buf = buf8.new( 2, 2, 9, 8, 7, 6, 5, 4, 3, 2 );
$aslist = Net::BGP::AS-List.new( :raw($buf), :asn32 );
is $aslist.ordered,    True,       "(2) ordered";
is $aslist.asn-size,   4,          "(2) asn-size";
is $aslist.asn-count,  2,          "(2) asn-count";
is $aslist.asns.elems, 2,          "(2) elems";
is $aslist.asns[0],    0x09080706, "(2) First ASN";
is $aslist.asns[1],    0x05040302, "(2) Second ASN";

$buf = buf8.new( 2, 1, 2, 3, 2, 3, 1, 2, 9, 8, 7, 6, 5, 4, 3, 2 );
my @aslists = Net::BGP::AS-List.as-lists( $buf, True );
is @aslists.elems,  2, "Proper number of AS lists";
is @aslists[0].Str, "{0x02030203}", "First AS Sequence is correct";
is @aslists[1].Str, "\{{0x09080706},{0x05040302}\}", "Second AS Sequence is correct";

done-testing;

