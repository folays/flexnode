#!/usr/bin/perl -w

use strict;

use LWP::UserAgent;
use Data::Dumper;
use Encode;
use Encode::Detect::Detector; # libencode-detect-perl
use HTML::TreeBuilder;

die "usage: $0 file.html text\n" unless scalar @ARGV == 2;

open FILE, "<", $ARGV[0] or die "could not open file";
my $content = eval { local $/ = undef; <FILE> };
close FILE;
$content = decode(detect($content), $content);

my $root = HTML::TreeBuilder->new;
$root->ignore_unknown(0);
$root->parse($content);
$root->eof();
$root->elementify();

my @stack = {h => $root, index => 0};

zou($root, 0);

sub zou
{
    my ($h) = @_;

    my %indexes; # group by tag name
    foreach my $node ($h->content_list())
    {
	push @stack, {h => $node, index => (ref $node ? $indexes{$node->tag}++ : $indexes{""}++)};
	my @attr = map {"$_=".$node->attr($_)} (ref $node ? $node->all_external_attr_names : ());
	if (!ref $node && $node =~ m/$ARGV[1]/o || grep {/$ARGV[1]/o} @attr)
	{
	    print encode("iso-8859-2", $node)."\n" unless ref $node;
	    print "ADDRESS ".$node->address."\n" if ref $node;
	    print "PATH ".&get_lineage_path(ref $node ? $node : $stack[$#stack - 1]->{h})."\n";
	    foreach my $e (@stack)
	    {
		my $p = $e->{h};
		do { print "-"x$#stack."> _TEXT[".$e->{index}."]\n"; last } unless ref $p;
		my $attr = join(', ', map {"$_=".$p->attr($_)} $p->all_external_attr_names);
		print "-"x$p->depth."> ".$p->tag."[".($p->pindex || 0)."][".$e->{index}."] ".$attr."\n";
	    }
	}

	zou($node) if ref $node;
	pop @stack;
    }
}

sub get_lineage_path
{
    my $node = shift;

    join (',', map {$_->tag.":".($_->attr('id') || "")."|".($_->attr('class') || "")} $node, $node->lineage);
}
