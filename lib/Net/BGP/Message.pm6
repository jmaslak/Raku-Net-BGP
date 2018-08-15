use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Message::Closed-Connection;
use Net::BGP::Message::New-Connection;
use Net::BGP::Message::Stop;

class Net::BGP::Message:ver<0.0.0>:auth<cpan:JMASLAK> {
    method message-type(-->Str) { 'NOOP' };
}

=begin pod

=head1 NAME

Net::BGP::Message - BGP Server Message Superclass

=head1 SYNOPSIS

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.new( :message-type<NOOP> );  # Create a server object

=head1 DESCRIPTION

Parent class for messages used for communication between user code and the BGP
server code.

=head1 METHODS

=head2 message-type

Contains a string that describes what message type the message represents.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
