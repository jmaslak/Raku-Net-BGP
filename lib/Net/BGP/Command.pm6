use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Command:ver<0.0.0>:auth<cpan:JMASLAK> {
    has Int $.connection-id;

    method message-type(-->Str) { 'NOOP' };
}

=begin pod

=head1 NAME

Net::BGP::Command - BGP Server Noitfy Superclass

=head1 SYNOPSIS

  use Net::BGP::Command;

  my $msg = Net::BGP::Command.new( :message-type<NOOP> );

=head1 DESCRIPTION

Parent class for messages (commands) from user code to BGP server code.

=head1 ATTRIBUTES

=head2 connection-id

This contains the appropriate connection ID associated with the command.

=head1 METHODS

=head2 message-type

Contains a string that describes what message type the command represents.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
