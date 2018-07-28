use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;

subtest 'Basic Class Construction', {
    my $bgp = Net::BGP.new();
    ok $bgp, "Created BGP Class";
    is $bgp.port, 179, 'Port has proper default';

    $bgp = Net::BGP.new( port => 1179 );
    is $bgp.port, 1179, 'Port is properly set to 1179';

    $bgp = Net::BGP.new( port => Nil );
    is $bgp.port, 179, 'Port is properly set to 179 by Nil';

    dies-ok { $bgp.port = 17991; }, 'Cannot change port';

    dies-ok { $bgp = Net::BGP.new( port =>    -1 ); }, '< 0 port rejected';
    dies-ok { $bgp = Net::BGP.new( port => 65536 ); }, '>65535 port rejected';

    dies-ok { $bgp = Net::BGP.new( foo => 1 ); }, 'Non-existent attribute causes failure';

    done-testing;
};

subtest 'Listener', {

    if (check-compiler-version) {
        my $bgp = Net::BGP.new( port => 0);
        is $bgp.port, 0, 'BGP Port is 0';

        $bgp.listen();
        isnt $bgp.port, 0, 'BGP Port isnt 0';

        diag "Port is: " ~ $bgp.port;

        $bgp.listen-stop();
    } else {
        skip "Compiler doesn't support dynamic IO::Socket::Async port listening" unless check-compiler-version;
    }
    done-testing;
};

done-testing;

sub check-compiler-version(--> Bool) {
    # We don't know about anything but Rakudo, so we assume it works.
    if ($*PERL.compiler.name ne 'rakudo') { return True; }

    # If Rakudo is older than this (or maybe a similar date), we assume
    # it doesn't have the IO::Socket::Async features to do properl
    # listening on a dynamic TCP port.
    if ((~$*PERL.compiler.version) lt '2018.06.259' ) { return False; }

    return True;
}

