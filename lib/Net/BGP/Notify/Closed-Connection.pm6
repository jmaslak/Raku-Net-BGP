use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Notify::Closed-Connection:ver<0.0.0>:auth<cpan:JMASLAK> {
    has Str $.client-ip;
    has Int $.client-port;

    method message-type(-->Str) { 'Closed-Connection' };
}

=begin pod

=head1 NAME

Net::BGP::Notify::Closed-Connection - BGP Closed Connection Notification

=head1 SYNOPSIS

  use Net::BGP::Notify::Closed-Connection;

  my $msg = Net::BGP::Notify::Closed-Connection.new();

=head1 DESCRIPTION

A Closed-Connection notification.

The Closed-Connection notification is only sent from the BGP server to the user
code.  This event is triggered when a connection to the BGP listener port is
closed.

=head1 METHODS

=head2 message-type

Contains the string C<Closed-Connection>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
