#!/usr/bin/perl
#canvas是vRain兀雨古籍刻本电子书制作工具的背景制作脚本
#by shanleiguang@gmail.com, 2024/1, 2025/8
use strict;
use warnings;

use Image::Magick;
use Getopt::Std;
use Encode;
use utf8;

$| = 1; #autoflush

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

my ($ifmr, $mrn, $mcc) = ($canvas{'if_multirows'}, $canvas{'multirows_num'}, $canvas{'multirows_colcolor'});

my $bg = $canvas{'canvas_background_image'}; #背景图
my ($cw, $ch, $cc) = ($canvas{'canvas_width'}, $canvas{'canvas_height'}, $canvas{'canvas_color'});
my ($mt, $mb) = ($canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($ml, $mr) = ($canvas{'margins_left'}, $canvas{'margins_right'});
my ($cln, $lcw) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});

my ($fty, $ftc) = ($canvas{'fish_top_y'}, $canvas{'fish_top_color'});
my ($ftrh, $ftth, $ftlw) = ($canvas{'fish_top_rectheight'}, $canvas{'fish_top_triaheight'}, $canvas{'fish_top_linewidth'});
my $fbd = $canvas{'fish_btm_direction'};
my ($fby, $fbc) = ($canvas{'fish_btm_y'}, $canvas{'fish_btm_color'});
my ($fbrh, $fbth, $fblw) = ($canvas{'fish_btm_rectheight'}, $canvas{'fish_btm_triaheight'}, $canvas{'fish_btm_linewidth'});
my ($flw, $flm, $flc) = ($canvas{'fish_line_width'}, $canvas{'fish_line_margin'}, $canvas{'fish_line_color'});

my ($ilw, $ilc) = ($canvas{'inline_width'}, $canvas{'inline_color'});
my ($olw, $olc) = ($canvas{'outline_width'}, $canvas{'outline_color'});
my ($moh, $mov) = ($canvas{'outline_hmargin'}, $canvas{'outline_vmargin'});
my ($lgi, $lgt, $lgy, $lgc) = ($canvas{'logo_image'}, $canvas{'logo_text'}, $canvas{'logo_y'}, $canvas{'logo_color'});
my ($lgf, $lgs) = ($canvas{'logo_font'}, $canvas{'logo_font_size'});
my $clw = ($cw-$ml-$mr-$lcw)/$cln; #计算列宽

$cc = 'white' if(not $cc); #背景色未定义时采用白色
print "create ImageMagick ...\n";
my $cimg = Image::Magick->new();

$cimg->Set(size => $cw.'x'.$ch);

if(defined $bg and -f $bg) {
	$cimg->ReadImage($bg); #使用背景图
	my ($bw, $bh) = ($cimg->Get('width'), $cimg->Get('height'));
    if($bw != $cw or $bh != $ch) {
        $cimg->AdaptiveResize(width => $cw, height => $ch, x => 0, y => 0, method => 'Hermit');
    }
} else {
	$cimg->ReadImage("canvas:$cc");
}

my $delta = 5; #标准间距
#粗外框
$cimg->Draw(primitive => 'rectangle', points => get_points($ml-$olw/2-$moh-$delta, $mt-$olw/2-$mov-$delta, $cw-$mr+$olw/2+$moh+$delta, $ch-$mb+$olw/2+$mov+$delta),
	fill => 'transparent', stroke => $olc, strokewidth => $olw);
#细内框
$cimg->Draw(primitive => 'rectangle', points => get_points($ml-$delta, $mt-$delta, $cw-$mr+$delta, $ch-$mb+$delta),
	fill => 'transparent', stroke => $ilc, strokewidth => $ilw);

