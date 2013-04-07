use Test::More;
use Test::Exception;

use Data::Dumper;

plan skip_all => 'ENV is not set' if ! exists $ENV{AMAZON_EMAIL} || ! exists $ENV{AMAZON_PASSWORD};

plan tests => 9;

use_ok('Net::Amazon::Recommended');

my $obj;
lives_ok { $obj = Net::Amazon::Recommended->new(email => $ENV{AMAZON_EMAIL}, password => $ENV{AMAZON_PASSWORD}) };
my $dat;
$dat = $obj->get_status('486267108X');
lives_ok { $dat = $obj->get_status('486267108X') };
TODO: {
	local $TODO = 'depending on purchase history';
	is($dat->{starRating}, 0, 'starRating');
	is($dat->{isOwned}, 1, 'isOwned');
	is($dat->{isNotInterested}, 0, 'isNotInterested');
	is($dat->{isExcluded}, 0, 'isExcluded');
}
lives_ok { $dat = $obj->get_status('4862671080') };
is($dat, undef, 'not found');
