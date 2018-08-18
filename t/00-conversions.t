use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;

my byte $b0 = 0;
my byte $b1 = 1;

subtest 'nuint16' => {

    is nuint16(           $b0, $b0 ), 0;
    is nuint16( ($b0,$b0)          ), 0;
    is nuint16( buf8.new(0,0)      ), 0;

    is nuint16(           $b0, $b1 ), 1;
    is nuint16( ($b0,$b1)          ), 1;
    is nuint16( buf8.new(0,1)      ), 1;

    is nuint16(           $b1, $b0 ), 256;
    is nuint16( ($b1,$b0)          ), 256;
    is nuint16( buf8.new(1,0)      ), 256;

    is nuint16(           $b1, $b1 ), 257;
    is nuint16( ($b1,$b1)          ), 257;
    is nuint16( buf8.new(1,1)      ), 257;

    done-testing;
}

subtest 'nunit32' => {
    is nuint32(               $b0, $b0, $b0, $b0 ), 0;
    is nuint32( ($b0,$b0,$b0,$b0)                ), 0;
    is nuint32( buf8.new(0,0,0,0)                ), 0;

    is nuint32(               $b0, $b0, $b0, $b1 ), 1;
    is nuint32( ($b0,$b0,$b0,$b1)                ), 1;
    is nuint32( buf8.new(0,0,0,1)                ), 1;

    is nuint32(               $b0, $b0, $b1, $b0 ), 256;
    is nuint32( ($b0,$b0,$b1,$b0)                ), 256;
    is nuint32( buf8.new(0,0,1,0)                ), 256;

    is nuint32(               $b0, $b1, $b0, $b0 ), 65536;
    is nuint32( ($b0,$b1,$b0,$b0)                ), 65536;
    is nuint32( buf8.new(0,1,0,0)                ), 65536;

    is nuint32(               $b1, $b1, $b1, $b1 ), 16843009;
    is nuint32( ($b1,$b1,$b1,$b1)                ), 16843009;
    is nuint32( buf8.new(1,1,1,1)                ), 16843009;

    done-testing;
}

done-testing;

