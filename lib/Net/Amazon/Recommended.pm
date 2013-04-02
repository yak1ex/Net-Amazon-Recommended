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

# URL: /gp/yourstore/<type>/ref=pd_ys_<category>?rGroup=<category_>
# type: recs (All), nr (New Release), fr (Coming soon)
# category, category_: depends on domain

my (%format) = (
	'co.jp' => ['%Y/%m/%d', '%Y/%m'],
	'' => ['%B %d, %Y', '%B %Y'],
);

sub get
{
	my ($self, $url, $max_pages) = @_;

	my $mech = join('::', __PACKAGE__, 'Mechanize')->new(
		email    => $self->{_EMAIL},
		password => $self->{_PASSWORD},
		domain   => $self->{_DOMAIN},
	);
	$mech->login() or die 'login failed';

	my $content = $mech->get($url);

# TODO: Default to unlimited
	my $pages = $max_pages || 1;

	my $key = exists $format{$self->{_DOMAIN}} ? $self->{_DOMAIN} : '';
	my (@strp) = map { DateTime::Format::Strptime->new(pattern => $_) } @{$format{$key}};

	my $extractor = Template::Extract->new;
# TODO: more relaxed template
# TODO: there might be not date
	my $extract_tmpl = <<'EOF';
<div class="head">[% ... %]<br />[% category %]</div>[% ... %]
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
	$mech->follow_link(url_regex => qr/pd_ys_next/);
	return $mech->content();
}

1;
__END__
