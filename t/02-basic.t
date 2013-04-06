use Test::More;
use Test::Exception;

use Data::Dumper;

plan skip_all => 'ENV is not set' if ! exists $ENV{AMAZON_EMAIL} || ! exists $ENV{AMAZON_PASSWORD};

plan tests => 15;

use_ok('Net::Amazon::Recommended');

my $obj;
lives_ok { $obj = Net::Amazon::Recommended->new(email => $ENV{AMAZON_EMAIL}, password => $ENV{AMAZON_PASSWORD}) };
my $dat;
lives_ok { $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_welc') };
TODO: {
	local $TODO = 'depending on purchase history';
	is(@$dat, 15, '1 page');
}
lives_ok { $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_welc', 2) };
TODO: {
	local $TODO = 'depending on purchase history';
	is(@$dat, 30, '2 pages');
}
is(ref $dat->[0]{date}, 'DateTime');
like($dat->[0]{url}, qr|https?://www.amazon.[^/]*/dp/[^/]+$|);
throws_ok
	{ $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_w&rGroup=watches') }
	qr/Non existent category/, 'non existent category';
TODO: {
	local $TODO = 'depending on purchase history';
	lives_ok { $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_diy?ie=UTF8&nodeID=2017405051&parentStoreNode=&rGroup=diy') };
	is(@$dat, 0, 'notfound');
}
lives_ok { $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_b_466294?ie=UTF8&nodeID=466294&parentID=465610&parentStoreNode=465610', 2) };
TODO: {
	local $TODO = 'depending on purchase history';
	ok(@$dat < 15, '2 pages but 1 page');
}
lives_ok { $dat = $obj->get('http://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_vg?ie=UTF8&nodeID=637872&parentStoreNode=&rGroup=videogames', undef) };
TODO: {
	local $TODO = 'depending on purchase history';
	ok(@$dat > 30, 'unlimited pages');
}
