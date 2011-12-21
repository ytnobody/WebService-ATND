use Test::More;
use WebService::ATND;

subtest 'normal' => sub {
    my $atnd = WebService::ATND->new( %{ $_->{ arg } } );
    isa_ok $atnd, 'WebService::ATND';
    is $atnd->baseurl, 'http://api.atnd.org/', sprintf 'baseurl as like as %s', 'http://api.atnd.org/';
};

done_testing();

