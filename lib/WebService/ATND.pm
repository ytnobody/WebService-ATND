package WebService::ATND;
our $VERSION = '0.01';

use parent qw/ LWP::UserAgent Class::Accessor::Fast /;
use XML::Simple;
use SUPER;
use URI;
use Data::Recursive::Encode;
use Hash::AsObject;
use DateTime::Format::ISO8601;
use POSIX qw/ strftime /;

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
    $self->events( [] );
    for my $event ( @{ $rtn->{ events }->{ event } } ) {
        push @{ $self->events }, _gen_event( $event );
    }
    $self->events( [ sort { $a->start->epoch <=> $b->start->epoch } @{ $self->events } ] );
    $self->iter(0);
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

    $event->{ lat } = sprintf( '%f', $event->{ lat }->{ value } );

    $event->{ lon } = sprintf( '%f', $event->{ lon }->{ value } );

    $event->{ waiting } = sprintf( '%d', $event->{ waiting }->{ value } );

    $event->{ start } = DateTime::Format::ISO8601->parse_datetime( $event->{ started_at }->{ value } ) if $event->{ started_at }->{ value };
    delete $event->{ started_at };

    $event->{ end } = DateTime::Format::ISO8601->parse_datetime( $event->{ ended_at }->{ value } ) if $event->{ ended_at }->{ value };
    delete $event->{ ended_at };

    $event->{ url } = $event->{ url }->{ value };    

    $event->{ limit } = sprintf( '%d', $event->{ limit }->{ value } );

    Hash::AsObject->new( $event );
}

1;
__END__

=head1 NAME

WebService::ATND - 

=head1 SYNOPSIS

  use WebService::ATND;

=head1 DESCRIPTION

WebService::ATND is

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
