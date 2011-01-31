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

{
    $atnd->fetch( 'events', keyword => 'perl' );
    @events = $atnd->today_start;
    for ( @events ) {
        is $_->start->strftime( '%Y%m%d' ), strftime( '%Y%m%d' );
    }
}

{
    $atnd->fetch( 'events/users', event_id => 9807 );
    $event = $atnd->next;
    is $event->users->[0]->nickname, "uzulla";
    is $event->users->[1]->nickname, "hide_o_55";
    is $event->users->[2]->nickname, "norry_gogo";
    is $event->users->[3]->nickname, "charsbar";
    is $event->users->[4]->nickname, "ytnobody";
    is $event->users->[5]->nickname, "umeyuki";
    is $event->users->[6]->nickname, "hondallica666";
    is $event->users->[7]->nickname, "makamaka_at_donzoko";
    is $event->users->[8]->nickname, "ono_pm";
    is $event->users->[9]->nickname, "usayman";
    is $event->users->[10]->nickname, "studio-m";
}

done_testing();

