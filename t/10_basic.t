use Test::More;
use WebService::ATND;
use POSIX qw/ strftime /;
use strict;

my @pattern = (
    { arg => {}, 
      baseurl => 'http://api.atnd.org/', 
      encoding => undef,
      timeout => 10 },
    { arg => { encoding => 'utf8' }, 
      baseurl => 'http://api.atnd.org/', 
      encoding => 'utf8',
      timeout => 10 },
    { arg => { baseurl => 'http://localhost/', timeout => 20 },
      baseurl => 'http://localhost/', 
      encoding => undef,
      timeout => 20 },
    { arg => { encoding => 'shiftjis', baseurl => 'http://localhost/', timeout => 0.1 }, 
      baseurl => 'http://localhost/', 
      encoding => 'shiftjis',
      timeout => 0.1 },
);

for ( @pattern ) {
    my $atnd = WebService::ATND->new( %{ $_->{ arg } } );
    isa_ok $atnd, 'WebService::ATND';
    is $atnd->baseurl, $_->{ baseurl };
    is $atnd->encoding, $_->{ encoding };
    is $atnd->timeout, $_->{ timeout };
}

done_testing();

