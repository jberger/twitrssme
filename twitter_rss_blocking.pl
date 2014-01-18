#!/usr/bin/env perl
use Mojolicious::Lite;
use POSIX qw(strftime);

use Mojo::Collection;
use Mojo::URL;

app->secrets(['This secret protects things and should be changed']);

helper base_url => sub { state $base = Mojo::URL->new('https://twitter.com'); $base->clone };
helper user_url => sub { 
  my ($self, $user, $replies) = @_;
  my $url = $self->base_url->path($user);
  push @{$url->path->parts}, 'with_replies' if $replies;
  return $url;
};

helper heavy_users => sub {
  my ($self, $reload) = @_;
  state $users;

  unless ($users or $reload) {
	  open my $in, '<', 'heavy_users' or die 'No heavy_users file';
    $users = Mojo::Collection->new(<$in>);
  }

  return $users;
};

helper parse_tweet => sub {
  my ($self, $dom) = @_;

  my $body = $dom->at('p.tweet-text')->content_xml;
  $body = "<![CDATA[$body]]>";

  my $header    = $dom->at('div.stream-item-header');
  my $avatar    = $header->at('a img.avatar')->{src};
  my $fullname  = $header->at('.fullname')->all_text;
  my $username  = '@' . $header->at('.username b')->text;
  my $ts        = $header->at('.tweet-timestamp');
  my $uri       = $self->base_url->path( $ts->{href} );
  my $timestamp = $ts->at('[data-time]')->{'data-time'};

  my $pub_date = strftime("%a, %d %b %Y %H:%M:%S %z", localtime($timestamp));

  return {
    username    => $username,
    fullname    => $fullname,
    link        => $uri,
    guid        => $uri,
    title       => "$username: $body",
    description => $body,
    timestamp   => $timestamp,
    pubDate     => $pub_date,
  }
};

any '/' => sub { shift->render_static( 'index.html' ) };

get '/twitter_user_to_rss' => sub {
  my $self = shift;
  my $user = lc $self->param('user') || 'ciderpunx';
  my $replies = $self->param('replies') || 0;

  $self->render_not_found if $user =~ '^#';

  $user=~s/(@|\s)//g;
  $user=~s/%40//g;

  my $max_age = $self->heavy_users->first($user) ? 86400 : 1800;
  my $url = $self->user_url($user, $replies);

  $self->app->log->info($user);

  my $tx = $self->ua->get($url);
  unless ($tx->success) { 
    return $self->render_exception(scalar $tx->error);
  }

  my $tweets = $tx->res->dom('li.js-stream-item > div');
  my $items  = $tweets->map(sub{$self->parse_tweet($_)});  

  $self->res->headers->cache_control("max-age=$max_age");
  $self->render( 'atom', format => 'rss', user => $user, items => $items );
};

app->start;

__DATA__

@@ atom.rss.ep

<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:georss="http://www.georss.org/georss" xmlns:twitter="http://api.twitter.com" version="2.0">
  <channel>
    <title>Twitter Search / $user </title>
    <link>http://twitter.com/$user</link>
    <description>Twitter feed for: $user.</description>
    <language>en-us</language>
    <ttl>40</ttl>
    % for (@$items) {
      <item>
        <title><%== $_->{title} %></title>
        <description><%== $_->{description}%></description>
        <pubDate><%== $_->{pubDate}%></pubDate>
        <guid><%== $_->{guid}%></guid>
        <link><%== $_->{link}%></link>
        <twitter:source/>
        <twitter:place/>
      </item>
    % }
  </channel>
</rss>      

