#!/usr/bin/perl
#canvas是vRain兀雨古籍刻本电子书制作工具的背景制作脚本
#by shanleiguang@gmail.com, 2024/1, 2025/8
use strict;
use warnings;

use Image::Magick;
use Math::Trig;
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
	s/\s+#.*$//;
	s/\s//g;
	my ($k, $v) = split /=/, $_;
	$v = decode('utf-8', $v);
	$canvas{$k} = $v;
}
close(CONFIG);

my ($ifmr, $mrn, $mrlw, $mrcc) = ($canvas{'if_multirows'}, $canvas{'multirows_num'}, $canvas{'multirows_linewidth'}, $canvas{'multirows_colcolor'}); #多栏参数
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
my ($iff, $ffi) = ($canvas{'if_fishflower'}, $canvas{'fish_flower_image'}); #花鱼尾，花鱼尾装饰图

my ($ilw, $ilc) = ($canvas{'inline_width'}, $canvas{'inline_color'});
my ($olw, $olc) = ($canvas{'outline_width'}, $canvas{'outline_color'});
my ($moh, $mov) = ($canvas{'outline_hmargin'}, $canvas{'outline_vmargin'});
my ($lgi, $lgt, $lgy, $lgc) = ($canvas{'logo_image'}, $canvas{'logo_text'}, $canvas{'logo_y'}, $canvas{'logo_color'});
my ($lgf, $lgs) = ('../fonts/'.$canvas{'logo_font'}, $canvas{'logo_font_size'});

my $clw = ($cw-$ml-$mr-$lcw)/$cln; #计算列宽

$cc = 'white' if(not $cc); #背景色未定义时采用白色

print '-'x60, "\n";
print "创建 '$cid' 背景图 ... \n";
print '-'x60, "\n";
print "\t背景尺寸：$cw x $ch\n";
print "\t背景颜色：$cc\t背景图片：", ($bg) ? $bg : '无', "\n";
print "\t整叶列数：$cln\t版心宽度：$lcw\n";
print "\t四边边距：上$mt 下$mb 左$ml 右$mr\n";
print "\t外框线宽：$olw\t外框颜色：$olc\n";
print "\t内框线宽：$ilw\t内框颜色：$ilc\n";
print "\t内外框距：横$moh 纵$mov\n";
print "\t多栏模式：", ($ifmr) ? $mrn.'栏' : '否', "\t分栏线宽：", ($mrlw) ? $mrlw : '', "\t栏列线色：", ($mrcc) ? $mrcc : '', "\n";
print "\t是否花尾：", ($iff) ? '是' : '否', "\t鱼尾装饰：", ($ffi) ? $ffi : '无', " *鱼尾装饰图应为正方形且内容居中\n";
print "\t鱼尾对顺：", ($fbd == 0) ? '顺鱼尾' : '对鱼尾', "\n";
print "\t鱼尾高度：上$fty 下$fby *以左上角为原点\n";
print "\t上尾身长：$ftrh\t上尾尾长：$ftth\n";
print "\t下尾身长：$fbrh\t下尾尾长：$fbth\n";
print "\t个性印章：", ($lgi) ? $lgi : '无', "\t个性签名：", ($lgt) ? $lgt : '无', "\n";
print '-'x60, "\n";

my $cimg = Image::Magick->new(); #画布图层

if(defined $bg and -f $bg) { #使用背景图
	$cimg->ReadImage($bg);
	my ($bw, $bh) = ($cimg->Get('width'), $cimg->Get('height'));
    $cimg->AdaptiveResize(width => $cw, height => $ch, x => 0, y => 0, method => 'Lanczos') if($bw > $cw or $bh > $ch); #缩
    $cimg->AdaptiveResize(width => $cw, height => $ch, x => 0, y => 0, method => 'Hermit', blur => 0.9) if($bw < $cw or $bh < $ch); #放
} else {
	$cimg->Set(size => $cw.'x'.$ch);
	$cimg->ReadImage("canvas:$cc");
}

my $limg = Image::Magick->new(); #框线及鱼尾图层

$limg->Set(size => $cw.'x'.$ch);
$limg->ReadImage("canvas:transparent");

my $delta = 5; #标准间距
my $gr = 0.618; #黄金分割率
#粗外框
$limg->Draw(primitive => 'rectangle', points => get_points($ml-$olw/2-$moh-$delta, $mt-$olw/2-$mov-$delta, $cw-$mr+$olw/2+$moh+$delta, $ch-$mb+$olw/2+$mov+$delta),
	fill => 'transparent', stroke => $olc, strokewidth => $olw);
