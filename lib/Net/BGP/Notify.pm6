use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Notify:ver<0.0.0>:auth<cpan:JMASLAK> {
    method message-type(-->Str) { 'NOOP' };
    method is-error(-->Bool)    { False  };
}

=begin pod

=head1 NAME

Net::BGP::Notify - BGP Server Noitfy Superclass

=head1 SYNOPSIS

  use Net::BGP::Notify;

  my $msg = Net::BGP::Notify.new( :message-type<NOOP> );

=head1 DESCRIPTION

Parent class for messages (notifications) used for communication from the BGP
server code to the user code.

=head1 METHODS

=head2 message-type

Contains a string that describes what message type the notification represents.

=head2 is-error

Returns true or false based on whether this notification represents an error.
It defaults to False in the parent class.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
