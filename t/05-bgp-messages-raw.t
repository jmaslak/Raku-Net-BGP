use v6.c;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::Message;

subtest 'Generic', {
    my $bgp = Net::BGP::Message.from-raw( read-message('noop-message') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-code, 0, 'Message type is correct';
    is $bgp.message-name, '0', 'Message code is correct';
    ok check-list($bgp.raw, read-message('noop-message')), 'Message value correct';;

    done-testing;
};

subtest 'Open Message', {
    my $bgp = Net::BGP::Message.from-raw( read-message('open-message') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-code, 1, 'Message type is correct';
    is $bgp.message-name, 'OPEN', 'Message code is correct';
    is $bgp.version, 4, 'BGP version is correct';
    is $bgp.asn, :16('1020'), 'ASN is correct';
    is $bgp.hold-time, 3, 'Hold time is correct';
    is $bgp.identifier, :16('01020304'), 'BGP identifier is correct';
    ok check-list($bgp.raw, read-message('open-message')), 'Message value correct';;

    done-testing;
};

subtest 'Open Message w/ Capabilities', {
    my $bgp = Net::BGP::Message.from-raw( read-message('open-message-capabilities') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-code, 1, 'Message type is correct';
    is $bgp.message-name, 'OPEN', 'Message code is correct';
    is $bgp.version, 4, 'BGP version is correct';
    is $bgp.asn, :16('1020'), 'ASN is correct';
    is $bgp.hold-time, 3, 'Hold time is correct';
    is $bgp.identifier, :16('01020304'), 'BGP identifier is correct';
    is $bgp.parameters.elems, 1, "Proper number of Parameters";
    ok $bgp.parameters[0] ~~ Net::BGP::Parameter::Capabilities, "Parameter is a Capabilitiy";
    is $bgp.parameters[0].parameter-code, 2, "Parameter has proper code";
    is $bgp.parameters[0].parameter-name, "Capabilities", "Parameter has proper name";

    my $caps = $bgp.parameters[0].capabilities;
    is $caps.elems, 3, "Proper number of capabilities";

    ok $caps[0] ~~ Net::BGP::Capability::Route-Refresh, "Capability¹ is proper type";
    is $caps[0].capability-code, 2,                     "Capability¹ has proper code";
    is $caps[0].capability-name, "Route-Refresh",       "Capability¹ has proper name";

    ok $caps[1] ~~ Net::BGP::Capability::ASN32, "Capability² is proper type";
    is $caps[1].capability-code, 65,            "Capability² has proper code";
    is $caps[1].capability-name, "ASN32",       "Capability² has proper name";
    is $caps[1].asn, :16('12345678'),           "Capability² has proper asn";

    ok $caps[2] ~~ Net::BGP::Capability::MPBGP,   "Capability³ is proper type";
    is $caps[2].capability-code, 1,               "Capability³ has proper code";
    is $caps[2].capability-name, "MPBGP",         "Capability³ has proper name";
    is $caps[2].afi,             "IP",            "Capability³ has proper afi";
    is $caps[2].safi,            "unicast",       "Capability³ has proper safi";
    is $caps[2].reserved,        0,               "Capability³ has proper reserved";

    ok check-list($bgp.raw, read-message('open-message-capabilities')), 'Message value correct';;

    done-testing;
};

subtest 'Keep-Alive Message', {
    my $bgp = Net::BGP::Message.from-raw( read-message('keep-alive') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-code, 4, 'Message type is correct';
    is $bgp.message-name, 'KEEP-ALIVE', 'Message code is correct';
    ok check-list($bgp.raw, read-message('keep-alive')), 'Message value correct';;

    done-testing;
};

subtest 'Update Message (ASN16)', {
    my $bgp = Net::BGP::Message.from-raw( read-message('update-asn16') );
    ok defined($bgp), "BGP message is defined";
    ok $bgp ~~ Net::BGP::Message::Update, "BGP message is proper type";
    is $bgp.message-code, 2, 'Message type is correct';
    is $bgp.message-name, 'UPDATE', 'Message code is correct';

    is $bgp.withdrawn.elems, 3, "Proper number of withdrawn prefixes";
    is $bgp.withdrawn[0], '0.0.0.0/0',        "Withdrawn 1 correct";
    is $bgp.withdrawn[1], '192.168.150.0/24', "Withdrawn 2 correct";
    is $bgp.withdrawn[2], '192.168.150.1/32', "Withdrawn 3 correct";

    is $bgp.path-attributes.elems, 1, "Proper number of path elements";
    ok $bgp.path-attributes[0] ~~ Net::BGP::Path-Attribute::Origin,
        "Path Attribute 1 Proper Type";
    is $bgp.path-attributes[0].origin, '?', "Path Attribute 1 Proper Type";

    is $bgp.nlri.elems, 3, "Proper number of NLRI prefixes";
    is $bgp.nlri[0], '10.0.0.0/8',       "NLRI 1 correct";
    is $bgp.nlri[1], '192.168.151.0/24', "NLRI 1 correct";
    is $bgp.nlri[2], '192.168.151.1/32', "NLRI 1 correct";

    ok check-list($bgp.raw, read-message('update-asn16')), 'Message value correct';;

    done-testing;
};

done-testing;

sub read-message($filename) {
    buf8.new( slurp("t/bgp-messages/$filename.msg", :bin)[18..*] ); # Strip header
}

sub check-list($a, $b -->Bool) {
    if $a.elems != $b.elems { return False; }
    return [&&] $a.values Z== $b.values;
}