#细内框
$limg->Draw(primitive => 'rectangle', points => get_points($ml-$delta, $mt-$delta, $cw-$mr+$delta, $ch-$mb+$delta),
	fill => 'transparent', stroke => $ilc, strokewidth => $ilw);
#列细线
foreach my $cid (1..$cln) {
	#next if($cid == 18 or $cid == 19);
	my $tilc = ($ifmr and $mrn > 1) ? $mrcc : $ilc; #多栏模式时，更新栏内列细线颜色
	$tilc = $ilc if($cid == $cln/2 or $cid == $cln/2+1); #版心两侧列细线
	my $wd = ($cid > $cln/2) ? ($lcw-$clw) : 0; #对于越过版心列的横坐标调整
	$limg->Draw(primitive => 'line', points => get_points($ml+$wd+$clw*$cid, $mt, $ml+$wd+$clw*$cid, $ch-$mb),
		fill => $tilc, stroke => $tilc, strokewidth => $ilw);
}
#多栏模式时打印分栏横线
if($ifmr and $mrn > 1) {
	my $mrh = ($ch-$mt-$mb)/$mrn;
	foreach my $rid (1..$mrn-1) {
		$limg->Draw(primitive => 'line', points => get_points($ml, $mt+$rid*$mrh, $cw/2-$lcw/2, $mt+$rid*$mrh),
			fill => $ilc, stroke => $ilc, strokewidth => $mrlw);
		$limg->Draw(primitive => 'line', points => get_points($cw-$mr, $mt+$rid*$mrh, $cw/2+$lcw/2, $mt+$rid*$mrh),
			fill => $ilc, stroke => $ilc, strokewidth => $mrlw);
	}
}
#上鱼尾
draw_fishtop($fty, $ftrh, $ftth);
#下鱼尾
if($fbd == 0) { draw_fishbtm_down($fby, $fbrh, $fbth); } #顺鱼尾
if($fbd == 1) { draw_fishbtm_up($fby, $fbrh, $fbth); } #对鱼尾
#鱼尾装饰图，要求：正方形，透明底色，主体图案为白色
if($ffi and -f $ffi) {
	#三叶草图层
	#将装饰图缩小为鱼尾尾部高度的黄金分割比例尺寸，距版心左、右侧线距离为$delta并与鱼身高度对齐
	my $fimg1 = Image::Magick->new(); #左上
	my ($fw, $fh) = ($ftrh*$gr, $ftrh*$gr);
	$fimg1->ReadImage($ffi);
	$fimg1->AdaptiveResize(width => $fw, height => $fh, method => 'Lanczos'); #缩小
	my $fimg2 = $fimg1->Clone(); #右上
	my $fimg3 = $fimg1->Clone(); #右下
	my $fimg4 = $fimg1->Clone(); #左下
	$fimg1->Rotate(degrees => -30, background => 'transparent'); #逆时针旋转30度
	($fw, $fh) = ($fimg1->Get('width'), $fimg1->Get('height')); #旋转后更新宽、高
	$limg->Composite(image => $fimg1, x => $cw/2-$lcw/2+$delta, y => $fty+$ftrh-$fh, compose => 'Over');
	$fimg2->Rotate(degrees => 30, background => 'transparent'); #顺时针旋转30度
	($fw, $fh) = ($fimg2->Get('width'), $fimg2->Get('height'));
	$limg->Composite(image => $fimg2, x => $cw/2+$lcw/2-$fw-$delta, y => $fty+$ftrh-$fh, compose => 'Over');
	$fimg3->Rotate(degrees => -150, background => 'transparent'); ##逆时针旋转150度
	$fimg4->Rotate(degrees => 150, background => 'transparent'); #逆时针旋转150度
	if($fbrh > 0 and $fbth > 0) {
		if($fbd == 0) { #顺鱼尾
			($fw, $fh) = ($fimg3->Get('width'), $fimg3->Get('height'));
			$limg->Composite(image => $fimg3, x => $cw/2-$lcw/2+$delta, y => $fby+$fbrh-$fh, compose => 'Over');
			($fw, $fh) = ($fimg4->Get('width'), $fimg4->Get('height'));
			$limg->Composite(image => $fimg4, x => $cw/2+$lcw/2-$fw-$delta, y => $fby+$fbrh-$fh, compose => 'Over');
		}
		if($fbd == 1) { #对鱼尾
			($fw, $fh) = ($fimg3->Get('width'), $fimg3->Get('height'));
			$limg->Composite(image => $fimg3, x => $cw/2-$lcw/2+$delta, y => $fby-$fbrh, compose => 'Over');
			($fw, $fh) = ($fimg4->Get('width'), $fimg4->Get('height'));
			$limg->Composite(image => $fimg4, x => $cw/2+$lcw/2-$fw-$delta, y => $fby-$fbrh, compose => 'Over');
		}
	}
	$limg->Opaque(color => 'white', fill => 'transparent'); #装饰图白色主体替换为透明
}

