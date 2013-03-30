use Test::More;
use Test::Exception;

use Data::Dumper;

plan skip_all => 'ENV is not set' if ! exists $ENV{AMAZON_EMAIL} || ! exists $ENV{AMAZON_PASSWORD};

plan tests => 3;

use_ok('Net::Amazon::Recommended');

my $obj;
lives_ok { $obj = Net::Amazon::Recommended->new(email => $ENV{AMAZON_EMAIL}, password => $ENV{AMAZON_PASSWORD}) };
lives_ok { note(Data::Dumper->Dump([$obj->get(Net::Amazon::Recommended->ALL)])) };
