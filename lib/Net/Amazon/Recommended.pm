package Net::Amazon::Recommended;

use strict;
use warnings;

# ABSTRCT: Grab and configurate recommendations by Amazon
# VERSION

use Carp;
use Template::Extract;
use DateTime::Format::Strptime;

use constant {
	ALL => 0,
	NEWRELEASE => 1,
	COMINGSOON => 2,
};

sub new
{
	my $self = shift;
	my $class = ref $self || $self;
	my %args = @_;
	croak 'email andd password are required' if ! exists $args{email} || ! exists $args{password};
	return bless {
		_EMAIL => $args{email},
		_PASSWORD => $args{password},
		_DOMAIN => $args{domain} || 'co.jp',
	}, $class;
}

# TODO: Handle category
my (%url) = (
	ALL() => '/gp/yourstore/recs/ref=pd_ys_welc',
	NEWRELEASE() => '/gp/yourstore/nr/ref=pd_ys_welc',
	COMINGSOON() => '/gp/yourstore/fr/ref=pd_ys_welc',
);

# Except for welc, nav_ is prefixed
# /ref=pd_ys_nav_<suffix>?rGroup=<key>
my (%category) = (
	''                    => ['welc',            'All'],
	'instant-video'       => ['nav_mov_aiv',     'Amazon Instant Video'],
	'dmusic'              => ['nav_dmusic',      'Amazon MP3 Store'],
	'appliances'          => ['nav_la',          'Appliances'],
	'mobile-apps'         => ['nav_mas',         'Appstore for Android'],
	'arts-crafts'         => ['nav_ac',          'Arts, Crafts & Sewing'],
	'automotive'          => ['nav_auto',        'Automotive'],
	'baby-products'       => ['nav_ba',          'Baby'], # .com
	'baby'                => ['nav_ba',          'Baby'], # .co.jp
	'beauty'              => ['nav_bt',          'Beauty'], # nav_beauty
	'books'               => ['nav_b',           'Books'],
	'digital-text'        => ['nav_kstore',      'Books on Kindle'], # nav_kinc
	'photo'               => ['nav_p',           'Camera & Photo'],
	'wireless'            => ['nav_cps',         'Cell Phones & Accessories'],
	'apparel'             => ['nav_a',           'Clothing & Accessories'],
	'pc'                  => ['nav_pc',          'Computers'],
	'diy',                => ['nav_diy',         'DIY'], # .co.jp
	'dvd'                 => ['nav_d',           'DVD'], # .co.jp
	'electronics'         => ['nav_e',           'Electronics'],
	'english-books'       => ['nav_fb',          'English book'], # .co.jp
	'food-beverage'       => ['nav_fb',          'Food & Beverage'], # .co.jp
	'grocery'             => ['nav_gro',         'Grocery & Gourmet Food'],
	'hpc'                 => ['nav_hpc',         'Health & Personal Care'],
	'home-garden'         => ['nav_hg',          'Home & Kitchen'],
	'hi'                  => ['nav_hi',          'Home Improvement'],
	'industrial'          => ['nav_indust',      'Industrial & Scientific'],
	'jewelry'             => ['nav_jw',          'Jewelry'], # nav__jwlry
	'kitchen'             => ['nav_k',           'Kitchen & Dining'],
	'magazines'           => ['nav_mag',         'Magazine Subscriptions'],
	'digital-magazines'   => ['nav_',            'Magazines on Kindle'],
	'instant-movie'       => ['nav_',            'Movies'],
	'movies-tv'           => ['nav_mov',         'Movies & TV'],
	'music'               => ['nav_m',           'Music'],
	'musical-instruments' => ['nav_MI',          'Musical Instruments'],
	'digital-newspapers'  => ['nav_',            'Newspapers on Kindle'],
	'office-products'     => ['nav_op',          'Office & School Supplies'], # nav_office
	'garden'              => ['nav_ol',          'Patio, Lawn & Garden'],
	'pet-supplies'        => ['nav_petsupplies', 'Pet Supplies'],
	'shoes'               => ['nav_shoe',        'Shoes'],
	'software'            => ['nav_sw',          'Software'],
	'sporting-goods'      => ['nav_sg',          'Sports & Outdoors'],
	'instant-tv'          => ['nav_',            'TV'],
	'toys-and-games'      => ['nav_t',           'Toys & Games'], # .com
	'toys'                => ['nav_t',           'Toys'], # .co.jp
	'video'               => ['nav_v',           'Video'], # .co.jp
	'videogames'          => ['nav_vg',          'Video Games'],
	'watch'               => ['nav_w',           'Watches'], # .co.jp
	'watches'             => ['nav_w',           'Watches'], # .com
);

my (%format) = (
	'co.jp' => ['%Y/%m/%d', '%Y/%m'],
	'' => ['%B %d, %Y', '%B %Y'],
);

