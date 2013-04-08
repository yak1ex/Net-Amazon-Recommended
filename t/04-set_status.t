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
my (%orig) = map { $_ => $dat->{$_} } qw(starRating isOwned isNotInterested isExcluded);
lives_ok { $obj->set_status('486267108X', { starRating => 5, isOwned => 0, isNotInterested => 0, isExcluded => 0 }) };
lives_ok { $dat = $obj->get_status('486267108X') };

is($dat->{starRating}, 5, 'starRating');
is($dat->{isOwned}, 0, 'isOwned');
is($dat->{isNotInterested}, 0, 'isNotInterested');
is($dat->{isExcluded}, 0, 'isExcluded');

lives_ok { $obj->set_status('486267108X', { starRating => 0, isOwned => 0, isNotInterested => 1, isExcluded => 0 }) };
lives_ok { $dat = $obj->get_status('486267108X') };

is($dat->{starRating}, 0, 'starRating');
is($dat->{isOwned}, 0, 'isOwned');
is($dat->{isNotInterested}, 1, 'isNotInterested');
is($dat->{isExcluded}, 0, 'isExcluded');

lives_ok { $obj->set_status('486267108X', { starRating => 0, isOwned => 1, isNotInterested => 0, isExcluded => 1 }) };
lives_ok { $dat = $obj->get_status('486267108X') };

is($dat->{starRating}, 0, 'starRating');
is($dat->{isOwned}, 1, 'isOwned');
is($dat->{isNotInterested}, 0, 'isNotInterested');
is($dat->{isExcluded}, 1, 'isExcluded');

lives_ok { $obj->set_status('486267108X', \%orig) };