#花鱼尾，弧形花鱼尾
if($iff) {
	#弧形花鱼尾图层
   	my $eimg = Image::Magick->new();
	$eimg->Set(size => ($lcw/2).'x'.($ftth+10)); #以涵盖半个三角鱼尾矩形为画布绘制花鱼尾，+10为了确保包含超出的弧形
	$eimg->ReadImage('canvas:transparent');
	my $dd = sqrt(($lcw/2)**2+$ftth**2); #矩阵对边边长
	my $dsin = $ftth/$dd; #矩阵左上三角形右上锐角的正弦函数
	my $dcos = $lcw/2/$dd; ##矩阵左上三角形右上锐角的余弦函数
	my $ddr = 0.4; #第一段弧线对应的边长长度占比
    $eimg->Draw( #第一段填充弧形
		primitive => 'ellipse',
		points => get_2points_ellipse(14, $lcw/2-2*$dcos, 2*$dsin, $lcw/2-($dd*$ddr-2)*$dcos, ($dd*$ddr-2)*$dsin),
		fill => $ftc,
	);
    $eimg->Draw( #第一段弧线
		primitive => 'ellipse',
		points => get_2points_ellipse(10, $lcw/2, 0, $lcw/2-$dd*$ddr*$dcos, $dd*$ddr*$dsin),
		fill => 'transparent',
		stroke => $ftc,
		strokewidth => 1,
	);
    $eimg->Draw( #第二段带填充弧形
		primitive => 'ellipse',
		points => get_2points_ellipse(14, $lcw/2-($dd*$ddr+2)*$dcos, ($dd*$ddr+2)*$dsin, $lcw/2-($dd-2)*$dcos, ($dd-2)*$dsin),
		fill => $ftc,
	);
    $eimg->Draw( #第二段弧线
		primitive => 'ellipse',
		points => get_2points_ellipse(10, $lcw/2-$dd*$ddr*$dcos, $dd*$ddr*$dsin, 0, $ftth),
		fill => 'transparent',
		stroke => $ftc,
		strokewidth => 1,
	);
	$limg->Composite(image => $eimg, x => $cw/2-$lcw/2, y => $fty+$ftrh, compose => 'Over'); #左上
	$eimg->Flop(); #左右翻转
	$limg->Composite(image => $eimg, x => $cw/2, y => $fty+$ftrh, compose => 'Over'); #右上
	if($fbrh > 0 and $fbth > 0) {
		if($fbd == 0) { #顺鱼尾时
			$limg->Composite(image => $eimg, x => $cw/2, y => $fby+$fbrh, compose => 'Over'); #右下
			$eimg->Flop();
			$limg->Composite(image => $eimg, x => $cw/2-$lcw/2, y => $fby+$fbrh, compose => 'Over'); #左下
		}
		if($fbd == 1) { #对鱼尾时
			$eimg->Flip(); #上下翻转
			$limg->Composite(image => $eimg, x => $cw/2, y => $fby-$fbrh-$fbth-9, compose => 'Over'); #右下
			$eimg->Flop();
			$limg->Composite(image => $eimg, x => $cw/2-$lcw/2, y => $fby-$fbrh-$fbth-9, compose => 'Over'); #左下
		}
	}
}
#版心鱼尾到上下边框的粗线
if($ftlw) { $limg->Draw(primitive => 'line', points => get_points($cw/2, $mt-$mov-$delta, $cw/2, $fty-$flm), stroke => $flc, strokewidth => $ftlw); }
if($fblw) { $limg->Draw(primitive => 'line', points => get_points($cw/2, $fby+$flm, $cw/2, $ch-$mb+$mov+$delta), stroke => $flc, strokewidth => $fblw); }
#合并图层
$cimg->Composite(image => $limg, x => 0, y => 0, compose => 'Over');
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

$cimg->Write("$cid.jpg");
print "保存到 '$cid.jpg'！\n";
print '-'x60, "\n";

sub get_points {
	my ($fx, $fy, $tx, $ty) = @_;
	return "$fx,$fy $tx,$ty"; ##Draw line,rectangle参数格式
}

