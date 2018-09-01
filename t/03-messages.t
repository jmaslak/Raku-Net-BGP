use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;

subtest 'Command' => {
    subtest 'Parent Class' => {
        my $msg = Net::BGP::Command.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'NOOP', 'Message type has proper default';

        done-testing;
    };

    subtest 'BGP-Message' => {
        my $bgp = Net::BGP::Message::Open.from-hash( {
            :asn(65000),
            :hold-time(0),
            :identifier('1.2.3.4'),
        } );

        my $msg = Net::BGP::Command::BGP-Message.new(
            :connection-id(1),
            :message($bgp),
        );
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'BGP-Message', 'Proper BGP-Message message';
        is $msg.message, $bgp, 'Payload is correct';

        done-testing;
    };

    subtest 'Stop' => {
        my $msg = Net::BGP::Command::Stop.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'Stop', 'Proper Stop message';

        done-testing;
    };

    done-testing;
};

subtest 'Notify' => {
    subtest 'Parent Class' => {
        my $msg = Net::BGP::Notify.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'NOOP', 'Message type has proper default';
        is $msg.is-error, False, 'Message is not an error';

        done-testing;
    };

    subtest 'BGP-Message' => {
        my $bgp = Net::BGP::Message.from-raw( read-message-nohead('t/bgp-messages/open-message.msg') );
        my $msg = Net::BGP::Notify::BGP-Message.new(:message($bgp), :connection-id(22));
        ok $msg, "Created Notify Class";
        is $msg.message-type, 'BGP-Message', 'Message type has proper value';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.is-error, False, 'Message is not an error';
        is $msg.message.message-type, 1, 'BGP message type is correct';
        is $msg.message.message-code, 'OPEN', 'BGP message code is correct';

        done-testing;
    };

    subtest 'Closed-Connection' => {
        my $msg = Net::BGP::Notify::Closed-Connection.new(
            :client-ip('192.0.2.1'),
            :client-port(1500),
            :connection-id(22),
        );
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'Closed-Connection', 'Proper Closed-Connection message';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.client-ip, '192.0.2.1', 'Client IP address';
        is $msg.client-port, 1500, 'Client IP port';
        is $msg.is-error, False, 'Message is not an error';

        done-testing;
    };

    subtest 'New-Connection' => {
        my $msg = Net::BGP::Notify::New-Connection.new(
            :client-ip('192.0.2.1'),
            :client-port(1500),
            :connection-id(22),
        );
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'New-Connection', 'Proper New-Connection message';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.client-ip, '192.0.2.1', 'Client IP address';
        is $msg.client-port, 1500, 'Client IP port';
        is $msg.is-error, False, 'Message is not an error';

        done-testing;
    };

    done-testing;
};

subtest 'Error' => {
    subtest 'Parent Class' => {
        my $msg = Net::BGP::Error.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'NOOP', 'Message type has proper value';
        is $msg.is-error, True, 'Message is an error';
        is $msg.message, 'No-Op', 'Human readable type';

        done-testing;
    };

    subtest 'Bad-Option-Length' => {
        my $msg = Net::BGP::Error::Bad-Option-Length.new(:length(999), :connection-id(22));
        ok $msg, "Created Error Class";
        is $msg.message-type, 'Bad-Option-Length', 'Message type has proper value';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.is-error, True, 'Message is an error';
        is $msg.message, 'Option Length in OPEN is invalid', 'Human readable type';
        is $msg.length, 999, 'Length is valid';

        done-testing;
    };
    subtest 'Length-Too-Short' => {
        my $msg = Net::BGP::Error::Length-Too-Short.new(:length(10), :connection-id(22));
        ok $msg, "Created Error Class";
        is $msg.message-type, 'Length-Too-Short', 'Message type has proper value';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.is-error, True, 'Message is an error';
        is $msg.message, 'Length field in header is impossibly short (RFC4271)', 'Human readable type';
        is $msg.length, 10, 'Length is valid';

        done-testing;
    };

    subtest 'Marker-Format' => {
        my $msg = Net::BGP::Error::Marker-Format.new(:connection-id(22));
        ok $msg, "Created Error Class";
        is $msg.message-type, 'Marker-Format', 'Message type has proper value';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.is-error, True, 'Message is an error';
        is $msg.message, 'Invalid header marker format (RFC4271)', 'Human readable type';

        done-testing;
    };

    subtest 'Unknown-Version' => {
        my $msg = Net::BGP::Error::Unknown-Version.new(:version(3), :connection-id(22));
        ok $msg, "Created Error Class";
        is $msg.message-type, 'Unknown-Version', 'Message type has proper value';
        is $msg.connection-id, 22, 'Connection ID is proper';
        is $msg.is-error, True, 'Message is an error';
        is $msg.message, 'BGP Version in OPEN is not supported', 'Human readable type';
        is $msg.version, 3, 'Version is valid';

        done-testing;
    };
};

done-testing;

sub read-message($filename -->buf8) {
    return slurp $filename, :bin;
}

sub read-message-nohead($filename -->buf8) {
    return buf8.new(read-message($filename)[18..*]);
}

