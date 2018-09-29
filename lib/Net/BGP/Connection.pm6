use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Connection:ver<0.0.0>:auth<cpan:JMASLAK> {
    my Int $last_id = 0;

    has IO::Socket::Async $.socket;
    has Channel           $.command = Channel.new();
    has Int               $.id      = $last_id++;
}

=begin pod

=head1 NAME

Net::BGP::Connection - BGP Server Connection Class

=head1 SYNOPSIS

  use Net::BGP::Connection;

  my $conn    = Net::BGP::Connection.new(:socket($socket));
  my $id      = $conn.id;

  $conn.command.send($msg);

=head1 DESCRIPTION

Maintains the connection information for an active (in the TCP-sense) BGP
connection.

=head1 ATTRIBUTES

=head2 socket

The socket associated with this connection.

=head2 command

A channel used to send BGP commands to the connection.  See classes under
the C<Net::BGP::Command> namespace.

=head2 id

A unique ID number associated with this connection.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
