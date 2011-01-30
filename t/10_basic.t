use Test::More;
use WebService::ATND;
use Data::Dumper;

my $atnd = WebService::ATND->new( encoding => "utf8" );

my $result = $atnd->fetch( 'events', event_id => '11405' );

isa_ok $result, "Hash::AsObject";
is $result->results_returned->value, 1;
my $event = $result->events->event->[0];
is $event->event_id->content, 11405;
is $event->title, 'hachioji.pm #1';

done_testing();