sub get_points_fish {
	my ($x1, $y1, $x2, $y2, $x3, $y3, $x4, $y4, $x5, $y5) = @_;
	return "M $x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 Z"; #Draw path鱼尾五边形参数格式
}

sub get_points_path {
	my ($fx, $fy, $px, $py, $tx, $ty) = @_;
	return "M $fx,$fy $px,$py $tx,$ty Z"; #Draw path三角形参数格式
}
#花鱼尾的弧线参数：给定两点A、B及距离两点中点距离的C，返回以C点为圆心，经过A、B两点弧线的Draw ellipse参数
sub get_2points_ellipse {
	#距离，第一点坐标，第二点坐标
	my ($cd, $x1, $y1, $x2, $y2) = @_;
	my ($cx, $cy) = (($x1+$x2)/2, ($y1+$y2)/2); #两点直线中点
	my $d21 = sqrt(($x1-$x2)**2+($y1-$y2)**2); #两点直线距离
	my $sin21 = abs(($x2-$x1)/$d21); #两点及水平线组成的直角三角形锐角的正弦
	my $cos21 = abs(($y2-$y1)/$d21); #余弦
	my $ncx = $cx-$cd*$cos21; #新圆心坐标
	my $ncy = $cy-$cd*$sin21; #新圆心坐标
	my $cr = sqrt(($ncx-$x1)**2+($ncy-$y1)**2); #新圆半径
	my $dgrees1 = rad2deg(atan2($y1-$ncy, $x1-$ncx)); #反切得到弧度，弧度转为角度
	my $dgrees2 = rad2deg(atan2($y2-$ncy, $x2-$ncx));
	return "$ncx,$ncy $cr,$cr $dgrees1,$dgrees2";
}
#上鱼尾
sub draw_fishtop {
    my ($fy, $dy1, $dy2) = @_;
    #鱼尾上细线
    $limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm), stroke => $flc, strokewidth => $flw);
    #鱼尾五边形
    $limg->Draw(
    	primitive => 'path',
    	points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    	#stroke => $flc, strokewidth => $flw,
    	fill => $ftc);
    #鱼尾下方两细斜线
    if(not $iff) {
		$limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    	$limg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
	}
}
#下鱼尾，顺鱼尾
sub draw_fishbtm_down {
    my ($fy, $dy1, $dy2) = @_;
    #鱼尾上细线
    $limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$flm, $cw/2+$lcw/2, $fy-$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) { #设置为0时，下鱼尾萎缩为双横线
	    $limg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy+$dy1+$dy2, $cw/2, $fy+$dy1, $cw/2-$lcw/2, $fy+$dy1+$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	if(not $iff or ($dy1 == 0 and $dy2 == 0)) { #非花鱼尾或下鱼尾萎缩时，两细线萎缩为直线
		$limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$dy1+$dy2+$flm, $cw/2, $fy+$dy1+$flm), fill => $flc);
    	$limg->Draw(primitive => 'line', points => get_points($cw/2, $fy+$dy1+$flm, $cw/2+$lcw/2, $fy+$dy1+$dy2+$flm), fill => $flc);
    }
}
#下鱼尾，对鱼尾
sub draw_fishbtm_up {
    my ($fy, $dy1, $dy2) = @_;
    $limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy+$flm, $cw/2+$lcw/2, $fy+$flm),
    	stroke => $flc, strokewidth => $flw);
    if($dy1 > 0 or $dy2 > 0) { #设置为0时，下鱼尾萎缩为双横线
	    $limg->Draw(
    		primitive => 'path',
    		points => get_points_fish($cw/2-$lcw/2, $fy, $cw/2+$lcw/2, $fy, $cw/2+$lcw/2, $fy-$dy1-$dy2, $cw/2, $fy-$dy1, $cw/2-$lcw/2, $fy-$dy1-$dy2),
    		stroke => $flc, strokewidth => $flw, fill => $fbc
    	);
	}
	if(not $iff or ($dy1 == 0 and $dy2 == 0)) { #非花鱼尾或下鱼尾萎缩时，两细线萎缩为直线
		$limg->Draw(primitive => 'line', points => get_points($cw/2-$lcw/2, $fy-$dy1-$dy2-$flm, $cw/2, $fy-$dy1-$flm), fill => $flc);
    	$limg->Draw(primitive => 'line', points => get_points($cw/2, $fy-$dy1-$flm, $cw/2+$lcw/2, $fy-$dy1-$dy2-$flm), fill => $flc);
    }
}
