package Net::Amazon::Recommended;

use strict;
use warnings;

# ABSTRCT: Grab and configurate recommendations by Amazon
# VERSION

use Carp;
use Template::Extract;

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

my %url =
(
	ALL() => '/gp/yourstore/recs/ref=pd_ys_welc',
	NEWRELEASE() => '/gp/yourstore/nr/ref=pd_ys_welc',
	COMINGSOON() => '/gp/yourstore/fr/ref=pd_ys_welc',
);

sub get
{
	my ($self, $type, $max_pages) = @_;

	my $mech = join('::', __PACKAGE__, 'Mechanize')->new(
		%$self
	);
	$self->login($mech, , $self->{_PASSWORD}) or die 'login failed';

	my $content = $mech->get('https://www.amazon'.$self->{_DOMAIN}.$url{$type});

	# TODO: Default to unlimited
	my $pages = $max_pages || 1;

	my $result = [];
	foreach my $page (1..$pages) {
		$content = $mech->next() if $page != 1;
		my $extractor = Template::Extract->new;

		my $source = $extractor->extract($self->tmpl_ext, $content);
		$source->{category} =~ s/<[^>]*>//g;
		$source->{category} =~ s/\n//g;
		$source->{category} =~ s/^&gt;//;
		$source->{category} = [ split /&gt;/, $source->{category} ];

		foreach my $data (@{$source->{entry}}) {
			$data->{author} =~ s/^\s+//;
			$data->{author} =~ s/\s+$//;
# TODO: Adjust URL
			$data->{url} =~ s,www\.amazon\.co\.jp/.*/dp/,www.amazon.co.jp/dp/,;
			$data->{url} =~ s,/ref=[^/]*$,,;

# TODO: Use alternative module
			my $date = Plagger::Date->strptime('%mŒŽ %d, %Y', $data->{date});
			$date = Plagger::Date->strptime('%mŒŽ, %Y', $data->{date}) if !defined($date);
			if(defined $date) {
				$date->set_time_zone('Asia/Tokyo'); # set floating datetime
				$date->set_time_zone(Plagger->context->conf->{timezone} || 'local');
			}
# TODO: Set back to date
		}
		push @$result, @{$source->{entry}};
	}
	return $result;
}

package Net::Amazon::Recommended::Mechanize;

use strict;
use warnings;

use WWW::Mechanize;

my $login_url = 'https://www.amazon.co.jp/gp/sign-in.html';

sub new
{
	my ($self, %args) =shift;
	my $class = ref $self || $self;
	my $mech = WWW::Mechanize->new;
	return bless {
	   _MECH     => $mech,
	   _EMAIL    => $args{email},
	   _PASSWORD => $args{password},
	   _IS_LOGIN => 0,
	}, $class;
}

sub is_login
{
	my ($self, $value) = @_;
	$self->{_IS_LOGIN} = $value if defined $value;
	return $self->{_IS_LOGIN};
}

sub login
{
	my ($self) = @_;
	return 1 if $self->is_login(); # TODO: handle expiration
	my $mech = $self->mech;
	$mech->get($login_url);
	$mech->submit_form(
		form_name => 'sign-in',
			fields => {
			email => $self->email,
			password => $self->password,
		},
	);
	return undef if $mech->content() =~ m!http://www.amazon.co.jp/gp/yourstore/ref=pd_irl_gw?ie=UTF8&amp;signIn=1!;
	$self->is_login(1);
	return 1;
}

sub get
{
   my ($self, $url) = @_;
   my $mech = $self->mech;
   $self->login() or return undef;
  $mech->get($url);
   return $mech->content();
}

sub next
{
	my ($self, $url) = @_;
	my $mech = $self->mech;
	$mech->follow_link(url_regex => qr/pd_ys_next/);
	return $mech->content();
}

1;
__DATA__
<table width="100%">
<tr><td>
<a href="/gp/yourstore/[% ... %]/ref=pd_ys_welc">[% ... %]</a>
[% category %]
</td></tr>
</table>[% ... %][% FOREACH entry %]<tr valign="top">
  <td rowspan="2"><span id="ysNum.[% id %]">[% ... %]</span></td>
  <td align="center" valign="top"><h3 style="margin: 0"><a href="[% url %]"><img src="[% image_url %]"[% ... %]/></a></h3></td>
  <td width="100%">
    <a href="[% ... %]" id="ysProdLink.[% ... %]"><strong>[% title %]</strong></a> <br /> 
    <span id="ysProdInfo.[% ... %]">[% author %][% /(?:<em class="notPublishedYet">)?/ %]([% date %])[% ... %]<span class="price"><b>[% price %]</b>[% ... %]
<tr><td colspan="4"><hr noshade="noshade" size="1" class="divider"></td></tr>
[% ... %]
[% END %]
__END__