#多栏模式时打印分栏横线
if($ifmr and $mrn > 1) {
	my $mrh = ($ch-$mt-$mb)/$mrn;
	foreach my $rid (1..$mrn-1) {
		$cimg->Draw(primitive => 'line', points => get_points($ml, $mt+$rid*$mrh, $cw/2-$lcw/2, $mt+$rid*$mrh), fill => $ilc);
		$cimg->Draw(primitive => 'line', points => get_points($cw-$mr, $mt+$rid*$mrh, $cw/2+$lcw/2, $mt+$rid*$mrh), fill => $ilc);
	}
}
#列细线
foreach my $cid (1..$cln) {
	my $tilc = ($ifmr and $mrn > 1) ? $mcc : $ilc; #多栏模式时，更新列细线颜色
	$tilc = $ilc if($cid == $cln/2 or $cid == $cln/2+1); #版心两侧列细线
	my $wd = ($cid > $cln/2) ? ($lcw-$clw) : 0; #对于越过版心列的横坐标调整
	$cimg->Draw(primitive => 'line', points => get_points($ml+$wd+$clw*$cid, $mt, $ml+$wd+$clw*$cid, $ch-$mb),
		fill => $tilc, stroke => $tilc, strokewidth => $ilw);
}

#上鱼尾
draw_fishtop($fty, $ftrh, $ftth);
#下鱼尾
if($fbd == 0) { draw_fishbtm_down($fby, $fbrh, $fbth); } #顺鱼尾
if($fbd == 1) { draw_fishbtm_up($fby, $fbrh, $fbth); } #对鱼尾
#版心鱼尾到上下边框的粗线
if($ftlw) { $cimg->Draw(primitive => 'line', points => get_points($cw/2, $mt-$mov-$delta, $cw/2, $fty-$flm), stroke => $flc, strokewidth => $ftlw); }
if($fblw) { $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fby+$flm, $cw/2, $ch-$mb+$mov+$delta), stroke => $flc, strokewidth => $fblw); }
#版心底部的logo
if(-f $lgi) { #图
	my $logo = Image::Magick->new();
	my ($lw, $lh);

	$logo->ReadImage($lgi);
	($lw, $lh) = ($logo->Get('Width'), $logo->Get('Height'));
	$logo->AdaptiveResize(width => $lw/3, height => $lh/3, method => 'Hermit');
	$cimg->Composite(image => $logo, x => $cw/2+$lcw/4-$lw/3/2, y => $ch-$mb-$lh/3, compose => 'Over');
} elsif($lgt) { #文字
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
	return "M $x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 Z"; #Draw path的路径参数格式，多点任意
}

sub get_points_path {
	my ($fx, $fy, $px, $py, $tx, $ty) = @_;
	return "M $fx,$fy $px,$py $tx,$ty Z"; #Draw path的路径参数格式，三角形
}

#上鱼尾
sub draw_fishtop {
    my ($fy, $dy1, $dy2) = @_;
    #鱼尾上细线
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm), stroke => $flc, strokewidth => $flw);
    #鱼尾
    $cimg->Draw(
    	primitive => 'path',
    	points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    	stroke => $flc, strokewidth => $flw, fill => $ftc);
    #鱼尾两细斜线
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}
#下鱼尾，顺鱼尾
sub draw_fishbtm_down {
    my ($fy, $dy1, $dy2) = @_;
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) { #设置为0时，下鱼尾萎缩为双横线
	    $cimg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}
#下鱼尾，对鱼尾
sub draw_fishbtm_up {
    my ($fy, $dy1, $dy2) = @_;
    $cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$flm, $cw/2+$lcw/2, $fy+$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) { #设置为0时，下鱼尾萎缩为双横线
	    $cimg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy-$dy1-$dy2, $cw/2, $fy-$dy1, $cw/2-$lcw/2, $fy-$dy1-$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$cimg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$dy1-$dy2-$flm, $cw/2, $fy-$dy1-$flm), fill => $flc);
    $cimg->Draw(primitive => 'line', points => get_points($cw/2, $fy-$dy1-$flm, $cw/2+$lcw/2, $fy-$dy1-$dy2-$flm), fill => $flc);
}

