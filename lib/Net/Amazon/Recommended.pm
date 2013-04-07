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
	return bless {
		_EMAIL => $args{email},
		_PASSWORD => $args{password},
		_DOMAIN => $args{domain} || 'co.jp',
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

sub get
{
	my ($self, $url, $max_pages) = @_;

	my $mech = join('::', __PACKAGE__, 'Mechanize')->new(
		email    => $self->{_EMAIL},
		password => $self->{_PASSWORD},
		domain   => $self->{_DOMAIN},
	);
	$mech->login() or die 'login failed';

	my $content;

# TODO: Default to unlimited
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
	if(defined eval { $mech->follow_link(url_regex => qr/pd_ys_next/) }) {
		return $mech->content();
	} else {
		return undef;
	}
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

=head1 METHODS

=method new(C<%options>)

Constructor. The following options are available.

=over 4

=item email =E<gt> $email

Specify an email as a login ID.

=item password =E<gt> $password

Specify a password.

=item domain =E<gt> $domain

Domain of Amazon e.g. C<'com'>. Defaults to C<'co.jp'>.

=back

=method get(C<$url>, C<$max_pages> = 1)

Returns array reference of recommended items.
Each element is a hash reference having the following keys:

=over 4

=item C<id>

ASIN ID.

=item C<url>

URL for the item like http://www.amazon.co.jp/dp/4873110963. Just an ASIN is used and other components are stripped.

=item C<image_url>

URL of cover image.

=item C<title>

Title.

=item author

Author.

=item date

L<DateTime> object of publish date.

=item price

price in just a string. Currency symbol is included.

=back

C<$url> can be sub category page like http://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_nav_b_515826?ie=UTF8&nodeID=515826&parentID=492352&parentStoreNode=492352.

C<$max_page> is the limitation of retrieving pages. Defaults to 1. To specify C<undef> B<explicitly> means no limitation, that is all recommended items are retrieved.

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