sub get
{
	my ($self, $type, $max_pages) = @_;

	my $mech = join('::', __PACKAGE__, 'Mechanize')->new(
		email    => $self->{_EMAIL},
		password => $self->{_PASSWORD},
		domain   => $self->{_DOMAIN},
	);
	$mech->login() or die 'login failed';

	my $url = 'https://www.amazon.'.$self->{_DOMAIN}.$url{$type};
	my $content = $mech->get($url);

# TODO: Default to unlimited
	my $pages = $max_pages || 1;

	my $key = exists $format{$self->{_DOMAIN}} ? $self->{_DOMAIN} : '';
	my (@strp) = map { DateTime::Format::Strptime->new(pattern => $_) } @{$format{$key}};

	my $extractor = Template::Extract->new;
# TODO: more relaxed template
# TODO: there might be not date
	my $extract_tmpl = <<'EOF';
[% FOREACH entry %]<tr valign="top">
  <td rowspan="2"><span id="ysNum.[% id %]">[% ... %]</span></td>[% ... %]
  <td align="center" valign="top"><h3 style="margin: 0"><a href="[% url %]"><img src="[% image_url %]"[% ... %]/></a></h3></td>
  <td width="100%">
    <a href="[% ... %]" id="ysProdLink.[% ... %]"><strong>[% title %]</strong></a> <br /> 
    <span id="ysProdInfo.[% ... %]">[% author %][% /(?:<em class="notPublishedYet">)?/ %]([% date %])[% ... %]<span class="price"><b>[% price %]</b>[% ... %]
<tr><td colspan="4"><hr noshade="noshade" size="1" class="divider"></td></tr>[% ... %]
[% END %]
EOF

	my $result = [];
	foreach my $page (1..$pages) {
		$content = $mech->next() if $page != 1;
if(0) {
open my $fh, '>', 'out.html';
print $fh $content;
close $fh;
}
		my $source = $extractor->extract($extract_tmpl, $content);
		foreach my $data (@{$source->{entry}}) {
			$data->{author} =~ s/^\s+//;
			$data->{author} =~ s/\s+$//;
			$data->{url} =~ s,www\.amazon\.\Q$self->{_DOMAIN}\E/.*/dp/,www.amazon.$self->{_DOMAIN}/dp/,;
			$data->{url} =~ s,/ref=[^/]*$,,;

			my $date;
			foreach my $strp (@strp) {
				$date = $strp->parse_datetime($data->{date});
				last if defined $date;
			}
			$data->{date} = $date if defined $date;
		}
		push @$result, @{$source->{entry}};
	}
	return $result;
}

package Net::Amazon::Recommended::Mechanize;

use strict;
use warnings;

use WWW::Mechanize;

my $login_url = '/gp/sign-in.html';

sub new
{
	my ($self, %args) = @_;
	my $class = ref $self || $self;
	my $mech = WWW::Mechanize->new;
	$mech->agent_alias('Windows IE 6'); # Without this line, sign-in is not done
	return bless {
	   _MECH     => $mech,
	   _EMAIL    => $args{email},
	   _PASSWORD => $args{password},
	   _DOMAIN   => $args{domain},
	   _IS_LOGIN => 0,
	}, $class;
}

sub is_login
{
	my ($self, $value) = @_;
	$self->{_IS_LOGIN} = $value if defined $value;
	return $self->{_IS_LOGIN};
}

use Data::Dumper;

sub login
{
	my ($self) = @_;
	return 1 if $self->is_login(); # TODO: handle expiration
	my $mech = $self->{_MECH};
	$mech->get('https://www.amazon.'.$self->{_DOMAIN}.$login_url);
if(0) {
print $mech->uri;
open my $fh, '>', 'before.html';
print $fh $mech->content;
close $fh;
}
	$mech->submit_form(
		form_name => 'sign-in',
		fields => {
			email => $self->{_EMAIL},
			password => $self->{_PASSWORD},
		},
	);
	if($mech->content() =~ m!/errors/validateCaptcha!) {
		$mech->content() =~ m|<img src="([^"]*)">|;
		system "cygstart $1";
		my $value = <STDIN>; chomp $value;
		print $value,"\n";
		$mech->submit_form(
			with_fields => {
				'field-keywords' => $value,
			}
		);
	}
if(0) {
print $mech->uri;
print Data::Dumper->Dump([$mech->cookie_jar]);
open my $fh, '>', 'after.html';
print $fh $mech->content;
close $fh;
}
	return undef if $mech->content() !~ m!http://www\.amazon\.\Q$self->{_DOMAIN}\E/gp/flex/sign-out.html!;
	$self->is_login(1);
	return 1;
}

sub get
{
	my ($self, $url) = @_;
	my $mech = $self->{_MECH};
	$self->login() or return undef;
	$mech->get($url);
0 and print Data::Dumper->Dump([$mech->cookie_jar]);
	return $mech->content();
}

sub next
{
	my ($self, $url) = @_;
	my $mech = $self->{_MECH};
	$mech->follow_link(url_regex => qr/pd_ys_next/);
	return $mech->content();
}

1;
__END__
