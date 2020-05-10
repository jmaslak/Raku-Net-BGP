use v6.c;
use Test;

#
# Copyright © 2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Path-Attribute;
use Net::BGP::Message::Update;

subtest 'Extended-Community' => {
    my @route-type = (
        'RT:1:2',
        'RT:100001:11',
        'RT:4.3.2.1:21',
        'SoO:1:1',
        'SoO:200002:12',
        'SoO:40.30.20.10:210',
        'OSPF-Route-Type:1000000:5:1',
    );

    my $pa = Net::BGP::Path-Attribute.from-hash(
        %{
            path-attribute-name => 'Extended-Community',
            extended-community  => @route-type,
        },
        :asn32(True),
    );

    ok $pa, "Created Path Attribute";
    ok $pa ~~ Net::BGP::Path-Attribute::Extended-Community,
        "From Hash capability correct";

    my $pa2 = Net::BGP::Path-Attribute.from-raw( $pa.raw, :asn32(True) );
    ok $pa2 ~~ Net::BGP::Path-Attribute::Extended-Community,
        "From RAW capability correct";

    is $pa.extended-community-list, @route-type, "Route type is correct";

    done-testing;
}

done-testing;

