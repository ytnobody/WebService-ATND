package WebService::ATND;
use warnings;
use strict;

our $VERSION = '0.02001';

use constant TIME_FORMAT => '%Y-%m-%dT%H:%M:%S%z:00';

use Mouse;
use XML::Simple;
use URI;
use HTTP::Request::Common;
use DateTime::Format::ISO8601;
use Time::Piece;
use Furl;

has agent => ( 
    is => 'ro', 
    isa => 'Furl',
    default => sub {
        Furl->new( 
            agent   => join( '/', __PACKAGE__, $VERSION ), 
            timeout => 10 
        );
    },
);

has baseurl => ( 
    is => 'ro', 
    isa => 'Str', 
    default => 'http://api.atnd.org/',
);

sub fetch {
    my ( $self, $path, %arg ) = @_;
    my $url = $self->request( $path, %arg );
    my $res = $self->agent->request(GET $url);
    unless ( $res->is_success ) {
        Carp::croak sprintf "Couldn't fetch response from ATND-API. Because: response-code=%s. API said %s", $res->code, $res->content;
    }
    my $rtn = XMLin( $res->content, ForceArray => qr/^event$/, ContentKey => "value" );
    $rtn = _no_nil( $rtn );
    my $store_method = "_store_$path";
    $store_method =~ s/\//_/g;
    $self->$store_method( $rtn );
}

sub _store_events {
    my ( $self, $rtn ) = @_;
    my @events;
    for my $event ( @{ $rtn->{ events }->{ event } } ) {
        push @events, _gen_event( $event );
    }
    return sort { $a->{ start }->epoch <=> $b->{ start }->epoch } @events;
}

sub _store_events_users {
    my ( $self, $rtn ) = @_;
    $self->_store_events( $rtn );
    for my $event ( @{ $self->events } ) {
        for my $user ( @{ $event->users->user } ) {
            $user = _gen_user( $user );
        }
        $event->users( $event->users->user );
        $event->accepted( $event->accepted->value );
    }
}

sub request {
    my ( $self, $path, %arg ) = @_;
    my $uri = URI->new( $self->baseurl.$path );
    $uri->query_form( %arg );
    return $uri->as_string;
}

sub _gen_event {
    my $event = shift;
    $event->{ id } = sprintf( '%d', $event->{ event_id }->{ value } );
    delete $event->{ event_id };
    $event->{ lat } = sprintf( '%f', $event->{ lat }->{ value } ) if $event->{ lat }->{ value };
    $event->{ lon } = sprintf( '%f', $event->{ lon }->{ value } ) if $event->{ lon }->{ value };
    $event->{ waiting } = sprintf( '%d', $event->{ waiting }->{ value } );
    for my $key ( qw( start end update ) ) {
        my $origin_key = $key =~ /e$/ ? $key.'d_at' : $key.'ed_at';
        if ( $event->{ $origin_key }->{ value } ) {
            $event->{ $key } = Time::Piece->strptime( $event->{ $origin_key }->{ value }, TIME_FORMAT );
        }
        delete $event->{ $origin_key };
    }
    $event->{ limit } = sprintf( '%d', $event->{ limit }->{ value } );
    $event = _no_nil( $event );
    return $event;
}

sub _gen_user {
    my $user = shift;
    $user->{ status } = $user->{ status }->{ value } if $user->{ status }->{ value };
    $user->{ id } = $user->{ user_id }->{ value } if $user->{ user_id }->{ value };
    delete $user->{ user_id };
    $user->{ twitter_id } = undef if ref $user->{ twitter_id } eq 'HASH';
    $user = _no_nil( $user );
    return $user;
}

sub _no_nil {
    no strict "refs";
    my $hashref = shift;
    for my $key ( keys %$hashref ) {
        next unless ref $hashref->{ $key } eq 'HASH';
        $hashref->{ $key } = $hashref->{ $key }->{ nil } ? undef : $hashref->{ $key };
    }
    return $hashref;
}

1;
__END__

=head1 NAME

WebService::ATND - ATND API Wrapper Class

=head1 SYNOPSIS

  use WebService::ATND;

  my $atnd = WebService::ATND->new;
  
  ### Fetch event infomation
  my @events = $atnd->fetch( 'events', keyword => 'perl' );
  
  ### Print each event name
  for my $event ( @events ) {
      print $event->{title}."\n";
  }
  
  ### Fetch users who joins to event
  my @users = $atnd->fetch( 'events/users', event_id => 10201 );

  ### Print each users who joins to event
  my $event = shift @users;
  for my $user ( @{ $event->{users} } ) {
      $user->{nickname}."\n";
  }

=head1 NOTE!!!!

THIS IS ALPHA QUALITY CODE!

If you found bug, please report by e-mail or twitter(@ytnobody).

=head1 INSTALL

  $ git clone git://github.com/ytnobody/WebService-ATND.git
  $ cpanm ./WebService-ATND

=head1 METHODS

=head2 new( %params ) 

Create an instance of WebService::ATND.

%params are options of LWP::UserAgent. And, following are appended. 

- encoding : Specifier of output-data encoding ( eg. utf8, shiftjis ... )

These option is not required.

=head2 fetch( $api_path, %params )

Send a http-request to ATND-API, and returns events-data list.

$api_path is a path for API. Currently, it becomes to 'events' or 'event/users'.

%params is query parameters for extracting data from API.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

http://api.atnd.org/

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
