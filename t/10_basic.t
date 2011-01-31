use Test::More;
use WebService::ATND;
use POSIX qw/ strftime /;
use Data::Dumper;

my $atnd = WebService::ATND->new( encoding => "utf8" );
my $event;

{
    $atnd->fetch( 'events', event_id => [ qw/ 9807 11405 / ] );

    $event = $atnd->next;
    is $event->id, 9807;
    is $event->title, '(東京西部、多摩地域).pm #0 ';
    is $event->start->strftime( '%Y/%m/%d %H:%M:%S' ), '2010/12/11 18:00:00';
    is $atnd->iter, 1;

    $event = $atnd->next;
    is $event->id, 11405;
    is $event->title, 'hachioji.pm #1';
    is $event->start->strftime( '%Y/%m/%d %H:%M:%S' ), '2011/01/22 18:00:00';
    is $atnd->iter, 2;

    $event = $atnd->next;
    is $event, undef;
    is $atnd->iter, 2;

    $event = $atnd->prev;
    is $event->id, 11405;
    is $event->title, 'hachioji.pm #1';
    is $event->start->strftime( '%Y/%m/%d %H:%M:%S' ), '2011/01/22 18:00:00';
    is $atnd->iter, 1;

    $event = $atnd->prev;
    is $event->id, 9807;
    is $event->title, '(東京西部、多摩地域).pm #0 ';
    is $event->start->strftime( '%Y/%m/%d %H:%M:%S' ), '2010/12/11 18:00:00';
    is $atnd->iter, 0;

    $event = $atnd->prev;
    is $event, undef;
    is $atnd->iter, 0;

    $event = $atnd->next;
    is $event->id, 9807;
    is $event->title, '(東京西部、多摩地域).pm #0 ';
    is $event->start->strftime( '%Y/%m/%d %H:%M:%S' ), '2010/12/11 18:00:00';
    is $atnd->iter, 1;
}

done_testing();

{
    $atnd->fetch( 'events', keyword => 'perl' );
    @events = $atnd->today_start;
    for ( @events ) {
        is $_->start->strftime( '%Y%m%d' ), strftime( '%Y%m%d' );
    }
}



