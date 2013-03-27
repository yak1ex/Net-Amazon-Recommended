package Net::Amazon::Recommended;

use strict;
use warnings;

# ABSTRCT: Grab and configurate recommendations by Amazon
# VERSION

use Template::Extract;

# m!http://www\.amazon\.co\.jp/gp/yourstore/(recs|nr|fr)/!)

sub aggregate
{
	my ($self, $context, $args) = @_;

	my $mech = join('::', __PACKAGE__, 'Mechanize')->new($self);
	$mech->login or $context->error('login failed');

	my $content = $mech->get($args->{feed}->url);

	my $pages = $self->conf->{pages} || 1;

	my $feed = $args->{feed};
	foreach my $page (1..$pages) {
		$content = $mech->next() if $page != 1;
		my $extractor = Template::Extract->new;

		my $source = $extractor->extract($self->tmpl_ext, $content);
		$source->{category} =~ s/<[^>]*>//g;
		$source->{category} =~ s/\n//g;
		$source->{category} =~ s/^&gt;//;
		$source->{category} = [ split /&gt;/, $source->{category} ];

# TODO: No need to set multiple times
		my $type;
		$type = '[すべて] ' if $args->{feed}->url =~ /recs/;
		$type = '[ニューリリース情報] ' if $args->{feed}->url =~ /nr/;
		$type = '[まもなく発売] ' if $args->{feed}->url =~ /fr/;
		$feed->title('Amazon おすすめ: ' . $type . join(' > ', @{$source->{category}}));
		$feed->link($feed->url);
		$feed->description($feed->title);

		foreach my $data (@{$source->{entry}}) {
			$data->{author} =~ s/^\s+//;
			$data->{author} =~ s/\s+$//;
			$data->{url} =~ s,www\.amazon\.co\.jp/.*/dp/,www.amazon.co.jp/dp/,;
			$data->{url} =~ s,/ref=[^/]*$,,;
			my $body = $self->templatize('output.tmpl', $data);

			my $date = Plagger::Date->strptime('%m月 %d, %Y', $data->{date});
			$date = Plagger::Date->strptime('%m月, %Y', $data->{date}) if !defined($date);
			if(defined $date) {
				$date->set_time_zone('Asia/Tokyo'); # set floating datetime
				$date->set_time_zone(Plagger->context->conf->{timezone} || 'local');
			}

			my $entry = Plagger::Entry->new;
			$entry->title($data->{title});
			$entry->link($data->{url});
			$entry->body($body);
			$entry->date($date);
			$entry->author($data->{author});
			$feed->add_entry($entry);
		}
	}
	$context->update->add($feed);
}

package Plagger::Plugin::CustomFeed::AmazonRecommend::Mechanize;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);

use Plagger::Mechanize;

__PACKAGE__->mk_accessors(qw(mech email password is_login));

my $login_url = 'https://www.amazon.co.jp/gp/sign-in.html';

sub new
{
	my $class =shift;
	my $plugin = shift;
	my $mech = Plagger::Mechanize->new;
	return bless {
		mech     => $mech,
		email    => $plugin->conf->{email},
		password => $plugin->conf->{password},
		is_login => 0,
	}, $class;
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

# TODO?: AUTOLOAD to transfer Plagger::Mechanize

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
