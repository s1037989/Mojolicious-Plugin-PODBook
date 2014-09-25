package Mojolicious::Plugin::PODBook;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Mojo::DOM;
use Mojo::URL;
use Mojo::Util qw(slurp unindent url_escape);
use Pod::Simple::XHTML 3.09;
use Pod::Simple::Search;

use File::Basename qw/ basename dirname /;
use File::Spec::Functions qw/ catdir /;

binmode STDOUT, ":utf8";

sub register {
  my ($self, $app, $conf) = @_;

  push @{ $app->renderer->paths }, catdir dirname(__FILE__), 'PODBook', 'templates';
  my $preprocess = $conf->{preprocess} || 'ep';
  $app->renderer->add_handler(
    $conf->{name} || 'pod' => sub {
      my ($renderer, $c, $output, $options) = @_;

      # Preprocess and render
      my $handler = $renderer->handlers->{$preprocess};
      return undef unless $handler->($renderer, $c, $output, $options);
      $$output = _pod_to_html($$output);
      return 1;
    }
  );

  $app->helper(podbook => sub {
    my $app = shift;
    my $base = shift;
    my $sections = shift;
    my $text = shift;
    say qq(<!DOCTYPE html>\n<html lang="en-US">\n<head><title></title></head><body>\n);
    say $app->ua->get($base)->res->dom->find($text);
    $app->ua->get($base)->res->dom->find($_)->attr("href")->map(sub { s!^#!$base/!g;s!-!/!g;$_ })->each(sub{
      warn "$_\n";
      say $app->ua->get($_)->res->dom->find($text)
    }) foreach @$sections;
    say qq(</body></html>);
  });

  $app->helper(pod_to_html => sub { shift; b(_pod_to_html(@_)) });

  # Perldoc browser
  return undef if $conf->{no_perldoc};
  my $defaults = {module => 'Mojolicious/Guides', format => 'html'};
  return $app->routes->any(
    '/perldoc/:module' => $defaults => [module => qr/[^.]+/] => \&_perldoc);
}

