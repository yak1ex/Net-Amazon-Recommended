package Net::Amazon::Recommended;

use strict;
use warnings;

# ABSTRACT: Grab and configurate recommendations by Amazon
# VERSION

use Carp;
use Template::Extract;
use DateTime::Format::Strptime;
use Data::Section -setup;

sub new
{
	my $self = shift;
	my $class = ref $self || $self;
	my %args = @_;
	croak 'email andd password are required' if ! exists $args{email} || ! exists $args{password};
	$args{domain} ||= 'co.jp';
	return bless {
		_DOMAIN => $args{domain},
		_MECH => join('::', __PACKAGE__, 'Mechanize')->new(
			email    => $args{email},
			password => $args{password},
			domain   => $args{domain},
		),
	}, $class;
}

# URL: /gp/yourstore/<type>/ref=pd_ys_<category>?rGroup=<category_>
# type: recs (All), nr (New Release), fr (Coming soon)
# category, category_: depends on domain

my (%format) = (
	'co.jp' => ['%Y/%m/%d', '%Y/%m'],
	'' => ['%B %d, %Y', '%B %Y'],
);

my $NOTFOUND_REGEX = ${__PACKAGE__->section_data('NOTFOUND_REGEX')};

# TODO: more relaxed template
# TODO: there might be not date
my $extractor = Template::Extract->new;
my $EXTRACT_REGEX = $extractor->compile(${__PACKAGE__->section_data('EXTRACT_RECS_TMPL')});
my $EXTRACT_STATUS_REGEX = $extractor->compile(${__PACKAGE__->section_data('EXTRACT_STATUS_TMPL')});
my $EXTRACT_LIST_REGEX = $extractor->compile(${__PACKAGE__->section_data('EXTRACT_LIST_TMPL')});

my %URL = (
	root => '/',
	login => '/gp/sign-in.html',
	logout => '/gp/flex/sign-out.html',
	rate => '/gp/rate-it/ref=pd_ys_wizard_search?rateIndex=search-alias%3Daps&rateKeywords=',
	submit => '/gp/yourstore/ratings/submit.html/ref=pd_recs_rate_dp_ys_ir_all',
	owned => '/gp/yourstore/iyr/ref=pd_ys_iyr_edit_own?ie=UTF8&collection=owned',
	notinterested => '/gp/yourstore/iyr/ref=pd_ys_iyr_edit_notInt?ie=UTF8&collection=notInt',
	rated => '/gp/yourstore/iyr/ref=pd_ys_iyr_edit_rated?ie=UTF8&collection=rated',
	purchased => '/gp/yourstore/iyr?ie=UTF8&collection=purchased',
);

my %VALID = (
	rate => [qw(itemId starRating isOwned)],
	owned => [qw(itemId starRating isExcluded)],
	notinterested => [qw(itemId isNotInterested)],
	rated => [qw(itemId starRating isExcluded)],
	purchased => [qw(itemId starRating isExcluded)],
);

sub _url
{
	my ($self, $type) = @_;
	return 'https://www.amazon.'.$self->{_DOMAIN}.$URL{lc $type};
}

