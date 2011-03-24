use Test::More;
use Test::TCP;
use File::Slurp;
use Plack::Loader;
use WebService::ATND;
use Data::Dumper;
use FindBin;
use strict;

my @pattern = (
    { id => 13928,
      title => '壊滅的ダメージを受けてる外食産業を盛り上げる会',
      url => 'http://www.butagumi.com/shabuan/',
      limit => 85,
      waiting => 0,
      updated_at => undef },
    { id => 13891,
      title => 'BPStudy#43',
      url => 'http://www.ebis303.com/ebisconference/index.html',
      limit => 50,
      waiting => 0,
      updated_at => undef },
    { id => 13836,
      title => '日本Androidの会横浜支部 第6回定例会',
      url => undef,
      limit => 93,
      waiting => 0,
      updated_at => undef },
    { id => 14021,
      title => 'わたなべ美樹氏特別講演「みんなでより良い社会を作ろう」',
      url => 'http://socialvalue.jp/special_watanabe/',
      limit => 490,
      waiting => 0,
      updated_at => undef },
    { id => 14017,
      title => '自粛ムードを吹っ飛ばせ！祝1周年！100人花見！',
      url => 'http://greendrinks.jp/announcements/gdkichijoji6/',
      limit => 100,
      waiting => 0,
      updated_at => undef },
    { id => 13958,
      title => '関西発　世界視点のキャリアのつくりかた',
      url => 'http://www.skybldg.co.jp/access/walk.html',
      limit => 100,
      waiting => 0,
      updated_at => undef },
    { id => 14019,
      title => '第四回 学生限定 Androidアプリ 開発ハンズオン',
      url => 'http://www.uni-labo.com',
      limit => 20,
      waiting => 0,
      updated_at => undef },
    { id => 14022,
      title => 'a-blog cms Training Camp 2011 Spring',
      url => 'http://www.a-blogcms.jp',
      limit => 15,
      waiting => 0,
      updated_at => undef },
    { id => 13984,
      title => 'ニコマスサバゲーオフ2011(春)',
      url => 'http://www.lodestone.co.jp/index.html',
      limit => 60,
      waiting => 0,
      updated_at => undef },
    { id => 14020,
      title => '（仮）sipeb2001　10周年同窓会',
      url => 'http://www.familyrestaurant.jp/',
      limit => 360,
      waiting => 0,
      updated_at => undef },
);

my $app = sub {
    my $content = read_file( "$FindBin::Bin/data/nocond.xml" );
    [ 200, [ 'Content-Type' => 'application/xml' ], [ $content ] ];
};

my $client = sub {
    my $base = shift;
    my $atnd = WebService::ATND->new( encoding => 'utf8', baseurl => $base );
    $atnd->fetch( 'events' );
    while ( my $event = $atnd->next ) {
        my $p = shift @pattern;
        is $event->$_, $p->{ $_ }, "$_ : \n".Dumper( $event->$_ ) for keys %$p; 
    }
};

test_tcp(
    client => sub {
        my $port = shift;
        my $base = "http://127.0.0.1:$port/";
        $client->( $base );
    },
    server => sub {
        my $port = shift;
        my $server = Plack::Loader->auto(
            port => $port,
            host => '127.0.0.1',
        );
        $server->run( $app );
    },
);

done_testing;
