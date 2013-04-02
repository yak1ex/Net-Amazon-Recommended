use Test::More;
use Test::Exception;

use Data::Dumper;

plan skip_all => 'ENV is not set' if ! exists $ENV{AMAZON_EMAIL} || ! exists $ENV{AMAZON_PASSWORD};

plan tests => 8;

use_ok('Net::Amazon::Recommended');

my $obj;
lives_ok { $obj = Net::Amazon::Recommended->new(email => $ENV{AMAZON_EMAIL}, password => $ENV{AMAZON_PASSWORD}) };
my $dat;
lives_ok { $dat = $obj->get('https://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_welc') };
note(scalar(@$dat).' items found');
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
