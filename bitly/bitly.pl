package MT::Plugin::bitly;

## ORIGINAL CODE
# AUTHOR  : あきみち
# SITE    : 「Geekなぺーじ [インターネット技術メモ]」 http://www.geekpage.jp/
# PAGE    : 「Geekなぺーじ : bit.lyのURL短縮機能を利用する」 http://www.geekpage.jp/programming/perl-network/bitly-shorten.php
##
# このプラグインは、上記のPerlコードを元に、MTプラグイン化したものです。
#

use strict;
use MT;
use MT::Plugin;

# Additional Module

use HTTP::Lite;
use XML::DOM;

use vars qw($PLUGIN_NAME $VERSION);
$PLUGIN_NAME = 'bitly';
$VERSION = '1.0';

use base qw( MT::Plugin );

@MT::Plugin::bitly::ISA = qw( MT::Plugin );

my $plugin = MT::Plugin::bitly->new({
    id => 'bitly',
    key => __PACKAGE__,
    name => $PLUGIN_NAME,
    version => $VERSION,
    description => "<MT_TRANS phrase='Make ShortenURL and Expand ShortenURL by bit.ly api'>",
    doc_link => 'http://code.zelazny.mydns.jp/mt-plugin-bitly',
    author_name => 'naoaki.onozaki',
    author_link => 'http://www.zelazny.mydns.jp/',
    l10n_class => 'bitly::L10N',
    blog_config_template => \&blog_config_template,
    settings => new MT::PluginSettings([
        ['bitly_login', { Default => '' }],
        ['bitly_apikey', { Default => '' }],
        ['bitly_ver', { Default => '2.0.1' }],
        ['bitly_history', { Default => '0' }],
    ]),
    registry => {
        tags => {
            modifier => {
                'bitly' => \&bitly_shorten,
                'bitly_shorten' => \&bitly_shorten,
                'bitly_expand' => \&bitly_expand,
            },
            function => {
                BitlyTest => \&bitly_test,
            },
        },
    },
});

MT->add_plugin($plugin);

sub instance { $plugin; }

sub blog_config_template {
    my $tmpl = <<'EOT';
    <mtapp:setting
        id="bitly_login"
        label="<__trans phrase="bit.ly login:">"
        hint="<__trans phrase="Hint">">
        <input type="text" name="bitly_login" id="bitly_login" value="<mt:var name="bitly_login" escape="html">" />
    </mtapp:setting>
    <mtapp:setting
        id="bitly_apikey"
        label="<__trans phrase="bit.ly apikey:">"
        hint="<__trans phrase="Hint">">
        <input type="text" name="bitly_apikey" id="bitly_apikey" value="<mt:var name="bitly_apikey" escape="html">" />
    </mtapp:setting>
    <mtapp:setting
        id="bitly_ver"
        label="<__trans phrase="bit.ly ver:">"
        hint="<__trans phrase="Hint">">
        <input type="text" name="bitly_ver" id="bitly_ver" value="<mt:var name="bitly_ver" escape="html">" readonly="readonly" />
    </mtapp:setting>
    <mtapp:setting
        id="bitly_ver"
        label="<__trans phrase="Enable History:">"
        hint="<__trans phrase="Hint">">
        <input type="checkbox" name="bitly_history" id="bitly_history" value="1"<mt:if name="bitly_history"> checked="checked"</mt:if> />
    </mtapp:setting>
EOT
}

#----- Global filter
sub bitly_shorten {
    my ($text, $arg, $ctx) = @_;
      $arg or return $text;

    my $blog_id = $ctx->stash('blog_id');
    my $login = $plugin->get_setting('bitly_login', $blog_id);     # bit.lyで取得したID
      $login or return $text;
    my $apikey = $plugin->get_setting('bitly_apikey', $blog_id);   # bit.lyで取得したAPI Key
      $apikey or return $text;
    my $ver = $plugin->get_setting('bitly_ver', $blog_id);         # 2009年8月6日現在はバージョン2.0.1
    my $url = $text; # 短縮したいURL
    my $history = $plugin->get_setting('bitly_history', $blog_id);

    my $http = new HTTP::Lite;

    my $resturl = "http://api.bit.ly/shorten?version=$ver&longUrl=$url&login=$login&apiKey=$apikey&format=xml";
    if ($history) {
      $resturl .= "&history=1";
    }
    my $result = $http->request($resturl) || die $!;
    my $xmlstr = $http->body();

    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse($xmlstr);
    my $nodes = $doc->getElementsByTagName('shortUrl');
    $text = $nodes->item(0)->getFirstChild->getNodeValue;

    $text;
}

sub bitly_expand {
    my ($text, $arg, $ctx) = @_;
      $arg or return $text;

    my $blog_id = $ctx->stash('blog_id');
    my $login = $plugin->get_setting('bitly_login', $blog_id);     # bit.lyで取得したID
      $login or return $text;
    my $apikey = $plugin->get_setting('bitly_apikey', $blog_id);   # bit.lyで取得したAPI Key
      $apikey or return $text;
    my $ver = $plugin->get_setting('bitly_ver', $blog_id);         # 2009年8月6日現在はバージョン2.0.1
    my $url = $text; # 短縮したいURL
    my $history = $plugin->get_setting('bitly_history', $blog_id);

    my $http = new HTTP::Lite;

    my $resturl = "http://api.bit.ly/expand?version=$ver&shortUrl=$url&login=$login&apiKey=$apikey&format=xml";
    if ($history) {
      $resturl .= "&history=1";
    }
    $resturl .= "&history=1" if $history;
    my $result = $http->request($resturl) || die $!;
    my $xmlstr = $http->body();

    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse($xmlstr);
    my $nodes = $doc->getElementsByTagName('longUrl');
    $text = $nodes->item(0)->getFirstChild->getNodeValue;

    $text;
}

#----- Load Settings
sub get_setting {
    my $plugin = shift;
    my ($value, $blog_id) = @_;
    my %plugin_param;

    $plugin->load_config(\%plugin_param, 'blog:'.$blog_id);
    $value = $plugin_param{$value};
    unless ($value) {
        $plugin->load_config(\%plugin_param, 'system');
        $value = $plugin_param{$value};
    }
    $value;
}

sub bitly_test {
    my ( $ctx, $args, $cond ) = @_;
    my $blog_id = $ctx->stash('blog_id');
    my $history = $plugin->get_setting('bitly_history', $blog_id);
    if ($history) {
      return 'yes';
    } else {
      return 'no';
    }
}

1;