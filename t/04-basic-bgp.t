use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;

subtest 'Valid', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';
        is $cr.connection-id, 0, 'Connection ID is as expected';

        $client.write( read-message('t/bgp-messages/noop-message.msg') );

        my $cr-bgp = $uc.receive;
        is $cr-bgp.message-type, 'BGP-Message', 'BGP message type is as expected';
        is $cr-bgp.is-error, False, 'Is not an error';
        is $cr-bgp.message.message-type, 0, 'BGP Message is proper type';
        is $cr-bgp.connection-id, 0, 'BGP Message connection ID is as expected';

        my $open = Net::BGP::Message::Open.from-hash( {
            :asn(65000),
            :hold-time(0),
            :identifier('1.2.3.4'),
        } );
        $bgp.send-bgp($cr-bgp.connection-id, $open);

        my $get = $client.recv(:bin);
        ok check-list($get.subbuf(18), $open.raw), "BGP message sent properly";

        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Closed-Connection', 'Close message type is as expected';
        is $cr-bad.is-error, False, 'Is not an error';
        is $cr-bad.connection-id, 0, 'Close message connection ID is as expected';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'invalid-marker', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-marker.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Marker-Format', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'invalid-length-short', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-length-short.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Length-Too-Short', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'invalid-length-long', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-length-long.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Length-Too-Long', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'invalid-version', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-version.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Unknown-Version', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'bad-option-length [1]', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-option-len-in-open-1.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Bad-Option-Length', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        is $cr-bad.length, 1, 'Length == 1';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'bad-option-length [3]', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/test-invalid-option-len-in-open-3.msg') );
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Bad-Option-Length', 'Error message type is as expected';
        is $cr-bad.is-error, True, 'Is an error';
        is $cr-bad.length, 3, 'Length == 3';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

subtest 'OPEN', {
    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
        my $uc = $bgp.user-channel;
        my $cr = $uc.receive;
        is $cr.message-type, 'New-Connection', 'Message type is as expected';

        $client.write( read-message('t/bgp-messages/open-message.msg') );
        
        my $cr-bgp = $uc.receive;
        is $cr-bgp.message-type, 'BGP-Message', 'BGP message type is as expected';
        is $cr-bgp.is-error, False, 'Is not an error';
        is $cr-bgp.message.message-type, 1, 'BGP Message is proper type';
        is $cr-bgp.message.option-len, 0, 'Option length is zero';
        is $cr-bgp.message.option-len, $cr-bgp.message.option.bytes, 'Option bytes = len';
        
        $client.close();

        my $cr-bad = $uc.receive;
        is $cr-bad.message-type, 'Closed-Connection', 'Close message type is as expected';
        is $cr-bad.is-error, False, 'Is not an error';
        
        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

done-testing;

sub read-message($filename) {
    return slurp $filename, :bin;
}

sub check-compiler-version(--> Bool) {
    # We don't know about anything but Rakudo, so we assume it works.
    if ($*PERL.compiler.name ne 'rakudo') { return True; }

    # If Rakudo is older than this (or maybe a similar date), we assume
    # it doesn't have the IO::Socket::Async features to do properl
    # listening on a dynamic TCP port.
    if ((~$*PERL.compiler.version) lt '2018.06.259' ) { return False; }

    return True;
}

sub check-list($a, $b -->Bool) {
    if $a.elems != $b.elems { return False; }
    return [&&] $a.values Z== $b.values;
}

