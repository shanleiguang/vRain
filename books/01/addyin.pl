#!/usr/bin/perl
#by shanleiguang, 2024.1.5
use strict;
use warnings;

use Image::Magick;
use PDF::Builder;
use Data::Dumper;
use Encode;
use utf8;

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my %zhnums;
open ZHNUM, '< ../../db/num2zh_jid.txt';
while(<ZHNUM>) {
	chomp;
	$_ = decode('utf-8', $_);
	my ($a, $b) = split /\|/, $_;
	$zhnums{$a} = $b;
}
close(ZHNUM);

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

opendir LWD, '.';
foreach my $pdfn (readdir(LWD)) {
	next if($pdfn !~ m/\.pdf$/);
	my @ypages = (
		'1|22.5|20|1|02_2,2_01_1.png',
		'1|22.5|17.5|1|02_4,3_01_0.png',
		#'1|2|1|2|redbook.png',
	);

	$pdfn = decode('utf-8', $pdfn);

	my ($jid, $jno);

	if($pdfn =~ m/至(\d+)/) {
		$jid = $1;
		$jid--;
		$jno = $zhnums{$jid};
		$jid = ($jid <= 9) ? '0'.$jid : $jid;
	}

	my $epdfn = "$jid、《$book{'title'}》卷$jno.pdf";
	my $fptmp = (split /\./, $pdfn)[0].'.tmp';
	my @fpages = ();

	open FPTMP, $fptmp;
	while(<FPTMP>) {
		chomp;
		print "$_\n";
		@fpages = split /\|/, $_;
	}
	close(FPTMP);
	print join ',',@fpages, "\n";

	foreach my $pid (@fpages) {
		push @ypages, "$pid|0.95|6|1|02_2,2_01_1.png";
		push @ypages, "$pid|0.95|4|1|02_1,2_01_0.png";
	}

	print "open pdf '$pdfn' ... \n";
	my $vpdf = PDF::Builder->open($pdfn);

	if($jid == 11) {
		my ($pid, $col_begin, $row_begin, $cols) = (12, 11, 22, 1);
		my $iw = $cols*$cw;
		my $ix = $bg_width-$bg_right-$cw*$col_begin;
		my $iy = $bg_bottom+$rh*($row_begin-1);

		my $yimg = Image::Magick->new();

		$yimg->ReadImage("yin/11.jpg");

		my ($yw, $yh) = ($yimg->Get('width'), $yimg->Get('height'));

		$yimg->AdaptiveResize(width => $iw*0.55, height => $yh*$iw/$yw*0.55, x => 0, y => 0, filter => 'Lanczos', blur => -1);
		$yimg->AutoThreshold();
		$yimg->Write("yin/tmp/11.jpg");

		my $page = $vpdf->open_page(13);
		my $grfx = $page->gfx();
		my $timg = $vpdf->image("yin/tmp/11.jpg");

		$grfx->object($timg, $ix+$iw*0.225, $iy);
	}

	foreach my $yin (@ypages) {
		my ($pid, $col_begin, $row_begin, $cols, $yinfn) = split /\|/, $yin;
		my $iw = $cols*$cw;
		my $ix = $bg_width-$bg_right-$cw*$col_begin;
		my $iy = $bg_bottom+$rh*($row_begin-1);

		$ix-= $lc_width if($col_begin > $col_num/2);

		`mkdir yin/tmp` if(not -d 'yin/tmp');

		my $yimg = Image::Magick->new();

		$yimg->ReadImage("yin/$yinfn");

		my ($yw, $yh) = ($yimg->Get('width'), $yimg->Get('height'));

		$yimg->AdaptiveResize(width => $iw, height => $yh*$iw/$yw, x => 0, y => 0, filter => 'Lanczos', blur => -1);
		$yimg->Write("yin/tmp/$yinfn");

		my $page = $vpdf->open_page($pid);
		my $grfx = $page->gfx();
		my $timg = $vpdf->image("yin/tmp/$yinfn");

		$grfx->object($timg, $ix, $iy);
	}
	$vpdf->save("export/$epdfn");
}
closedir(LWD);

