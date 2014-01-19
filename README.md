twitrssme
=========

Forked from: TwitRSS.me code

Amended by Joel Berger for the [Mojolicious](http://mojolicio.us) framework.

Recommended nonblocking deployment is `hypnotoad twitter_rss_nonblocking.pl`, which will start the application on localhost:8080.
To stop it run `hypnotoad -s twitter_rss_nonblocking.pl`.

For a simpler, but still nonblocking is `./twitter_rss_nonblocking.pl daemon`.

The blocking version may be run under non-mojolicious servers like plackup (or even under CGI though the file structure has changed somewhat).

EDIT: I have now added a portable version of the code which works under all mojolicious, psgi, and cgi servers.
I am leaving the original separate versions as examples.

It is released under the same terms as the original.