sub _html {
  my ($c, $src) = @_;

  # Rewrite links
  my $dom     = Mojo::DOM->new(_pod_to_html($src));
  my $perldoc = $c->url_for('/perldoc/');
  my $module  = $c->param('module');
  $module =~ s/\//-/g;
  do { $_->{href} =~ /\// ? $_->{href} =~ s/#/-/g : $_->{href} =~ s/#/#$module-/g; $_->{href} =~ s!^http://metacpan\.org/pod/!#! and $_->{href} =~ s!::!-!gi}
    for $dom->find('a[href]')->attr->each;

  # Rewrite code blocks for syntax highlighting and correct indentation
  for my $e ($dom->find('pre > code')->each) {
    $e->content(my $str = unindent $e->content);
    next if $str =~ /^\s*(?:\$|Usage:)\s+/m || $str !~ /[\$\@\%]\w|-&gt;\w/m;
    my $attrs = $e->attr;
    my $class = $attrs->{class};
    $attrs->{class} = defined $class ? "$class prettyprint" : 'prettyprint';
  }

  # Rewrite headers
  my $toc = Mojo::URL->new->fragment("$module-toc");
  my $Module = $module;
  $Module =~ s/-/::/g;
  my @parts = [$Module, Mojo::URL->new->fragment($module)];
  for my $e ($dom->find('h1, h2, h3')->each) {
    push @parts, [] if $e->type eq 'h1' || !@parts;
    my $anchor = "$module-$e->{id}";
    #$e->{href} =~ s/^#([^#]+)/#$module-$1/;
    my $link   = Mojo::URL->new->fragment($anchor);
    push @{$parts[-1]}, my $text = $e->all_text, $link;
    my $permalink = $c->link_to('#' => $link, class => 'permalink');
    $e->content($c->link_to($text => $toc, id => $anchor));
  }

  # Try to find a title
  my $title = 'Perldoc';
  $dom->find('h1 + p')->first(sub { $title = shift->text });

  # Combine everything to a proper response
  $c->content_for(perldoc => "$dom");
  #warn $c->app->renderer->get_data_template({
  #  template       => 'podbook',
  #  format         => 'html',
  #  handler        => 'ep'
  #});
  $c->render('podbook', title => $title, parts => \@parts);
}

sub _perldoc {
  my $c = shift;

  # Find module or redirect to CPAN
  my $module = join '::', split '/', scalar $c->param('module');
  my $path
    = Pod::Simple::Search->new->find($module, map { $_, "$_/pods" } @INC);
  return $c->redirect_to("http://metacpan.org/pod/$module")
    unless $path && -r $path;

  my $src = slurp $path;
  $c->respond_to(txt => {data => $src}, html => sub { _html($c, $src) });
}

sub _pod_to_html {
  return '' unless defined(my $pod = ref $_[0] eq 'CODE' ? shift->() : shift);

  my $parser = Pod::Simple::XHTML->new;
  $parser->perldoc_url_prefix('http://metacpan.org/pod/');
  $parser->$_('') for qw(html_header html_footer);
  $parser->output_string(\(my $output));
  return $@ unless eval { $parser->parse_string_document("$pod"); 1 };

  return $output;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::PODBook - POD renderer plugin

=head1 SYNOPSIS

  # Mojolicious
  my $route = $self->plugin('PODBook');
  my $route = $self->plugin(PODBook => {name => 'foo'});
  my $route = $self->plugin(PODBook => {preprocess => 'epl'});

  # Mojolicious::Lite
  my $route = plugin 'PODBook';
  my $route = plugin PODBook => {name => 'foo'};
  my $route = plugin PODBook => {preprocess => 'epl'};

  # foo.html.ep
  %= pod_to_html "=head1 TEST\n\nC<123>"

=head1 DESCRIPTION

L<Mojolicious::Plugin::PODBook> is a renderer for true Perl hackers, rawr!

The code of this plugin is a good example for learning to build new plugins,
you're welcome to fork it.

See L<Mojolicious::Plugins/"PLUGINS"> for a list of plugins that are available
by default.

=head1 OPTIONS

L<Mojolicious::Plugin::PODBook> supports the following options.

=head2 name

  # Mojolicious::Lite
  plugin PODBook => {name => 'foo'};

Handler name, defaults to C<pod>.

=head2 no_perldoc

  # Mojolicious::Lite
  plugin PODBook => {no_perldoc => 1};

Disable L<Mojolicious::Guides> documentation browser that will otherwise be
available under C</perldoc>.

=head2 preprocess

  # Mojolicious::Lite
  plugin PODBook => {preprocess => 'epl'};

Name of handler used to preprocess POD, defaults to C<ep>.

=head1 HELPERS

L<Mojolicious::Plugin::PODBook> implements the following helpers.

=head2 pod_to_html

  %= pod_to_html '=head2 lalala'
  <%= pod_to_html begin %>=head2 lalala<% end %>

Render POD to HTML without preprocessing.

=head1 METHODS

L<Mojolicious::Plugin::PODBook> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  my $route = $plugin->register(Mojolicious->new);
  my $route = $plugin->register(Mojolicious->new, {name => 'foo'});

Register renderer and helper in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut

__DATA__
@@ podbook.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= $title %></title>
    %= javascript '/mojo/prettify/run_prettify.js'
    %= stylesheet '/mojo/prettify/prettify-mojo-light.css'
    <style>
      a { color: inherit }
      a:hover { color: #2a2a2a }
      a img { border: 0 }
      body {
        background: url(<%= url_for '/mojo/pinstripe-light.png' %>);
        color: #445555;
        font: 0.9em 'Helvetica Neue', Helvetica, sans-serif;
        font-weight: normal;
        line-height: 1.5em;
        margin: 0;
      }
      :not(pre) > code {
        background-color: rgba(0, 0, 0, 0.04);
        border-radius: 3px;
        font: 0.9em Consolas, Menlo, Monaco, Courier, monospace;
        padding: 0.3em;
      }
      h1, h2, h3 {
        color: #2a2a2a;
        display: inline-block;
        font-size: 1.5em;
        margin: 0;
        position: relative;
      }
      h1 a, h2 a, h3 a { text-decoration: none }
      li > p {
        margin-bottom: 0;
        margin-top: 0;
      }
      pre {
        background: url(<%= url_for '/mojo/stripes.png' %>);
        border: 1px solid #d1d1d1;
        border-radius: 3px;
        box-shadow: 0 1px #fff, inset -1px 1px 4px rgba(0, 0, 0, 0.1);
        font: 100% Consolas, Menlo, Monaco, Courier, monospace;
        padding: 1em;
        padding-bottom: 1.5em;
        padding-top: 1.5em;
      }
      pre > code {
        color: #4d4d4c;
        font: 0.9em Consolas, Menlo, Monaco, Courier, monospace;
        line-height: 1.5em;
        text-align: left;
        text-shadow: #eee 0 1px 0;
        white-space: pre-wrap;
      }
      ul { list-style-type: square }
      #footer {
        padding-top: 1em;
        text-align: center;
      }
      #perldoc {
        background-color: #fff;
        border-bottom-left-radius: 5px;
        border-bottom-right-radius: 5px;
        box-shadow: 0px 0px 2px #999;
        margin-left: 5em;
        margin-right: 5em;
        padding: 3em;
        padding-top: 70px;
      }
      #perldoc > ul:first-of-type a { text-decoration: none }
      #source { padding-bottom: 1em }
      #wrapperlicious {
        max-width: 1000px;
        margin: 0 auto;
      }
      .permalink {
        display: none;
        left: -0.75em;
        position: absolute;
        padding-right: 0.25em;
      }
      h1:hover .permalink, h2:hover .permalink, h3:hover .permalink {
        display: block;
      }
    </style>
  </head>
  <body>
    %= include inline => app->renderer->_bundled('mojobar')
    <div id="wrapperlicious">
      <div id="perldoc">
        <div id="source">
          % my $path;
          % for my $part (split '/', $module) {
            %= '::' if $path
            % $path .= "/$part";
            %= link_to $part => url_for("/perldoc$path")
          % }
          (<%= link_to 'source' => url_for("/perldoc$path.txt") %>)
        </div>
        <h1><a id="toc">TABLE OF CONTENTS</a></h1>
        <ul>
          % for my $part (@$parts) {
            <li>
              %= link_to splice(@$part, 0, 2)
              % if (@$part) {
                <ul>
                  % while (@$part) {
                    <li><%= link_to splice(@$part, 0, 2) %></li>
                  % }
                </ul>
              % }
            </li>
          % }
        </ul>
        %= content_for 'perldoc'
      </div>
    </div>
    <div id="footer">
      %= link_to 'http://mojolicio.us' => begin
        %= image '/mojo/logo-black.png', alt => 'Mojolicious logo'
      % end
    </div>
  </body>
</html>