sub get
{
	my ($self, $url, $max_pages) = @_;

	my $mech = $self->{_MECH};
	$mech->login() or die 'login failed';

	my $content;

	my $pages = @_ >= 3 ? $max_pages : 1;

	my $key = exists $format{$self->{_DOMAIN}} ? $self->{_DOMAIN} : '';
	my (@strp) = map { DateTime::Format::Strptime->new(pattern => $_) } @{$format{$key}};

	my $result = [];
	while(! defined $pages || --$pages >= 0) {
		if(defined $content) { # Successive invocation
			$content = $mech->next();
		} else { # First invocation
			$content = $mech->get($url);
		}
		last if ! defined $content; # Can't get content because next link does not exist, or some reasons
		last if $content =~ /$NOTFOUND_REGEX/;

if(0) {
open my $fh, '>', 'out.html';
print $fh $content;
close $fh;
}
		my $source = $extractor->run($EXTRACT_REGEX, $content);
		croak 'Non existent category' if $url =~ /\b(rGroup|nodeId)\b/ && $source->{category} eq '';
		foreach my $data (@{$source->{entry}}) {
			$data->{author} =~ s/^\s+//;
			$data->{author} =~ s/\s+$//;
			my $root = $self->_url('root');
			$root =~ s,^https://,,;
			$data->{url} =~ s,\Q$root\E.*/dp/,${root}dp/,;
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

sub get_list
{
	my ($self, $type, $max_pages) = @_;
	my $url = $self->_url($type);

	my $mech = $self->{_MECH};
	$mech->login() or die 'login failed';

	my $content;

	my $pages = @_ >= 3 ? $max_pages : 1;

	my $result = [];
	while(! defined $pages || --$pages >= 0) {
		if(defined $content) { # Successive invocation
			$content = $mech->next();
		} else { # First invocation
			$content = $mech->get($url);
		}
		last if ! defined $content; # Can't get content because next link does not exist, or some reasons

		my $source = $extractor->run($EXTRACT_LIST_REGEX, $content);
		foreach my $data (@{$source->{entry}}) {
			$data->{author} =~ s/^\s+//;
			$data->{author} =~ s/\s+$//;
			my $root = $self->_url('root');
			$root =~ s,^https://,,;
			$data->{url} =~ s,\Q$root\E.*/dp/,${root}dp/,;
			$data->{url} =~ s,/ref=[^/]*$,,;
# It looks like easy thing to handle inside Template::Extract, but I can't achieve it...
			my (%result) = map { /^\s*(\S*)\s*$/; } map { split /:/ } split /,/, delete $data->{values};
			$data->{$_} = $result{$_} for @{$VALID{lc $type}};
		}
		push @$result, @{$source->{entry}};
	}
	return $result;
}

sub _get_status
{
	my ($self, $type, $url) = @_;
	my $mech = $self->{_MECH};
	$mech->login() or die 'login failed';
	my $content = $mech->get($url);
# It looks like easy thing to handle inside Template::Extract, but I can't achieve it...
	my $source = $extractor->run($EXTRACT_STATUS_REGEX, $content);
	return if ! exists $source->{values};
	my (%result) = map { /^\s*(\S*)\s*$/; } map { split /:/ } split /,/, $source->{values};
	return { map { $_ => $result{$_} } @{$VALID{lc $type}} };
}

sub get_status
{
	my ($self, $asin) = @_;
	return $self->_get_status('rate', $self->_url('rate').$asin);
}

sub get_last_status
{
	my ($self, $type) = @_;
	return $self->_get_status($type, $self->_url($type));
}

my %PARAM = (
	starRating => ['onetofive',[0,1,2,3,4,5]],
	isNotInterested => ['not-interested', ['NONE', 'NOTINTERESTED']],
	isOwned => ['owned',['NONE', 'OWN']],
	isExcluded => ['excluded',['NONE', 'EXCLUDED']],
	isExcludedClickstream => ['excludedClickstream', ['NONE', 'EXCLUDED']],
	isGift => ['isGift', ['NONE', 'ISGIFT']],
	isPreferred => ['isPreferred', ['NONE', 'ISPREFERRED']],
);

sub set_status
{
	my ($self, $asin, $param) = @_;
	my $mech = $self->{_MECH};
	$mech->login() or die 'login failed';
	my $dat = {
		rating_asin => $asin,
		'rating.source' => 'ir',
		type => 'asin',
		'return.response' => '204',
		'template-name' => '/gp/yourstore/recs/ref=pd_ys_welc',
	};
	foreach my $key (keys %$param) {
		if(exists $PARAM{$key}) {
			$dat->{$asin.'_asin.rating.'.$PARAM{$key}[0]} = $PARAM{$key}[1][$param->{$key}];
		}
	}
#print Data::Dumper->Dump([$dat]);
	my $content = $mech->post($self->_url('submit'), $dat);
if(0) {
open my $fh, '>', 'set.html';
print $fh $content;
close $fh;
}
}

package Net::Amazon::Recommended::Mechanize;

use strict;
use warnings;

use WWW::Mechanize;

sub _url
{
	my ($self, $type) = @_;
	return 'https://www.amazon.'.$self->{_DOMAIN}.$URL{lc $type};
}

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
	$mech->get($self->_url('login'));
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
	my $url = $self->_url('logout'); $url =~ s/^https/http/;
	return if $mech->content() !~ /\Q$url\E/;
	$self->is_login(1);
	return 1;
}

sub get
{
	my ($self, $url) = @_;
	my $mech = $self->{_MECH};
	$self->login() or return;
	$mech->get($url);
0 and print Data::Dumper->Dump([$mech->cookie_jar]);
	return $mech->content();
}

sub next
{
	my ($self, $url) = @_;
	my $mech = $self->{_MECH};
	if($mech->content =~ m|<a href="(/gp/yourstore/iyr/ref=pd_ys_iyr_next\?[^"]+)">|) {
		my $url = $1;
		$url =~ s/&amp;/&/g;
		$mech->get($url);
		return $mech->content();
	} elsif(defined eval { $mech->follow_link(url_regex => qr/pd_ys_next/) }) {
		return $mech->content();
	} else {
		return;
	}
}

sub post
{
	my ($self, $url, $param) = @_;
	my $mech = $self->{_MECH};
	$self->login() or return;
	$mech->cookie_jar->scan(sub {
		 $param->{'session-id'} = $_[2] if $_[1] eq 'session-id';
	});
	$mech->post($url, $param);
	return $mech->content();
}

package Net::Amazon::Recommended;
1;

=pod

=head1 SYNOPSIS

  my $obj = Net::Amazon::Recommended->new(
    email => 'someone@example.com',
    password => 'password',
    domain => 'co.jp',
  );
  my $rec = $obj->get('http://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_welc');
  print join "\n", map { $_->{title} } @$rec;

=head1 DESCRIPTION

This module obtains recommended items in Amazon by using L<WWW::Mechanize>.

To spcify category, you need to specify URL itself. To specify some constants or short-hand key is considered
but currently rejected because category names are dependent on domains and it is difficult to enumerate all
possible sub categories.

