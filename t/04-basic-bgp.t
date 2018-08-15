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

        $client.write( read-message('t/bgp-messages/01-noop-message.msg') );
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

        $client.write( read-message('t/bgp-messages/02-test-invalid-header.msg') );
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

