package FlexNode;

use strict;
use warnings FATAL => qw(uninitialized);

use Data::Dumper;
use HTML::TreeBuilder;

sub new($$)
{
    my (undef, $content, %options) = @_;
    $options{unused} ||= "unused";

    my $self = {};
    bless $self;

    $self->{root} = $self->get_root_node($content);

    return $self;
}

sub get_root_node($$)
{
    my ($self, $content) = @_;

    #$content = decode(detect($content), $content);

    my $root = HTML::TreeBuilder->new;
    # http://www.ahinea.com/en/tech/perl-unicode-struggle.html
    # http://search.cpan.org/~gaas/HTML-Parser-3.65/Parser.pm
    # http://perldoc.perl.org/Encode.html
    # http://perldoc.perl.org/perlunifaq.html
    # my $root = HTML::TreeBuilder->new; $root->utf8_mode(1);
    # ===> tells the parser that input is raw undecoded UTF-8.
    # this should causes the strings containing entities to be expanded as
    # undecoded UTF-8 ("\xE2\x99\xA5") instead of decoded UTF-8 ("\x{2665}" Perl's internal form),
    # so that they end up compatible with the surrounding text.
    # utf_mode on : "\xWHAT\xEVER&hearts;" -> "\xWHAT\xEVER\xE2\x99\xA5" <- this is what you want.
    # utf_mode off: "\xWHAT\xEVER&hearts;" -> "\xWHAT\xEVER\x{2665}" <- bad: raw undecoded UTF-8 + wide characters.
    # other hints:
    # decode("utf8", "\xWHAT\xEVER") -> convert from raw undecoded UTF-8 to Perl's internal form ("\x{NUMBER_ABOVE_255}")
    # `-> utf8_flag will be always on, unless input contains only ASCII data.
    #  -> can fail, not all sequences of octets form valid UTF-8 encodings.
    # encode("utf8", "\x{NUMBER_ABOVE_255}") -> convert from Perl's internal form to raw undecoded UTF-8
    # `-> utf8_flag will be always off
    #  -> cannot fail, all possible characters have a UTF-8 representation.
    #  -> UTF-8 is strict mode ("\x{FFFF_FFFF}" is invalid), while utf8 is Perl's UTF-8 relaxed mode.
    # ==> undecoded UTF-8 (or iso- or whatever) Perl's string means that the Perl's string representation consists
    #     only of non-wide characters <= 255
    # ==> decoded UTF-8 (or whatever) Perl's string means that the Perl's string representation possibly contains
    #     wide characters > 255 ("\x{256 and above}")
    $root->utf8_mode(1);
    if ($content =~ m/VISUELS/ || 1)
    {
	$root->parse($content);
    }
    else
    {
	print "GET FILE FROM CACHEEEEEEEEEEE\n";
	my $cachefile = "detail_313828_52560471.html";
#	open FILE, "<:utf8:", $cachefile or die;
	open FILE, "<", $cachefile or die;
	$root->parse_file(\*FILE) or die $!;
	close FILE;
    }
    $root->eof();
    $root->elementify();

    return FlexNode::Node->new($self, $root);
}

sub get_root($)
{
    my ($self) = @_;

    return $self->{root};
}

sub get_node($)
{
    my ($self, $lineage) = @_;

    return $self->{root}->get_node($lineage);
}

package FlexNode::Node;

use Data::Dumper;

sub new($$)
{
    my (undef, $root, $node) = @_;

    my $self = {};
    bless $self;

    $self->{root} = $root;
    $self->{node} = $node;

    return $self;
}

sub get_node($$)
{
    my ($self, $lineage) = @_;

    my $node = $self->{node}->look_down(sub {&_get_lineage_path($_[0]) eq $lineage});
    return FlexNode::Node->new($self->{root}, $node) if $node;
}

sub get_node2($$)
{
    my ($self, $lineage, $debug) = @_;

    ### a coder :
    # - une fonction qui split le linexp,
    # - qui descend dans l'arbre,
    # `- s'arrete des le premier element qui matche pas, plutot que de build une chaine a comparer pour tous
    # - qui pour chaque element compare le tagname, l'id la classe, et optionnelement la position []
    # IL faut donc iterer soit meme sur chaque descendants... p-t voir le code de look_down()...
# ("tr:|row2 [2],tbody:|,table:|datas compteInventaire,div:|cadre,div:blocCentral|,div:center|,div:container|,body:|,html:|")
    my @lineage;
    foreach my $elem ($lineage =~ m/\G([^,]+)(?:,|$)/og)
    {
	my ($tag, $id, $class, $pindex) = $elem =~ m/^(\S+):(\S*)\|([\w ]*)(?:\[(.*)\])?$/o or die;
	push @lineage, {tag => $tag, id => $id, class => $class, pindex => $pindex};
    }
#    print Dumper \@lineage;

#    my @pile = $self->{node};
    my @pile = $self->{node}->content_list();
    while (my $elem = pop @lineage)
    {
	@pile = grep {(
	    ref $_ &&
	    ($debug ? printf "cmp %s - %s\n", $elem->{tag}, $_->tag : 1) &&
	    ($debug ? printf "id '%s' - '%s'\n", ($elem->{id} || ""), ($_->attr('id') || "") : 1) &&
	    $elem->{tag} eq $_->tag &&
	    ($elem->{id} ? $elem->{id} eq ($_->attr('id') || "") : 1) &&
	    ($elem->{class} ? $elem->{class} eq ($_->attr('class') || "") : 1) &&
#	    (defined $elem->{pindex} ? $elem->{pindex} == $_->pindex() : 1) &&
	    1)} @pile;
#	printf "scalar pile : %d\n", scalar @pile;
	@pile = $pile[$elem->{pindex}] if defined $elem->{pindex};
	@pile = map {
#	    printf "-> %s\n", $_; 
	    ($_->content_list())
	} @pile if scalar @lineage;
	# content_list seems to return (undef) ... ?!
	@pile = grep { defined($_) } @pile;
    }
    return unless scalar @pile;
#    printf "selected %s\n", $pile[0] || "undef";
    return FlexNode::Node->new($self->{root}, $pile[0]) unless wantarray;
    return map { FlexNode::Node->new($self->{root}, $_) } @pile;
}

sub _get_lineage_path($)
{
    my ($node) = @_;

    join (',', map {$_->tag.":".($_->attr('id') || "")."|".($_->attr('class') || "")} $node, $node->lineage);
}

sub is_lineage_path($$)
{
    my ($node, $_) = @_;

}

sub as_trimmed_text($)
{
    my ($self) = @_;

    return $self->{node}->as_trimmed_text();
}

sub as_xml($)
{
    my ($self) = @_;

    return $self->{node}->as_XML();
}

sub content_list($)
{
    my ($self) = @_;

    return [$self->{node}->content_list()];
}

sub tag($)
{
    my ($self) = @_;
    return $self->{node}->tag();
}

sub attr($$)
{
    my ($self, $attr) = @_;
    return $self->{node}->attr($attr);
}

1;
