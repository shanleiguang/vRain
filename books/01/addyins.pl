#!/usr/bin/perl
#读取yins.cfg配置文件，将印章图片插入到PDF文件相应页码的相应位置
#by shanleiguang, 2025.7
use strict;
use warnings;

use PDF::Builder;
use Data::Dumper;
use Encode;
use utf8;

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my %book;
open BCONFIG, "< book.cfg";
print "read 'book.cfg'...\n";
while(<BCONFIG>) {
	chomp;
	next if(m/^\s{0,}$/);
	next if(m/^#/);
	s/\s//g;
	s/#.*$// if(not m/=#/);
	my ($k, $v) = split /=/, $_;
	$v = decode('utf-8', $v);
	$book{$k} = $v;
}
close(BCONFIG);

my ($canvas_id, $row_num) = ($book{'canvas_id'}, $book{'row_num'});

my %canvas;
open CCONFIG, "< ../../canvas/$canvas_id.cfg";
print "read '../../canvas/$canvas_id.cfg'...\n";
while(<CCONFIG>) {
	chomp;
	next if(m/^\s{0,}$/);
	next if(m/^#/);
	s/\s//g;
	s/#.*$// if(not m/=#/);
	my ($k, $v) = split /=/, $_;
	$v = decode('utf-8', $v);
	$canvas{$k} = $v;
}
close(CCONFIG);

my ($bg_width, $bg_height) = ($canvas{'canvas_width'}, $canvas{'canvas_height'});
my ($bg_top, $bg_bottom) = ($canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($bg_left, $bg_right) = ($canvas{'margins_left'}, $canvas{'margins_right'});
my ($col_num, $lc_width) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});
my ($il_width, $ol_width, $ot_vmargin) = ($canvas{'inline_width'}, $canvas{'outline_width'}, $canvas{'outline_vmargin'});
my $cw = ($bg_width - $bg_left - $bg_right - $lc_width)/$col_num;
my $rh = ($bg_height - $bg_top - $bg_bottom)/$row_num;

my %yins;
open YINCFG, "< yins.cfg";
print "read 'yins.cfg'...\n";
while(<YINCFG>) {
	chomp;
	next if(m/^\s{0,}$/);
	next if(m/^#/);
	s/\s//g;
	$_ = decode('utf-8', $_);
	my ($pdfn, $pos, $yinfn) = split /\|/, $_;
	my ($pid, $col_begin, $row_begin, $cols) = split /\,/, $pos;
	push @{$yins{$pdfn}}, [$pid, $col_begin, $row_begin, $cols, $yinfn];
}
close(YINCFG);

foreach my $pdfn (keys %yins) {
	print "open pdf '$pdfn' ... \n";
	my @pyins = @{$yins{$pdfn}};
	my $vpdf = PDF::Builder->open("$pdfn.pdf");

	foreach my $yin (@pyins) {
		my ($pid, $col_begin, $row_begin, $cols, $yinfn) = @{$yin};
		my $iw = $cols*$cw;
		my $ix = $bg_width-$bg_right-$cw*$col_begin;
		my $iy = $bg_bottom+$rh*($row_begin-1);

		$ix-= $lc_width if($col_begin > $col_num/2);

		my $page = $vpdf->open_page($pid);
		my $grfx = $page->gfx();
		my $yimg = $vpdf->image("yins/$yinfn");

		$grfx->object($yimg, $ix, $iy, $iw);
	}
	my $ypdfn = $pdfn.'_印章';

	$vpdf->save("$ypdfn.pdf");
}

