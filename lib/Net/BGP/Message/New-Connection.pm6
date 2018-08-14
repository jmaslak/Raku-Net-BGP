use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Message::New-Connection:ver<0.0.0>:auth<cpan:JMASLAK> {
    has Str $.client-ip;
    has Int $.client-port;

    method message-type(-->Str) { 'New-Connection' };
}

=begin pod

=head1 NAME

Net::BGP::Message::New-Connection - BGP New Connection Notification

=head1 SYNOPSIS

  use Net::BGP::Message::New-Connection;

  my $msg = Net::BGP::Message::New-Connection.new();

=head1 DESCRIPTION

A New-Connection message.

The New-Connection message is only sent from the BGP server to the user code.
This event is triggered when a new connection to the BGP listener port is
received.

=head1 METHODS

=head2 message-type

Contains the string C<New-Connection>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
