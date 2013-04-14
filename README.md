# NAME

Net::Amazon::Recommended - Grab and configurate recommendations by Amazon

# VERSION

version v0.0.0

# SYNOPSIS

    my $obj = Net::Amazon::Recommended->new(
      email => 'someone@example.com',
      password => 'password',
      domain => 'co.jp',
    );
    my $rec = $obj->get('http://www.amazon.co.jp/gp/yourstore/recs/ref=pd_ys_welc');
    print join "\n", map { $_->{title} } @$rec;

# DESCRIPTION

This module obtains recommended items in Amazon by using [WWW::Mechanize](http://search.cpan.org/perldoc?WWW::Mechanize).

To spcify category, you need to specify URL itself. To specify some constants or short-hand key is considered
but currently rejected because category names are dependent on domains and it is difficult to enumerate all
possible sub categories.

# METHODS

## new(`%options`)

Constructor. The following options are available.

- email => $email

    Specify an email as a login ID.

- password => $password

    Specify a password.

- domain => $domain

    Domain of Amazon e.g. `'com'`. Defaults to `'co.jp'`. `'com'`, `'co.uk'` and `'co.jp'` are checked. It might work for other domains.

## get(`$url`, `$max_pages` = 1)

Returns array reference of recommended items.
Each element is a hash reference having the following keys:

- `id`

    ASIN ID.

- `url`

    URL for the item like http://www.amazon.co.jp/dp/4873110963. Just an ASIN is used and other components are stripped.

- `image_url`

    URL of cover image.

- `title`

    Title.

- author

    Author.

- date

    [DateTime](http://search.cpan.org/perldoc?DateTime) object of publish date.

- price

    price in just a string. Currency symbol is included.

- listprice

    list price in just a string. Currency symbol is included.

- otherprice

    price by other sellers in just a string. Currency symbol is included.

`$url` can be sub category page like http://www.amazon.co.jp/gp/yourstore/recs/ref=pd\_ys\_nav\_b\_515826?ie=UTF8&nodeID=515826&parentID=492352&parentStoreNode=492352.

`$max_page` is the limitation of retrieving pages. Defaults to 1. To specify `undef` __explicitly__ means no limitation, that is all recommended items are retrieved.

## get\_list(`$type`, `$max_pages` = 1)

Returns array reference of items in the specified type. `$type` can be `'notinterested'`, `'owned'`, `'purchased'` or `'rated'`.

Each element is a hash reference having the following keys:

- `id`

    ASIN ID.

- `url`

    URL for the item like http://www.amazon.co.jp/dp/4873110963. Just an ASIN is used and other components are stripped.

- `image_url`

    URL of cover image.

- `title`

    Title.

- author

    Author. It might be empty.

- `starRating`

    Rated value for this item from 1 to 5. 0 means not rated.
    This key is avaiable for the case that `$type` is `'owned'`, `'purchased'` or `'rated'`.

- `isNotInterested`

    1 means this item is not interested. 0 means not.
    This key is avaiable for the case that `$type` is `'notinterested'`.

- `isExcluded`

    1 means this item is not considered for recommendation. 0 means considered.
    This key is avaiable for the case that `$type` is `'owned'`, `'purchased'` or `'rated'`.

`$max_page` is the limitation of retrieving pages. Defaults to 1. To specify `undef` __explicitly__ means no limitation, that is all recommended items are retrieved.

## get\_status(`$asin`)

Returns a hash reference having the following keys. If the corresponding item is not found, `undef` is returned.
__Unfortunately__, it seems to be that only `'co.jp'` provides the interface `/gp/rate-it/` used by this method.
Other domains moved to /gp/betterizer/ intefrace.
To set some state by `set_status()` then calling `get_last_status()` or `get_list()` might be used as workaround.

- `starRating`

    Rated value for this item from 1 to 5. 0 means not rated.

- `isOwned`

    1 means this item is owned. 0 means not.

## get\_last\_status(`$type`)

Returns a hash reference having the following keys for the last item of `$type`.

- `starRating`

    Rated value for this item from 1 to 5. 0 means not rated.
    This key is avaiable for the case that `$type` is `'owned'` or `'rated'`.

- `isNotInterested`

    1 means this item is not interested. 0 means not.
    This key is avaiable for the case that `$type` is `'notinterested'`.

- `isExcluded`

    1 means this item is not considered for recommendation. 0 means considered.
    This key is avaiable for the case that `$type` is `'owned'` or `'rated'`.

`$type` is case-insensitive.

## set\_status(`$asin`, `\%args`)

`%arg` is a hash having some of the following keys.

- `starRating`

    Rated value for this item from 1 to 5. 0 means not rated.

- `isOwned`

    1 means this item is owned. 0 means not.

- `isNotInterested`

    1 means this item is not interested. 0 means not.

- `isExcluded`

    1 means this item is not considered for recommendation. 0 means considered.

# TEST

To test this module completely, you need to specify environment variables `AMAZON_EMAIL` and `AMAZON_PASSWORD`.

Because results of some tests are dependent on purchase history, they are marked as TODO.

__CAUTIONS:__ Some tests, `03-status.t`, `05-domain.t` and `06-domain.t` will change your recommendation configurations.

# SEE ALSO

- [WWW::Mechanize](http://search.cpan.org/perldoc?WWW::Mechanize)

# AUTHOR

Yasutaka ATARASHI <yakex@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Yasutaka ATARASHI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
