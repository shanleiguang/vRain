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
$cc = 'rgb(210,200,190)'; #白宣底色
$ilc = $olc = $ftc = $fbc = $flc = 'rgb(66,66,66)'; #墨线做旧色
print "create ImageMagick ...\n";
my $cimg = Image::Magick->new();

$cimg->Set(size => $cw.'x'.$ch);
$cimg->ReadImage("canvas:$cc");

#添加纸张纹理
$cimg->AddNoise(noise => 'gaussian', attenuate => 0.6); # 高斯噪声
$cimg->Blur(radius => 3, sigma=> 1.5); # 模糊创建纤维质感
$cimg->BrightnessContrast(brightness => 8, contrast => 5); # 微调对比度

#创建墨线图层
my $ink = Image::Magick->new;
$ink->Set(size => $cw.'x'.$ch);
$ink->Read('xc:none'); # 透明背景

#内外线框
$ink->Draw(primitive => 'rectangle', points => get_points($ml-$olw/2-$moh, $mt-$olw/2-$mov, $cw-$mr+$olw/2+$moh, $ch-$mb+$olw/2+$mov),
	fill => 'transparent', stroke => $olc, strokewidth => $olw);
$ink->Draw(primitive => 'rectangle', points => get_points($ml, $mt, $cw-$mr, $ch-$mb),
	fill => 'transparent', stroke => $ilc, strokewidth => $ilw);
#行分割线
foreach my $cid (1..$cln) {
	my $wd = ($cid > $cln/2) ? ($lcw-$clw) : 0;
	$ink->Draw(primitive => 'line', points => get_points($ml+$wd+$clw*$cid, $mt, $ml+$wd+$clw*$cid, $ch-$mb),
		stroke => $ilc, strokewidth => $ilw);
}
#上鱼尾
draw_fishtop($fty, $ftrh, $ftth);
#下鱼尾，0：顺鱼尾，1：对鱼尾
if($fbd == 0) { draw_fishbtm_down($fby, $fbrh, $fbth); }
if($fbd == 1) { draw_fishbtm_up($fby, $fbrh, $fbth); }
#上下鱼尾线
if($ftlw) { $ink->Draw(primitive => 'line', points => get_points($cw/2, $mt-$mov, $cw/2, $fty-$flm), stroke => $flc, strokewidth => $ftlw); }
if($fblw) { $ink->Draw(primitive => 'line', points => get_points($cw/2, $fby+$flm, $cw/2, $ch-$mb+$mov), stroke => $flc, strokewidth => $fblw); }
#墨线图层柔化
$ink->Blur(radius => 1, sigma => 0.5);

#创建斑点图层
my $pnum = 2000;
foreach my $i (1..$pnum) {
    #随机位置和大小
    my ($px, $py) = (int(rand($cw)), int(rand($ch)));
    my $size = 10+int(rand(20));    
    #绘制椭圆并模糊
    my $point = Image::Magick->new();
    $point->Set(size => $size.'x'.$size);
    $point->ReadImage('xc:none');
    if(check_range($px, $py, $size)) {
    	$point->Draw(primitive => 'ellipse', 
        	points => get_points_ellipse($size/2, $size/2, $size*0.3, $size*0.2),
        	fill => 'white', 
    	);
    	$point->Rotate(degrees => rand(45)-22.5);
    	$point->OilPaint(radius => 1.5);
    }
    $point->Blur(radius => $size, sigma => 1);
    $ink->Composite(image => $point, x => $px-$size*0.4, y => $py, compose => 'Overlay');
}
$ink->OilPaint(radius => 0.8);

#书房名
if($lgt) {
	my @lchars = split //, $lgt;
	foreach my $lcid (0..$#lchars) {
		print "\t$lchars[$lcid] -> $lgf\n";
		$ink->Annotate(text => $lchars[$lcid], font => '@'.$lgf, pointsize => $lgs, x => $cw/2-$lgs/2, y => $lgy+$lgs*$lcid,
            fill => $lgc, stroke => $lgc, strokewidth => 1);
	}
}

$cimg->Composite(image => $ink, compose => 'Multiply');
print "write '$cid.jpg' ... ";
$cimg->Write("$cid.jpg");
print "done\n";

sub check_range {
	my ($px, $py, $ps) = @_;
	return 1 if(abs($px-$cw/2) >= $lcw);
	return 1 if($py < $fty-$ps);
	return 1 if($py > $fby+$ps);
	return 0;
}

sub get_points {
	my ($fx, $fy, $tx, $ty) = @_;
	return "$fx,$fy $tx,$ty";
}

sub get_points_ellipse {
	my ($fx, $fy, $tx, $ty) = @_;
	return "$fx,$fy $tx,$ty 0,360";
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
    $ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    $ink->Draw(
    	primitive => 'path',
    	points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    	stroke => $flc, strokewidth => $flw, fill => $ftc);
    $ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $ink->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}

sub draw_fishbtm_down {
    my ($fy, $dy1, $dy2) = @_;
    $ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) {
	    $ink->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    $ink->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
}

sub draw_fishbtm_up {
    my ($fy, $dy1, $dy2) = @_;
    $ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$flm, $cw/2+$lcw/2, $fy+$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) {
	    $ink->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy-$dy1-$dy2, $cw/2, $fy-$dy1, $cw/2-$lcw/2, $fy-$dy1-$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	$ink->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$dy1-$dy2-$flm, $cw/2, $fy-$dy1-$flm), fill => $flc);
    $ink->Draw(primitive => 'line', points => get_points($cw/2, $fy-$dy1-$flm, $cw/2+$lcw/2, $fy-$dy1-$dy2-$flm), fill => $flc);
}

