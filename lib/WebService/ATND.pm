package WebService::ATND;
our $VERSION = '0.01';

use parent qw/ LWP::UserAgent Class::Accessor::Fast /;
use XML::Simple;
use SUPER;
use URI;
use Data::Recursive::Encode;
use Hash::AsObject;

__PACKAGE__->mk_accessors( qw/ baseurl encoding result / );

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
    my $res = $self->get( $url );
    my $rtn = XMLin( $res->content, ForceArray => qr/^event$/, ContentKey => "value" ) if $res->is_success;
    $rtn = Data::Recursive::Encode->encode( $self->encoding, $rtn ) if $self->encoding;
    $self->result( Hash::AsObject->new( $rtn ) );
    $self->result;
}

sub _rq {
    my ( $self, $path, %arg ) = @_;
    my $uri = URI->new( $self->baseurl.$path );
    $uri->query_form( %arg );
    return $uri->as_string;
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
