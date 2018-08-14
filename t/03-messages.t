use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Message;

subtest 'Parent Class', {
    my $msg = Net::BGP::Message.new();
    ok $msg, "Created BGP Class";
    is $msg.message-type, 'NOOP', 'Message type has proper default';

    done-testing;
};

subtest 'Stop', {
    my $msg = Net::BGP::Message::Stop.new();
    ok $msg, "Created BGP Class";
    is $msg.message-type, 'Stop', 'Proper Stop message';

    done-testing;
};

done-testing;

