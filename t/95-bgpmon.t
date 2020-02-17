use v6.d;
use Test;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Speaker;
use Net::BGP::Conversions;

my $speaker = Net::BGP::Speaker.new(
    listen-port => 0,
    my-asn      => 65000,
    my-bgp-id   => '192.0.2.1',
);

ok $speaker ~~ Net::BGP::Speaker:D, "Speaker object defined";
ok $speaker.bgp ~~ Net::BGP:D, "BGP defined";
ok $speaker.display ~~ Net::BGP::Speaker::Display:D, "Display object defined";
is $speaker.listen-host, '0.0.0.0', "Proper listen-host";
is $speaker.listen-port, 0, "Proper listen-port";
is $speaker.my-asn, 65000, "Proper my-asn";
ok $speaker.my-domain ~~ Str, "proper my-domain";
ok $speaker.my-hostname ~~ Str, "proper my-hostname";
is $speaker.wanted-cidr, [], "Proper wanted CIDR (1)";
is $speaker.wanted-asn, [], "Proper wanted ASN (1)";

$speaker = Net::BGP::Speaker.new(
    listen-port => 0,
    my-asn      => 65000,
    my-bgp-id   => '192.0.2.1',
    asn-filter  => '65000,65001',
    cidr-filter => '192.0.2.0/32,192.0.2.128/25',
);
my @cidrs = (
    Net::BGP::CIDR.from-str('192.0.2.0/32'),
    Net::BGP::CIDR.from-str('192.0.2.128/25'),
);
is $speaker.wanted-cidr, @cidrs, "Proper wanted CIDR (2)";
is $speaker.wanted-asn, [65000, 65001], "Proper wanted ASN (2)";

is $speaker.colored, False, "Not colored (1)";
is $speaker.display.colored, False, "Not colored (2)";
$speaker.colored(True);
is $speaker.colored, True, "Yes colored (1)";
is $speaker.display.colored, True, "Yes colored (2)";

my $bgp = $speaker.bgp;
is $bgp.port, 0, 'BGP Port is 0';

$speaker.peer-add(
    :peer-asn(0x1020),
    :peer-ip('127.0.0.1'),
    :peer-port(179),
    :passive,
    :ipv4(True),
    :ipv6(False),
    :md5(Str),
);

$bgp.listen();
isnt $bgp.port, 0, 'BGP Port isnt 0';

is $bgp.my-asn, 65000, "ASN is correct";

my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($bgp.port));
my $uc = $bgp.user-channel;
my $cr = $uc.receive;
is $cr.message-name, 'New-Connection', 'Message type is as expected';

$client.write( read-message('t/bgp-messages/open-message-no-opt.msg') );

my $cr-bgp = $uc.receive;
is $cr-bgp.message-name, 'BGP-Message', 'BGP message type is as expected';
is $cr-bgp.is-error, False, 'Is not an error';
is $cr-bgp.message.message-name, 'OPEN', 'BGP Message is proper name';

$client.read(16).sink; # Read (and silently discard) header
my $raw = $client.read(nuint16($client.read(2))-18); # Read appropriate length

my $msg = Net::BGP::Message.from-raw($raw, :!asn32);
ok $msg ~~ Net::BGP::Message::Open, "Message is proper type";
is $msg.parameters.elems, 0, "No parameters provided";

my $header = $client.read(16); # Read and silently discard header;
$raw = $client.read(nuint16($client.read(2))-18); # Read appropriate length;
my $keep-alive = Net::BGP::Message.from-raw($raw, :!asn32);
is $keep-alive.message-name, 'KEEP-ALIVE', "Keep-Alive received";

$client.write( $header );
$client.write( nuint16-buf8( $raw + 18 ) );
$client.write( $raw );

$bgp.announce(
    $cr-bgp.connection-id,
    [ '192.0.2.0/24', '192.0.2.2/32' ],
    '192.0.2.1'
);

$client.read(16).sink; # Read and silently discard header;
$raw = $client.read(nuint16($client.read(2))-18); # Read appropriate length;
my $update = Net::BGP::Message.from-raw($raw, :!asn32);
is $update.message-name, 'UPDATE', 'UD is proper name';
is $update.nlri, ['192.0.2.0/24', '192.0.2.2/32'], 'UD NLRI correct';
is $update.next-hop, '192.0.2.1', "UD next-hop correct";
is $update.path, '65000 ?', "UD path correct";

$client.close();

my $cr-bad = $uc.receive;
is $cr-bad.message-name, 'Closed-Connection', 'Close message type is as expected';
is $cr-bad.is-error, False, 'Is not an error';

is $bgp.peer-get(:peer-ip('127.0.0.1')).state, Net::BGP::Peer::Idle, 'Peer is idle';

$bgp.listen-stop();

done-testing;

sub read-message($filename) {
    return slurp $filename, :bin;
}

