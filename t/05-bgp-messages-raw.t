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
    is $bgp.message-type, 0, 'Message type is correct';
    is $bgp.message-code, '0', 'Message code is correct';
    ok check-list($bgp.raw, read-message('noop-message')), 'Message value correct';;

    done-testing;
};

subtest 'Open Message', {
    my $bgp = Net::BGP::Message.from-raw( read-message('open-message') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-type, 1, 'Message type is correct';
    is $bgp.message-code, 'OPEN', 'Message code is correct';
    is $bgp.version, 4, 'BGP version is correct';
    is $bgp.asn, :16('1020'), 'ASN is correct';
    is $bgp.hold-time, 3, 'Hold time is correct';
    is $bgp.identifier, :16('01020304'), 'BGP identifier is correct';
    ok check-list($bgp.raw, read-message('open-message')), 'Message value correct';;

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

