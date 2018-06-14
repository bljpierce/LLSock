#############################################################################
#                               LLSock.pm                                   #
#                                                                           #
#          A Perl module that implements a link layer 2 raw socket.         #
#                                                                           #
#                      Copyright (c) 2016, Barry Pierce                     #
#                                                                           #  
#############################################################################

package LLSock;
use strict;
use warnings;
use Socket; # for SOCK_RAW
use Carp 'croak';

use constant {
    ETH_P_ALL    => 0x0003, # from /usr/include/linux/if_ether.h
    PF_PACKET    => 17,     # from /usr/include/linux/socket.h
    SIOCGIFINDEX => 0x8933, # from /usr/include/linux/sockios.h
};

sub new {
    my ($class, $dev) = @_;

    if (!$dev) {
        croak 'no network interface given';
    }

    # bless anonymous scalar to be our object
    my $self = bless \do{ my $anon }, $class;

    # Firstly, create the raw socket
    # $$self will be the socket descriptor
    socket $$self, PF_PACKET, SOCK_RAW, ETH_P_ALL or croak "$!";

    # Secondly, get the network interface index
    # fill out struct ifreq which is 
    # defined in /usr/include/linux/if.h
    my $ifreq = pack "a16x4", $dev;

    ioctl($$self, SIOCGIFINDEX, $ifreq) or croak "$!";

    my $if_index = unpack "x16i", $ifreq;

    # Thirdly, bind the interface to the socket
    # fill out struct sockaddr_ll which is
    # defined in /usr/include/linux/if_packet.h
    my $sockaddr_ll = pack "Snix12", PF_PACKET, $if_index, ETH_P_ALL;
    bind $$self, $sockaddr_ll or die "$!";#or croak "$!";

    return $self;
}

# read a packet
sub readp {
    my ($self) = @_;
    sysread $$self, my $buf, 1500 or croak "$!";
    return $buf;
}

# write a packet
sub writep {
    my ($self, $buf) = @_;
    syswrite $$self, $buf or croak "$!";
}

# close the socket - will be called by the destructor
sub finish {
    my ($self) = @_;
    close $$self;
}

sub DESTROY {
    my ($self) = @_;
    $self->finish();
}

1;
