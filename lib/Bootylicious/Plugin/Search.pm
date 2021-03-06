package Bootylicious::Plugin::Search;

use strict;
use warnings;

use base 'Mojo::Base';

use Mojo::ByteStream 'b';

__PACKAGE__->attr('before_context' => 20);
__PACKAGE__->attr('after_context'  => 20);
__PACKAGE__->attr('min_length'     => 2);
__PACKAGE__->attr('max_length'     => 256);

sub hook_init {
    my $self = shift;
    my $app = shift;

    my $r = $app->routes;

    $r->route('/search')
      ->to(callback => sub { my $c = shift; _search($self, $c) })
      ->name('search');
}

sub _search {
    my $self = shift;
    my $c = shift;

    my $q = $c->req->param('q');

    my $results = [];

    $c->stash(error => '');

    if (defined $q && length($q) < $self->min_length) {
        $c->stash(error => 'Has to be '
              . $self->min_length
              . ' characters minimal');
    }
    elsif (defined $q && length($q) > $self->max_length) {
        $c->stash(error => 'Has to be '
              . $self->max_length
              . ' characters maximal');
    }
    else {
        if (defined $q) {
            $q = b($q)->xml_escape;

            my ($articles) = main::get_articles;

            my $before_context = $self->before_context;
            my $after_context  = $self->after_context;

            foreach my $article (@$articles) {
                my $found = 0;

                my $title = $article->{title};
                if ($title =~ s/(\Q$q\E)/<font color="red">$1<\/font>/isg) {
                    $found = 1;
                }

                my $parts = [];
                my $content = $article->{content};
                while ($content
                    =~ s/((?:.{$before_context})?\Q$q\E(?:.{$after_context})?)//is
                  )
                {
                    my $part = $1;
                    $part = b($part)->xml_escape->to_string;
                    $part =~ s/(\Q$q\E)/<font color="red">$1<\/font>/isg;
                    push @$parts, $part;

                    $found = 1;
                }

                push @$results, {title => $title, parts => $parts} if $found;
            }
        }
    }

    $c->stash(
        articles       => $results,
        format         => 'html',
        template_class => __PACKAGE__,
        layout         => 'wrapper'
    );
}

1;
__DATA__

@@ search.html.ep
% stash(template_class => 'main');
% stash(title => 'Search');
<div style="text-align:center;padding:2em">
<form method="get">
<input type="text" name="q" value="<%= param('q') || '' %>" />
<input type="submit" value="Search" />
% if ($error) {
<div style="color:red"><%= $error %></div>
% }
</form>
</div>
% if (!$error && param('q')) {
<h1>Search results: <%== @$articles %></h1>
<br />
% }
% foreach my $article (@$articles) {
<div class="text">
    <a href="<%= url(article => $article) %>"><%== $article->{title} %></a><br />
    <div class="created"><%= date($article->{created}) %></div>
%   foreach my $part (@{$article->{parts}}) {
    <span style="font-size:small"><%== $part %></span> ...
%   }
</div>
% }
