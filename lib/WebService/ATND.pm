package WebService::ATND;
use warnings;
use strict;

our $VERSION = '0.01001';

use parent qw/ LWP::UserAgent Class::Accessor::Fast /;
use XML::Simple;
use URI;
use Data::Recursive::Encode;
use Hash::AsObject;
use DateTime::Format::ISO8601;
use POSIX qw/ strftime /;
use Data::Dumper;

__PACKAGE__->mk_accessors( qw/ baseurl encoding events iter response / );

our $BASEURL = 'http://api.atnd.org/';

sub new {
    my $class = shift;
    my %arg = @_;
    my $baseurl = $arg{ baseurl };
    my $encoding = $arg{ encoding };
    delete $arg{ baseurl };
    delete $arg{ encoding };
    $arg{ agent } ||= __PACKAGE__.'/'.$VERSION;
    $arg{ timeout } ||= 10;
    my $self = $class->SUPER::new( %arg );
    $self->baseurl( $baseurl ? $baseurl : $BASEURL );
    $self->encoding( $encoding );
    return $self;
}

sub fetch {
    my ( $self, $path, %arg ) = @_;
    my $url = $self->_rq( $path, %arg );
    $self->response( $self->get( $url ) );
    unless ( $self->response->is_success ) {
        warn "Couldn't fetch response from ATND-API. Because: response-code=".$self->response->code.". API said ".$self->response->content;
    }
    my $rtn = XMLin( $self->response->content, ForceArray => qr/^event$/, ContentKey => "value" );
    $rtn = Data::Recursive::Encode->encode( $self->encoding, $rtn ) if $self->encoding;
    $rtn = _no_nil( $rtn );
    my $store_method = "_store_$path";
    $store_method =~ s/\//_/g;
    $self->$store_method( $rtn );
}

sub _store_events {
    my ( $self, $rtn ) = @_;
    $self->events( [] );
    for my $event ( @{ $rtn->{ events }->{ event } } ) {
        push @{ $self->events }, _gen_event( $event );
    }
    $self->events( [ sort { $a->start->epoch <=> $b->start->epoch } @{ $self->events } ] );
    $self->iter(0);
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

sub next {
    my $self = shift;
    my $res = $self->event( $self->iter );
    $self->iter( $self->iter + 1 ) if $res;
    return $res;
}

sub prev {
    my $self = shift;
    $self->iter( $self->iter - 1 );
    my $res = $self->event( $self->iter );
    $self->iter( 0 ) unless $self->iter >= 0;
    return $res;
}

sub event {
    my ( $self, $i ) = @_;
    return unless $i >= 0 && $i <= $#{ $self->events };
    $self->events->[$i];
}

sub today_start {
    my $self = shift;
    my @rtn;
    map { push @rtn, $_ if $_->start->strftime( '%Y%m%d' ) eq strftime( '%Y%m%d', localtime() ) } @{ $self->events };
    return @rtn;
}

sub _rq {
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
    $event->{ start } = DateTime::Format::ISO8601->parse_datetime( $event->{ started_at }->{ value } ) if $event->{ started_at }->{ value };
    delete $event->{ started_at };
    $event->{ end } = DateTime::Format::ISO8601->parse_datetime( $event->{ ended_at }->{ value } ) if $event->{ ended_at }->{ value };
    delete $event->{ ended_at };
    $event->{ update } = DateTime::Format::ISO8601->parse_datetime( $event->{ updated_at }->{ value } ) if $event->{ updated_at }->{ value };
    delete $event->{ updated_at };
    $event->{ limit } = sprintf( '%d', $event->{ limit }->{ value } );
    $event = _no_nil( $event );
    Hash::AsObject->new( $event );
}

sub _gen_user {
    my $user = shift;
    $user->{ status } = $user->{ status }->{ value } if $user->{ status }->{ value };
    $user->{ id } = $user->{ user_id }->{ value } if $user->{ user_id }->{ value };
    delete $user->{ user_id };
    $user->{ twitter_id } = undef if ref $user->{ twitter_id } eq 'HASH';
    $user = _no_nil( $user );
    Hash::AsObject->new( $user );
}

sub _no_nil {
    no strict "refs";
    my $hashref = shift;
    $hashref->{ $_ } = $hashref->{ $_ }->{ nil } ? undef : $hashref->{ $_ } for keys %{ $hashref };
    return $hashref;
}

1;
__END__

=head1 NAME

WebService::ATND - ATND API Wrapper Class

=head1 SYNOPSIS

  use WebService::ATND;

  my $atnd = WebService::ATND->new;
  ### or ###
  my $atnd = WebService::ATND->new( encoding => 'utf8' ); 
  
  ### Fetch event infomation
  $atnd->fetch( 'events', keyword => 'perl' );
  
  ### Print each event name
  print $_->title."\n" while $atnd->next;
  
  ### Fetch users who joins to event
  $atnd->fetch( 'events/users', event_id => 10201 );

  ### Print each users who joins to event
  my $event = $atnd->next;
  $_->nickname."\n" for @{ $event->users };

=head1 NOTE!!!!

THIS IS ALPHA QUALITY CODE!

If you found bug, please report by e-mail or twitter(@ytnobody).

This module inherits LWP::UserAgent.

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

Send a http-request to ATND-API. Instance stores events-data that contained into response.

$api_path is a path for API. Currently, it becomes to 'events' or 'event/users'.

%params is query parameters for extracting data from API.

=head2 next / prev

Get stored data from instance;

=head2 iter

=head2 events

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

Hash::AsObject

http://api.atnd.org/

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
