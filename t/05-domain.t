use Test::More;
use Test::Exception;

use Data::Dumper;

plan skip_all => 'ENV is not set' if ! exists $ENV{AMAZON_EMAIL} || ! exists $ENV{AMAZON_PASSWORD};

plan tests => 48;

use_ok('Net::Amazon::Recommended');

my $obj;
lives_ok { $obj = Net::Amazon::Recommended->new(email => $ENV{AMAZON_EMAIL}, password => $ENV{AMAZON_PASSWORD}, domain => 'com') };
my $dat;

lives_ok { $dat = $obj->get('http://www.amazon.com/gp/yourstore/recs/ref=pd_ys_nav_b_5?ie=UTF8&nodeID=5&parentID=51546011&parentStoreNode=51546011
') };
TODO: {
	local $TODO = 'depending on purchase history';
	cmp_ok(@$dat, '>', 0, '1 page');
}

foreach my $type (qw(rated notinterested owned purchased)) {
	lives_ok { $dat = $obj->get_list($type) };
	TODO: {
		local $TODO = 'depending on purchase history';
		is(@$dat, 15, '1 page for '.$type);
	}
	lives_ok { $dat = $obj->get_list($type, 2) };
	TODO: {
		local $TODO = 'depending on purchase history';
		is(@$dat, 30, '2 pages for '.$type);
	}
	SKIP: {
		skip 'item not found', 1 unless @$dat;
		like($dat->[0]{url}, qr|https?://www.amazon.[^/]*/dp/[^/]+$|, 'url check');
	}
}

lives_ok { $dat = $obj->get_last_status('Purchased') };
TODO: {
	local $TODO = 'depending on purchase history';
	is($dat->{itemId}, "'0716724898'", 'Purchased by asin');
	is($dat->{starRating}, 0, 'starRating');
	is($dat->{isExcluded}, 0, 'isExcluded');
}

my $target_asin = '0805071660';

lives_ok { $obj->set_status($target_asin, { starRating => 0, isOwned => 0, isNotInterested => 1, isExcluded => 0 }) };

lives_ok { $dat = $obj->get_last_status('Owned') };
isnt($dat->{itemId}, "'$target_asin'", 'asin');

lives_ok { $dat = $obj->get_last_status('NotInterested') };
is($dat->{itemId}, "'$target_asin'", 'asin');
is($dat->{isNotInterested}, 1, 'isNotInterested');

# Can't check exclusion

lives_ok { $obj->set_status($target_asin, { starRating => 0, isOwned => 1, isNotInterested => 0, isExcluded => 1 }) };

lives_ok { $dat = $obj->get_last_status('Owned') };
is($dat->{itemId}, "'$target_asin'", 'asin');
is($dat->{isExcluded}, 1, 'isExcluded');

lives_ok { $dat = $obj->get_last_status('NotInterested') };
isnt($dat->{itemId}, "'$target_asin'", 'asin');

lives_ok { $obj->set_status($target_asin, { starRating => 5, isOwned => 0, isNotInterested => 0, isExcluded => 1 }) };

lives_ok { $dat = $obj->get_last_status('Owned') };
isnt($dat->{itemId}, "'$target_asin'", 'asin');

lives_ok { $dat = $obj->get_last_status('Rated') };
is($dat->{itemId}, "'$target_asin'", 'asin');
is($dat->{starRating}, 5, 'starRating');
is($dat->{isExcluded}, 1, 'isExcluded');

lives_ok { $obj->set_status($target_asin, { starRating => 5, isOwned => 1, isNotInterested => 0, isExcluded => 0 }) };
