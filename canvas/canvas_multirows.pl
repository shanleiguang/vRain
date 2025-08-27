#!/usr/bin/perl
#by shanleiguang, 2024.1.5
use strict;
use warnings;

use Image::Magick;
use Getopt::Std;
use Encode;
use utf8;

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my %opts;

getopts('hc:', \%opts);

if(not defined $opts{'c'} or not -f "$opts{'c'}.cfg") {
	print "error: no config, ./canvas -c 01_Black\n";
	exit;
}
my $cid = $opts{'c'};

my %canvas;
open CONFIG, "< $cid.cfg";
while(<CONFIG>) {
	chomp;
	next if(m/^\s{0,}$/);
	next if(m/^#/);
	s/#.*$// if(not m/=#/);
	s/\s//g;
	my ($k, $v) = split /=/, $_;
	$v = decode('utf-8', $v);
	$canvas{$k} = $v;
}
close(CONFIG);

my ($cw, $ch, $cc) = ($canvas{'canvas_width'}, $canvas{'canvas_height'}, $canvas{'canvas_color'});
my ($mt, $mb) = ($canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($ml, $mr) = ($canvas{'margins_left'}, $canvas{'margins_right'});
my ($cln, $lcw) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});

my ($ifmr, $mrn, $mcc) = ($canvas{'if_multirows'}, $canvas{'multirows_num'}, $canvas{'multirows_colcolor'});

my ($fty, $ftc) = ($canvas{'fish_top_y'}, $canvas{'fish_top_color'});
my ($ftrh, $ftth, $ftlw) = ($canvas{'fish_top_rectheight'}, $canvas{'fish_top_triaheight'}, $canvas{'fish_top_linewidth'});
my $fbd = $canvas{'fish_btm_direction'};
my ($fby, $fbc) = ($canvas{'fish_btm_y'}, $canvas{'fish_btm_color'});
my ($fbrh, $fbth, $fblw) = ($canvas{'fish_btm_rectheight'}, $canvas{'fish_btm_triaheight'}, $canvas{'fish_btm_linewidth'});
my ($flw, $flm, $flc) = ($canvas{'fish_line_width'}, $canvas{'fish_line_margin'}, $canvas{'fish_line_color'});

my ($ilw, $ilc) = ($canvas{'inline_width'}, $canvas{'inline_color'});
my ($olw, $olc) = ($canvas{'outline_width'}, $canvas{'outline_color'});
my ($moh, $mov) = ($canvas{'outline_hmargin'}, $canvas{'outline_vmargin'});
my ($lgt, $lgy, $lgc) = ($canvas{'logo_text'}, $canvas{'logo_y'}, $canvas{'logo_color'});
my ($lgf, $lgs) = ($canvas{'logo_font'}, $canvas{'logo_font_size'});
my $clw = ($cw-$ml-$mr-$lcw)/$cln;

$cc = 'white' if(not $cc);
print "create ImageMagick ...\n";
my $cimg = Image::Magick->new();

$cimg->Set(size => $cw.'x'.$ch);
$cimg->ReadImage("canvas:$cc");

$cimg->Draw(primitive => 'rectangle', points => get_points($ml-$olw/2-$moh, $mt-$olw/2-$mov, $cw-$mr+$olw/2+$moh, $ch-$mb+$olw/2+$mov),
	fill => 'transparent', stroke => $olc, strokewidth => $olw);
$cimg->Draw(primitive => 'rectangle', points => get_points($ml, $mt, $cw-$mr, $ch-$mb),
	fill => 'transparent', stroke => $ilc, strokewidth => $ilw);

if($ifmr and $mrn > 1) {
	my $mrh = ($ch-$mt-$mb)/$mrn;
	foreach my $rid (1..$mrn-1) {
		$cimg->Draw(primitive => 'line', points => get_points($ml, $mt+$rid*$mrh, $cw/2-$lcw/2, $mt+$rid*$mrh), fill => $ilc);
		$cimg->Draw(primitive => 'line', points => get_points($cw-$mr, $mt+$rid*$mrh, $cw/2+$lcw/2, $mt+$rid*$mrh), fill => $ilc);
	}
}

foreach my $cid (1..$cln) {
	my $tilc = ($ifmr and $mrn > 1) ? $mcc : $ilc;
	$tilc = $ilc if($cid == $cln/2 or $cid == $cln/2+1);
	my $wd = ($cid > $cln/2) ? ($lcw-$clw) : 0;
	$cimg->Draw(primitive => 'line', points => get_points($ml+$wd+$clw*$cid, $mt, $ml+$wd+$clw*$cid, $ch-$mb),
		fill => $tilc, stroke => $tilc, strokewidth => $ilw);
}

draw_fishtop($fty, $ftrh, $ftth);
if($fbd == 0) { draw_fishbtm_down($fby, $fbrh, $fbth); }
if($fbd == 1) { draw_fishbtm_up($fby, $fbrh, $fbth); }

if($ftlw) { $cimg->Draw(primitive => 'line', points => get_points($cw/2, $mt-$mov, $cw/2, $fty-$flm), stroke => $flc, strokewidth => $ftlw); }
if($fblw) { $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fby+$flm, $cw/2, $ch-$mb+$mov), stroke => $flc, strokewidth => $fblw); }
if($lgt) {
	my @lchars = split //, $lgt;
	foreach my $lcid (0..$#lchars) {
		print "\t$lchars[$lcid] -> $lgf\n";
		$cimg->Annotate(text => $lchars[$lcid], font => '@'.$lgf, pointsize => $lgs, x => $cw/2-$lgs/2, y => $lgy+$lgs*$lcid,
            fill => $lgc, stroke => $lgc, strokewidth => 1);
	}
}

print "write '$cid.jpg' ... ";
$cimg->Write("$cid.jpg");
print "done\n";

sub get_points {
	my ($fx, $fy, $tx, $ty) = @_;
	return "$fx,$fy $tx,$ty";
}

sub get_points_fish {
	my ($x1, $y1, $x2, $y2, $x3, $y3, $x4, $y4, $x5, $y5) = @_;
	return "M $x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 Z";
}

sub get_points_path {
	my ($fx, $fy, $px, $py, $tx, $ty) = @_;
	return "M $fx,$fy $px,$py $tx,$ty Z";
}

sub draw_fishtop {
    my ($fy, $dy1, $dy2) = @_;
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    $cimg->Draw(
    	primitive => 'path',
    	points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    	stroke => $flc, strokewidth => $flw, fill => $ftc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}

sub draw_fishbtm_down {
    my ($fy, $dy1, $dy2) = @_;
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) {
	    $cimg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}

sub draw_fishbtm_up {
    my ($fy, $dy1, $dy2) = @_;
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$flm, $cw/2+$lcw/2, $fy+$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) {
	    $cimg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy-$dy1-$dy2, $cw/2, $fy-$dy1, $cw/2-$lcw/2, $fy-$dy1-$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$dy1-$dy2-$flm, $cw/2, $fy-$dy1-$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy-$dy1-$flm, $cw/2+$lcw/2, $fy-$dy1-$dy2-$flm), fill => $flc);
}