=method new(C<%options>)

Constructor. The following options are available.

=for :list
= email =E<gt> $email
Specify an email as a login ID.
= password =E<gt> $password
Specify a password.
= domain =E<gt> $domain
Domain of Amazon e.g. C<'com'>. Defaults to C<'co.jp'>.

=method get(C<$url>, C<$max_pages> = 1)

Returns array reference of recommended items.
Each element is a hash reference having the following keys:

=for :list
= C<id>
ASIN ID.
= C<url>
URL for the item like http://www.amazon.co.jp/dp/4873110963. Just an ASIN is used and other components are stripped.
= C<image_url>
URL of cover image.
= C<title>
Title.
= author
Author.
= date
L<DateTime> object of publish date.
= price
price in just a string. Currency symbol is included.

C<$url> can be sub category page like http://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_b_515826?ie=UTF8&nodeID=515826&parentID=492352&parentStoreNode=492352.

C<$max_page> is the limitation of retrieving pages. Defaults to 1. To specify C<undef> B<explicitly> means no limitation, that is all recommended items are retrieved.

=method get_status(C<$asin>)

Returns a hash reference having the following keys. If the corresponding item is not found, C<undef> is returned.

=for :list
= C<starRating>
Rated value for this item from 1 to 5. 0 means not rated.
= C<isOwned>
1 means this item is owned. 0 means not.

=method get_last_status(C<$type>)

Returns a hash reference having the following keys for the last item of C<$type>.

=for :list
= C<starRating>
Rated value for this item from 1 to 5. 0 means not rated.
This key is avaiable for the case that C<$type> is C<'owned'> or C<'rated'>.
= C<isNotInterested>
1 means this item is not interested. 0 means not.
This key is avaiable for the case that C<$type> is C<'notinterested'>.
= C<isExcluded>
1 means this item is not considered for recommendation. 0 means considered.
This key is avaiable for the case that C<$type> is C<'owned'> or C<'rated'>.

C<$type> is case-insensitive.

=method set_status(C<$asin>, C<\%args>)

C<%arg> is a hash having some of the following keys.

=for :list
= C<starRating>
Rated value for this item from 1 to 5. 0 means not rated.
= C<isOwned>
1 means this item is owned. 0 means not.
= C<isNotInterested>
1 means this item is not interested. 0 means not.
= C<isExcluded>
1 means this item is not considered for recommendation. 0 means considered.

=head1 TEST

To test this module completely, you need to specify environment variables C<AMAZON_EMAIL> and C<AMAZON_PASSWORD>.

Because results of some tests are dependent on purchase history, they are marked as TODO.

=head1 SEE ALSO

=for :list
* L<WWW::Mechanize>

=cut

__DATA__
__[ NOTFOUND_REGEX ]__
<tr><td colspan="4"><hr  class="divider" noshade="noshade" size="1"/></td></tr>
<tr> 
<td colspan="4"><table bgcolor="#ffffee" cellpadding="5" cellspacing="0" width="100%">
<tr> 
<td class="small"><span class="h3color"><b>[^<]*</b></span><br />
[^<]*
</td>
</tr>
</table></td>
</tr>
__[ EXTRACT_RECS_TMPL ]__
<div class="head">[% ... %]<br />[% category %]</div>[% ... %]
[% FOREACH entry %]<tr valign="top">
  <td rowspan="2"><span id="ysNum.[% id %]">[% ... %]</span></td>[% ... %]
  <td align="center" valign="top"><h3 style="margin: 0"><a href="[% url %]"><img src="[% image_url %]"[% ... %]/></a></h3></td>
  <td width="100%">
    <a href="[% ... %]" id="ysProdLink.[% ... %]"><strong>[% title %]</strong></a> <br /> 
    <span id="ysProdInfo.[% ... %]">[% author %][% /(?:<em class="notPublishedYet">)?/ %]([% date %])[% ... %]<span class="price"><b>[% price %]</b>[% ... %]
<tr><td colspan="4"><hr noshade="noshade" size="1" class="divider"></td></tr>[% ... %]
[% END %]
__[ EXTRACT_STATUS_TMPL ]__
<script language="Javascript" type="text/javascript">
amznJQ.onReady('amzn-ratings-bar-init', function() {
    jQuery([% ... %]).amazonRatingsInterface({
[% values %]
    });
});
</script>
__[ EXTRACT_LIST_TMPL ]__
[% FOREACH entry %]<tr valign=middle id="iyrListItem[% id %]">[% ... %]
<a href="[% url %]"><img src="[% image_url %]"[% ... %]/></a>[% ... %]
<a href="[% ... %]">[% title %]</a>
</b><br /><span id="iyrListItemByline[% ... %]">[% author %]</span><br />[% ... %]
<script language="Javascript" type="text/javascript">
amznJQ.onReady('amzn-ratings-bar-init', function() {
    jQuery([% ... %]).amazonRatingsInterface({
[% values %]
    });
});
</script>
</td>

</tr>
<tr>
<td colspan=4><hr noshade color="#cccc99" width=100% size=1></td>
</tr>[% ... %]
[% END %]
