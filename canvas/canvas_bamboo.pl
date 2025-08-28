#!/usr/bin/perl
#by shanleiguang, 2025
use strict;
use warnings;

use Image::Magick;
use Getopt::Std;
use Encode;
use utf8;

my %canvas;
open CONFIG, "< bamboo.cfg";
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

my $bg = $canvas{'canvas_background_image'};
my ($iw, $ih) = ($canvas{'canvas_width'}, $canvas{'canvas_height'});
my ($hm, $itm, $ibm) = ($canvas{'margins_left'}, $canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($cln, $lcw) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});

my $bc0 = 'rgb(210,200,190)'; #宣纸色
my $bc1 = 'rgb(233,189,96)'; #竹简色
my $bc2 = '#eeeeee'; #竹简纹理色
my $bc3 = 'rgb(148,112,55)'; #韦编色
my $cw = ($iw-$hm*2)/$cln; #列宽

my $image = Image::Magick->new();

$image->Set(size => $iw.'x'.$ih);

if($bg and -f $bg) {
    $image->ReadImage($bg);
    my ($bw, $bh) = ($image->Get('width'), $image->Get('height'));
    if($bw != $iw or $bh != $ih) {
        $image->AdaptiveResize(width => $iw, height => $ih, x => 0, y => 0, method => 'Hermit');
    }
} else {
    $image->ReadImage("canvas:$bc0");
    $image->AddNoise(noise => 'gaussian', attenuate => 0.6); # 高斯噪声
    $image->Blur(radius => 3, sigma=> 1.5); # 模糊创建纤维质感
    $image->BrightnessContrast(brightness => 12, contrast => 5); # 微调对比度
}

my $texture = Image::Magick->new();

$texture->Set(size => $iw.'x'.$ih);
$texture->ReadImage('canvas:transparent');

foreach my $i (0..$cln-1) {
    my $tm = $itm - 50 - 3*rand(2); #竹简上边高度增加些微随机
    my $bm = $ibm - 50 - 3*rand(2); #竹简下边高度增加些微随机

    my $p1 = ($hm+$cw*$i+$cw*0.05).','.$tm;
    my $p2 = ($hm+$cw*($i+1)-$cw*0.05).','.($ih-$bm);
    my $p3 = ($hm+$cw*($i+1)-$cw*0.05).','.$tm;
    my $p4 = ($hm+$cw*$i+$cw*0.05).','.($ih-$bm);

    $image->Draw(primitive => 'rectangle', points => "$p1 $p2", fill => $bc1); #竹简
    $image->Draw(primitive => 'line', points => "$p2, $p3", stroke => '#cccccc', strokewidth => 2); #右阴影线
    $image->Draw(primitive => 'line', points => "$p2, $p4", stroke => '#cccccc', strokewidth => 2); #下阴影线

    #韦编
    my $l1 = ($hm+$cw*$i-$cw*0.025).','.($itm-15);
    my $l2 = ($hm+$cw*$i).','.($itm-10);
    my $l3 = ($hm+$cw*($i+1)).','.($itm-10);
    my $l4 = ($hm+$cw*($i+1)+$cw*0.025).','.($itm-15);
    my $ld = $cw/10;

    foreach my $j (0..9) {
        next if($j == 5);
        my $t1 = ($hm+$cw*$i-$cw*0.025+$ld*$j).','.($itm-15);
        my $t2 = ($hm+$cw*$i-$cw*0.025+$ld*($j+1)).','.($itm-15);
        my $t3 = ($hm+$cw*$i+$ld*$j).','.($itm-10);
        $image->Draw(primitive => 'line', points => "$t1, $t3", stroke => $bc3, strokewidth => 2);
        $image->Draw(primitive => 'line', points => "$t2, $t3", stroke => $bc3, strokewidth => 2);
    }

    $image->Draw(primitive => 'line', points => "$l2, $l3", stroke => $bc3, strokewidth => 1);
    $image->Draw(primitive => 'line', points => "$l1, $l4", stroke => $bc3, strokewidth => 2);

    my $l5 = ($hm+$cw*$i-$cw*0.025).','.($ih-$ibm+15);
    my $l6 = ($hm+$cw*$i).','.($ih-$ibm+10);
    my $l7 = ($hm+$cw*($i+1)).','.($ih-$ibm+10);
    my $l8 = ($hm+$cw*($i+1)+$cw*0.025).','.($ih-$ibm+15);

    foreach my $j (0..9) {
        next if($j == 5);
        my $t1 = ($hm+$cw*$i-$cw*0.025+$ld*$j).','.($ih-$ibm+15);
        my $t2 = ($hm+$cw*$i-$cw*0.025+$ld*($j+1)).','.($ih-$ibm+15);
        my $t3 = ($hm+$cw*$i+$ld*$j).','.($ih-$ibm+10);
        $image->Draw(primitive => 'line', points => "$t1, $t3", stroke => $bc3, strokewidth => 2);
        $image->Draw(primitive => 'line', points => "$t2, $t3", stroke => $bc3, strokewidth => 2);
    }

    $image->Draw(primitive => 'line', points => "$l6, $l7", stroke => $bc3, strokewidth => 1);
    $image->Draw(primitive => 'line', points => "$l5, $l8", stroke => $bc3, strokewidth => 2);

    #竹简纹理
    my $rlc = 30;
    foreach (0..$rlc) {
        my $ci = 220+rand(35); #纹理浅色增加一些随机变化
        my $rc = "rgb($ci,$ci,$ci)";
        my $rx = $hm+$cw*$i+$cw*0.05+$cw*0.9*rand(10)/10;
        my $r1 = $rx.','.($itm+100+($ih-$itm-$ibm-100)*rand(1));
        my $r2 = $rx.','.($itm+100+($ih-$itm-$ibm-100)*rand(1));
        $texture->Draw(primitive => 'line', points => "$r1, $r2", fill => $rc, strokewidth => rand(3));
    }
}

$texture->AddNoise(noise => 'gaussian', attenuate => 0.6); # 高斯噪声
$texture->Blur(radius => 1.5, sigma=> 1.5); # 模糊创建纤维质感
$image->Composite(image => $texture, compose => 'Over'); #合并
$image->Write('bamboo.jpg')

