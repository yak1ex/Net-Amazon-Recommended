# NAME

Net::Amazon::Recommended - Grab and configurate recommendations by Amazon

# VERSION

version v0.0.0

# SYNOPSIS

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

    Domain of Amazon e.g. `'.com'`. Defaults to `'.co.jp'`.

## get(`$url`, `$max_pages` = 1)

Returns array reference of recommended items.
Each element is a hash reference having the following keys:

- `id`

    ASIN ID.

- `url`

    URL for the item like http://www.amazon.co.jp/dp/4873110963. Just an ASIN is used.

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

`$url` can be sub category page like http://www.amazon.co.jp/gp/yourstore/recs/ref=pd\_ys\_nav\_b\_515826?ie=UTF8&nodeID=515826&parentID=492352&parentStoreNode=492352.

`$max_page` is the limitation of retrieving pages. Defaults to 1.

# TEST

To test completely, you need to specify environment variables `AMAZON_EMAIL` and `AMAZON_PASSWORD`.

# SEE ALSO

- [WWW::Mechanize](http://search.cpan.org/perldoc?WWW::Mechanize)

# AUTHOR

Yasutaka ATARASHI <yakex@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Yasutaka ATARASHI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.