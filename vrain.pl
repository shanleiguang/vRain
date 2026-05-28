#!/usr/bin/perl
#==============================================================================
#
#   vRain（兀雨）— 中文古籍刻本风格直排电子书制作工具
#   Chinese Ancient Book-Style Vertical PDF E-book Generator
#
#   Version:    v1.5.1
#   Author:     shanleiguang <shanleiguang@gmail.com>
#   GitHub:     https://github.com/shanleiguang/vRain
#   License:    MIT
#
#   Version History:
#       v1.5   2025-05   Font metric adjustment for multi-font visual consistency,
#                        fallback font bold simulation, code style standardization
#       v1.4   2025-03   Multi-row layout, font configuration improvements
#       v1.3   2025-01   Wavy book-title lines, rounded frames, markup system
#       v1.2   2024-12   Double-row interlinear commentary, punctuation processing
#       v1.1   2024-11   Multi-font fallback system with Font::FreeType glyph check
#       v1.0   2024-10   Initial release
#
#   Dependencies:
#       PDF::Builder        — PDF generation
#       Font::FreeType      — font glyph detection and metrics
#       Image::Magick       — background image generation (canvas/*.pl)
#       Ghostscript (gs)    — PDF compression (-c option)
#
#==============================================================================
use strict;
use warnings;

use PDF::Builder;
use Font::FreeType;
use Math::Trig qw(pi);
use Getopt::Std;
use POSIX qw(strftime);
use Encode;
use utf8;

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my $software = 'vRain';
my $version = 'v1.5.1';

# ============================================================================
# 程序输入参数设置与初始化
# ============================================================================
my %opts;

getopts('hcvz:b:f:t:', \%opts);
if(defined $opts{'h'}) { print_help(); exit; }

my $book_id = $opts{'b'};
my $from = $opts{'f'} ? $opts{'f'} : 1;
my $to = $opts{'t'} ? $opts{'t'} : 1;

if(not -d "books/$book_id") { print "错误：未发现该书籍目录'books/$book_id'！\n"; exit; }
if(not -d "books/$book_id/text" ) { print "错误: 未发现该书籍文本目录'books/$book_id/text'！\n"; exit; }
if(not -f "books/$book_id/book.cfg") { print "错误：未发现该书籍排版配置文件'books/$book_id/book.cfg'！\n"; exit; }

print_welcome();
if(defined $opts{'z'}) { print "注意：-z 测试模式，仅输出", $opts{'z'}, "页用于调试排版参数！\n"; }

# ============================================================================
# 读取配置文件（书籍配置 + 背景图配置）
# ============================================================================

#读取阿拉伯数字与中文数字对应，用于章回、页码显示
my %zhnums;
open ZHNUM, '< db/num2zh_jid.txt';
while(<ZHNUM>) {
    chomp;
    $_ = decode('utf-8', $_);
    my ($a, $b) = split /\|/, $_;
    $zhnums{$a} = $b;
}
close(ZHNUM);

#读取书籍配置文件
my %book;
open BCONFIG, "< books/$book_id/book.cfg";
print "读取书籍排版配置文件'books/$book_id/book.cfg'...\n";
while(<BCONFIG>) {
    chomp;
    next if(m/^\s{0,}$/);
    next if(m/^#/);
    s/#.*$// if(not m/=#/);
    s/\s//g;
    my ($k, $v) = split /=/, $_;
    $v = decode('utf-8', $v);
    $book{$k} = $v;
}
close(BCONFIG);

#书籍标题、作者、背景图ID、可选字体、正文及批注字体组
my ($author, $title) = ($book{'author'}, $book{'title'});
my ($canvas_id, $row_num, $row_delta_y) = ($book{'canvas_id'}, $book{'row_num'}, $book{'row_delta_y'});
my ($fn1, $fn2, $fn3, $fn4, $fn5) = ($book{'font1'}, $book{'font2'}, $book{'font3'}, $book{'font4'}, $book{'font5'});
my ($fnr1, $fnr2, $fnr3, $fnr4, $fnr5) = ($book{'font1_rotate'}, $book{'font2_rotate'}, $book{'font3_rotate'}, $book{'font4_rotate'}, $book{'font5_rotate'});
my ($fs1_text, $fs2_text, $fs3_text, $fs4_text, $fs5_text) = ($book{'text_font1_size'}, $book{'text_font2_size'}, $book{'text_font3_size'}, $book{'text_font4_size'}, $book{'text_font5_size'});
my ($fs1_comm, $fs2_comm, $fs3_comm, $fs4_comm, $fs5_comm) = ($book{'comment_font1_size'}, $book{'comment_font2_size'}, $book{'comment_font3_size'}, $book{'comment_font4_size'}, $book{'comment_font5_size'});
my ($tfarray, $cfarray) = ($book{'text_fonts_array'}, $book{'comment_fonts_array'});
#书名号文字左侧波浪线
my $if_tagbl = $book{'if_tag_bookline'};
my ($bline_w, $bline_c) = ($book{'book_line_width'}, $book{'book_line_color'});
#正文字符右侧批注符号，圈注为o、点注为p、线注为l
my ($if_tagcn, $if_tagpn, $if_tagln) = ($book{'if_tag_circlenote'}, $book{'if_tag_pointnote'}, $book{'if_tag_linenote'});
my ($text_note_ox, $text_note_oy, $text_note_or, $text_note_ow, $text_note_oc) =
    ($book{'text_note_ox'}, $book{'text_note_oy'}, $book{'text_note_or'}, $book{'text_note_ow'}, $book{'text_note_oc'});
my ($text_note_px, $text_note_py, $text_note_ps, $text_note_pc) =
    ($book{'text_note_px'}, $book{'text_note_py'}, $book{'text_note_ps'}, $book{'text_note_pc'});
my ($text_note_lx, $text_note_ly, $text_note_lw, $text_note_lc) =
    ($book{'text_note_lx'}, $book{'text_note_ly'}, $book{'text_note_lw'}, $book{'text_note_lc'});
#字符底框参数
my ($if_tagrf, $if_tagcf) = ($book{'if_tag_rectframe'}, $book{'if_tag_circleframe'});
##圆角方框
my ($rect_type, $rect_bcolor, $rect_fcolor) = ($book{'rect_type'}, $book{'rect_bcolor'}, $book{'rect_fcolor'});
my ($text_rty, $text_rth, $text_rtr) = ($book{'text_rect_y'}, $book{'text_rect_h'}, $book{'text_rect_r'});
my ($comm_rty, $comm_rth, $comm_rtr) = ($book{'comm_rect_y'}, $book{'comm_rect_h'}, $book{'comm_rect_r'});
##圆形框
my ($text_cy, $text_cr, $text_cf, $comm_cy, $comm_cr, $comm_cf) =
    ($book{'text_circle_y'}, $book{'text_circle_r'}, $book{'text_circle_f'}, $book{'comm_circle_y'}, $book{'comm_circle_r'}, $book{'comm_circle_f'});
my ($circle_type, $circle_bcolor, $circle_fcolor) = ($book{'circle_type'}, $book{'circle_bcolor'}, $book{'circle_fcolor'});
#正文字符缩放
my $if_tagtz = $book{'if_tag_textzoom'};
my $text_zoom = $book{'text_zoom'};
#字体度量微调
my $if_font_metric_adjust = $book{'if_font_metric_adjust'} || 0;
#回退字体模拟加粗
my $if_fallback_bold = $book{'if_fallback_bold'} || 0;
my $fallback_bold_stroke_width = $book{'fallback_bold_stroke_width'} || 1.0;

if(not $canvas_id) { print "错误：未定义背景图ID 'canvas_id'！\n"; exit; }
if(not -f "canvas/$canvas_id.cfg") { print "错误：未发现背景图cfg配置文件！\n"; exit; }
if(not -f "canvas/$canvas_id.jpg") { print "错误：未发现背景图jpg图片文件！\n"; exit; }
if(not $fn1) { print "错误：主字体'font1'未定义！\n"; exit; }
if($fn1 and not -f "fonts/$fn1") { print "错误：未发现字体'fonts/$fn1'！\n"; exit; }
if($fn2 and not -f "fonts/$fn2") { print "错误：未发现字体'fonts/$fn2'！\n"; exit; }
if($fn3 and not -f "fonts/$fn3") { print "错误：未发现字体'fonts/$fn3'！\n"; exit; }
if($fn4 and not -f "fonts/$fn4") { print "错误：未发现字体'fonts/$fn4'！\n"; exit; }
if($fn5 and not -f "fonts/$fn5") { print "错误：未发现字体'fonts/$fn5'！\n"; exit; }

#存储字体参数哈希
my %fonts;
if($fn1) { $fonts{$fn1} = [$fs1_text, $fs1_comm, $fnr1]; }
if($fn2) { $fonts{$fn2} = [$fs2_text, $fs2_comm, $fnr2]; }
if($fn3) { $fonts{$fn3} = [$fs3_text, $fs3_comm, $fnr3]; }
if($fn4) { $fonts{$fn4} = [$fs4_text, $fs4_comm, $fnr4]; }
if($fn5) { $fonts{$fn5} = [$fs5_text, $fs5_comm, $fnr5]; }

my @fonts= ($fn1, $fn2, $fn3, $fn4, $fn5); #可选字体数组
my (@tfns, @cfns); #正文字体数组、批注字体数组
#正文字体数组
foreach my $fid (split //, $tfarray) {
    push @tfns, $fonts[$fid-1] if($fonts[$fid-1]);
}
#批注字体数组
foreach my $fid (split //, $cfarray) {
    push @cfns, $fonts[$fid-1] if($fonts[$fid-1]);
}

#字体度量微调：缩放因子缓存和 FreeType face 缓存
my %font_scale;
my %face_cache;


#正文、批注文字颜色
my ($text_font_color, $comment_font_color) = ($book{'text_font_color'}, $book{'comment_font_color'});
#简易封面标题、作者的字体、位置
my ($cover_title_font_size, $cover_title_y) = ($book{'cover_title_font_size'}, $book{'cover_title_y'});
my ($cover_author_font_size, $cover_author_y) = ($book{'cover_author_font_size'}, $book{'cover_author_y'});
my $cover_font_color = $book{'cover_font_color'};
#版心标题、页码的字体、位置
my ($title_postfix, $title_directory) = ($book{'title_postfix'}, $book{'title_directory'});
my ($title_font_size, $title_font_color, $title_y, $title_ydis) = ($book{'title_font_size'}, $book{'title_font_color'}, $book{'title_y'}, $book{'title_ydis'});
my ($pager_font_size, $pager_font_color, $pager_y) = ($book{'pager_font_size'}, $book{'pager_font_color'}, $book{'pager_y'});
#标点符号替代规则
my ($exp_replace_comma, $exp_replace_number) = ($book{'exp_replace_comma'}, $book{'exp_replace_number'});
#标点符号过滤规则
my $exp_delete_comma = $book{'exp_delete_comma'};
#无标点符号模式、标点符号归一化模式
my ($if_nocomma, $if_onlyperiod) = ($book{'if_nocomma'}, $book{'if_onlyperiod'});
my ($exp_nocomma, $exp_onlyperiod) = ($book{'exp_nocomma'}, $book{'exp_onlyperiod'});
#正文中不占字符位的标点符号、旋转直排的标点符号
my ($text_comma_nop, $text_comma_90) = ($book{'text_comma_nop'}, $book{'text_comma_90'});
my ($text_comma_nop_size, $text_comma_nop_x, $text_comma_nop_y) = ($book{'text_comma_nop_size'}, $book{'text_comma_nop_x'}, $book{'text_comma_nop_y'});
my ($text_comma_90_size, $text_comma_90_x, $text_comma_90_y) = ($book{'text_comma_90_size'}, $book{'text_comma_90_x'}, $book{'text_comma_90_y'});
#批注中不占字符位的标点符号、旋转直排的标点符号
my ($comment_comma_nop, $comment_comma_90) = ($book{'comment_comma_nop'}, $book{'comment_comma_90'});
my ($comment_comma_nop_size, $comment_comma_nop_x, $comment_comma_nop_y) = ($book{'comment_comma_nop_size'}, $book{'comment_comma_nop_x'}, $book{'comment_comma_nop_y'});
my ($comment_comma_90_size, $comment_comma_90_x, $comment_comma_90_y) = ($book{'comment_comma_90_size'}, $book{'comment_comma_90_x'}, $book{'comment_comma_90_y'});

#如启用以下特殊符号，程序会对符号内标识的文字加入特定的排版效果；此时所启用的特殊符号亦不将占字符位（也不显示），因此同时添加到不占字符位标点符号变量中，不必重复设置，以确保正确排版
if($if_tagbl) { $text_comma_nop.= '|《|》'; $comment_comma_nop.= '|《|》'; } #书名左侧线
if($if_tagrf) { $text_comma_nop.= '|〔|〕'; $comment_comma_nop.= '|〔|〕'; } #圆角方框
if($if_tagcf) { $text_comma_nop.= '|〈|〉'; $comment_comma_nop.= '|〈|〉'; } #圆框
if($if_tagtz) { $text_comma_nop.= '|（|）'; $comment_comma_nop.= '|（|）'; } #正文字符字体大小缩放
if($if_tagcn) { $text_comma_nop.= '|｛|｝'; $comment_comma_nop.= '|｛|｝'; } #正文字符右侧圈注
if($if_tagpn) { $text_comma_nop.= '|＜|＞'; $comment_comma_nop.= '|＜|＞'; } #正文字符右侧点注
if($if_tagln) { $text_comma_nop.= '|［|］'; $comment_comma_nop.= '|［|］'; } ##正文字符右侧线注

#读取背景图配置文件
my %canvas;
open CCONFIG, "< canvas/$canvas_id.cfg";
print "读取背景图配置文件'canvas/$canvas_id.cfg'...\n";
while(<CCONFIG>) {
    chomp;
    next if(m/^\s{0,}$/);
    next if(m/^#/);
    s/#.*$// if(not m/=#/);
    s/\s//g;
    my ($k, $v) = split /=/, $_;
    $v = decode('utf-8', $v);
    $canvas{$k} = $v;
}
close(CCONFIG);

#背景图参数
my ($canvas_width, $canvas_height) = ($canvas{'canvas_width'}, $canvas{'canvas_height'});
my ($margins_top, $margins_bottom) = ($canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($margins_left, $margins_right) = ($canvas{'margins_left'}, $canvas{'margins_right'});
my ($col_num, $lc_width) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});
my ($olw, $olc, $ilw, $ilc, $ohm, $ovm) = ($canvas{'outline_width'}, $canvas{'outline_color'}, $canvas{'inline_width'}, $canvas{'inline_color'}, $canvas{'outline_hmargin'}, $canvas{'outline_vmargin'});
my ($if_multirows, $multirows_hl, $multirows_num) = ($canvas{'if_multirows'}, $book{'multirows_horizontal_layout'}, $canvas{'multirows_num'});
my $logo_text = $canvas{'logo_text'};

print "\t标题：$title\n";
print "\t作者：$author\n";
print "\t背景：$canvas_id\n";
print "\t尺寸：$canvas_width x $canvas_height\n";
print "\t多栏：$if_multirows\t栏数：$multirows_num\t布局：$multirows_hl\n";
print "\t列数：$col_num\n";
print "\t每列字数：$row_num\n";
print "\t正文字体数组：$tfarray\n";
print "\t批注字体数组：$cfarray\n";
print "\t是否无标点：$if_nocomma\n";
print "\t标点归一化：$if_onlyperiod\n";
print "\t《》书名左侧线：$if_tagbl\n";
print "\t〔〕圆角方框：$if_tagrf\n";
print "\t〈〉圆形框：$if_tagcf\n";
print "\t（）正文大小缩放：$if_tagtz\n";
print "\t｛｝正文右侧圈注：$if_tagcn\n";
print "\t＜＞正文右侧点注：$if_tagpn\n";
print "\t［］正文右侧线注：$if_tagln\n";
print "\t字体度量微调：$if_font_metric_adjust\n";
print "\t回退字体加粗：$if_fallback_bold\t描边宽度：$fallback_bold_stroke_width\n";
print '-'x60, "\n";

# ============================================================================
# 计算排版座标网格
# ============================================================================

#计算列宽、行高
my $cw = ($canvas_width - $margins_left - $margins_right - $lc_width)/$col_num;
my $rh = ($canvas_height - $margins_top - $margins_bottom)/$row_num;
#页面位置数组
my (@pos, $pos_x, $pos_y); #单列
my @pos_r = ([0,0]); #单列左右双排
my @pos_l = ([0,0]); #单列左右双排
#生成文字坐标，$pos_l、$pos_r用于夹批双排，$pos_l用于正文单排
if($if_multirows and $multirows_num != 1) {
    if($row_num % $multirows_num != 0) {
        print "错误：多横栏模式下，每列字数应是栏数的倍数！\n" and exit;
    }
    my $rrow_num = $row_num/$multirows_num;
    #分栏横向整叶换行
    if($multirows_hl == 1) {
        foreach my $rid (1..$multirows_num) {
            foreach my $i (1..$col_num) {
                foreach my $j (1..$rrow_num) {
                    $pos_x = $canvas_width - $margins_right - $cw*$i if($i <= $col_num/2);
                    $pos_x = $canvas_width - $margins_right - $cw*$i - $lc_width if($i > $col_num/2);
                    $pos_y = $canvas_height - $margins_top - $rrow_num*($rid-1)*$rh - $rh*$j + $row_delta_y;
                    push @pos_l, [$pos_x, $pos_y];
                    push @pos_r, [$pos_x+$cw/2, $pos_y];
                }
            }
        }
    }
    #分栏横向半叶换行
    if($multirows_hl == 2) {
        foreach my $rid (1..$multirows_num) {
            foreach my $i (1..$col_num/2) {
                foreach my $j (1..$rrow_num) {
                    $pos_x = $canvas_width - $margins_right - $cw*$i;
                    $pos_y = $canvas_height - $margins_top - $rrow_num*($rid-1)*$rh - $rh*$j + $row_delta_y;
                    push @pos_l, [$pos_x, $pos_y];
                    push @pos_r, [$pos_x+$cw/2, $pos_y];
                }
            }
        }
        foreach my $rid (1..$multirows_num) {
            foreach my $i ($col_num/2+1..$col_num) {
                foreach my $j (1..$rrow_num) {
                    $pos_x = $canvas_width - $margins_right - $cw*$i - $lc_width;
                    $pos_y = $canvas_height - $margins_top - $rrow_num*($rid-1)*$rh - $rh*$j + $row_delta_y;
                    push @pos_l, [$pos_x, $pos_y];
                    push @pos_r, [$pos_x+$cw/2, $pos_y];
                }
            }
        }
    }
    $row_num = $rrow_num;
} else {
    foreach my $i (1..$col_num) {
        foreach my $j (1..$row_num) {
            $pos_x = $canvas_width - $margins_right - $cw*$i if($i <= $col_num/2);
            $pos_x = $canvas_width - $margins_right - $cw*$i - $lc_width if($i > $col_num/2);
            $pos_y = $canvas_height - $margins_top - $rh*$j + $row_delta_y;
            push @pos_l, [$pos_x, $pos_y];
            push @pos_r, [$pos_x+$cw/2, $pos_y];
            #具体的对应关系
            #$pos_l[ ($i-1)*$row_num+$j ] = [$pos_x, $pos_y];
            #$pos_r[ ($i-1)*$row_num+$j ] = [$pos_x+$cw/2, $pos_y];
        }
    }
}

my @tchars = split //, $title;
my @achars = split //, $author;
my $page_chars_num = ($if_multirows and $multirows_num != 1) ? $col_num*$row_num*$multirows_num : $col_num*$row_num; #重要常量：每页字符计数器
my ($if_text000, $if_text999) = (0, 0); #是否存在用于保存前言及序的000.txt文件
my @dats = ('');
# ============================================================================
# 读取源文本文件
# ============================================================================

#读取书籍文本
opendir TDIR, "books/$book_id/text";
print "读取该书籍全部文本文件'books/$book_id/text/*.txt'...";
foreach my $tfn (sort readdir(TDIR)) {
    next if($tfn =~ m/^\./);
    next if($tfn !~ m/\.txt$/i);
    $if_text000 = 1 if($tfn =~ /^0+\.txt$/i); #是否存在000.txt文件，保存正文前的序言等文字
    $if_text999 = 1 if($tfn eq '999.txt');
    #读取文件，计算段落首尾需要补齐的空格
    my $dat;
    my $text_file = "books/$book_id/text/$tfn";
    open TEXT, "< $text_file";
    while(<TEXT>) {
        chomp;
        next if(/^\s{0,}$/);
        s/\s//g;
        $_ = decode('utf-8', $_);
        #标点符号替换
        if($exp_replace_comma) {
            foreach my $kv (split /\|/, $exp_replace_comma) {
                my ($k, $v) = split //, $kv;
                if($k =~ m/\.|\!|\?|\(|\)|\[|\]|\-/) { $k = '\\'.$k; }
                s/$k/$v/g;
            }
        }
        #中文数字替换
        if($exp_replace_number) {
            foreach my $kv (split /\|/, $exp_replace_number) {
                my ($k, $v) = split //, $kv;
                s/$k/$v/g;
            }
        }
        #标点符号删除
        s/$exp_delete_comma//g if($exp_delete_comma);
        #无标点模式
        s/$exp_nocomma//g if($if_nocomma == 1);
        #标点符号归一化为句读
        if($if_onlyperiod == 1) {
            s/$exp_onlyperiod/。/g;
            s/。+/。/g;
            s/^。//;
        }
        s/\@/ /g; #@代表空格

    	my $tmpstr = $_; #保存基础处理后原始文本
    	my $rnum = 0; #标注文本双排占用长度

    	s/^T.{1}//;
    	s/$text_comma_nop//g if($text_comma_nop); #去除正文中不占字符位的标点
    	s/$comment_comma_nop//g if($comment_comma_nop); #去除批注中不占字符位的标点
    	while(m/【(.*?)】/g) { #重要！去除标注后的正文，必须逐个标注计算，不能把所有标注合并后计算，否则会导致行末补齐空格数量错误
    		my $rdat = $1;
    		my @rchars = split //, $rdat;
    		if(($#rchars+1) % 2 == 0) { #夹批双排，每两个标注文字占用一个正文字符位
    			$rnum+= ($#rchars+1)/2; #偶数时
    		} else {
        		$rnum+= int(($#rchars+1)/2)+1; #奇数时
        	}
   		}
    	s/【.*?】//g; #去除标注文字后的正文

        my @chars = split //, $_; #正文字符数组
        my $spaces_num; #为对齐行高，计算段落末尾需要补齐的空格数

    	$spaces_num = $row_num - ($#chars+1+$rnum) + int(($#chars+1+$rnum)/$row_num)*$row_num;
    	$dat.= $tmpstr;
    	$dat.= ' ' x $spaces_num if($spaces_num > 0 and $spaces_num < $row_num); #$dat存储需要打印到图片的总文本，含标注及标注标识【】
    }
    close(TEXT);
    push @dats, $dat;
}
print $#dats, "个文本文件\n";
close(TDIR);

#去除字符串中的分隔符，用于后续模式匹配
my $comment_comma_nop_tmp = $comment_comma_nop;
$text_comma_nop =~ s/\|//g;
$comment_comma_nop =~ s/\|//g;

my $vpdf = PDF::Builder->new(compress => 'none'); #创建PDF文件

# ============================================================================
# PDF 文档初始化与封面生成
# ============================================================================

my $vpimg = $vpdf->image("canvas/$canvas_id.jpg"); #读取背景图片
my $vpage = $vpdf->page(); #创新新页面

#加载主辅字体
my %vfonts;
$vfonts{$fn1} = $vpdf->ttfont("fonts/$fn1", -noembed=>0, -nosubset=>1) if($fn1);
$vfonts{$fn2} = $vpdf->ttfont("fonts/$fn2", -noembed=>0, -nosubset=>1) if($fn2);
$vfonts{$fn3} = $vpdf->ttfont("fonts/$fn3", -noembed=>0, -nosubset=>1) if($fn3);
$vfonts{$fn4} = $vpdf->ttfont("fonts/$fn4", -noembed=>0, -nosubset=>1) if($fn4);
$vfonts{$fn5} = $vpdf->ttfont("fonts/$fn5", -noembed=>0, -nosubset=>1) if($fn5);

#字体度量微调：预计算各字体缩放因子
if ($if_font_metric_adjust) {
    compute_font_scales($tfns[0], '国', 100);
    print "字体缩放因子：\n";
    for my $f (keys %font_scale) {
        printf "\t%s => %.4f\n", $f, $font_scale{$f};
    }
}
print '-'x60, "\n";


#添加PDF文档信息
my $meta_title = $title;
my $meta_author = $author;
my $meta_creator = $logo_text;
my $meta_producer = $software.$version.'，兀雨古籍刻本直排电子书制作工具';

$vpdf->title($meta_title);
$vpdf->author($meta_author);
$vpdf->creator($meta_creator);
$vpdf->producer($meta_producer);
$vpdf->created(strftime("%Y%m%d", localtime));
$vpdf->mediabox($canvas_width, $canvas_height);

#添加封面，封面图片cover.jpg不存在时添加简易封面
if(-f "books/$book_id/cover.jpg") {
    print "发现封面图片'$book_id/boos/$book_id/cover.jpg ...\n";
    my $cpimg = $vpdf->image("books/$book_id/cover.jpg");
    $vpage->object($cpimg);
} else {
    print "未发现封面文件'$book_id/boos/$book_id/cover.jpg，创建简易封面...\n";
    my $pline = $vpage->gfx();
    my $plx = $canvas_width/2;
    $plx = $canvas_width if($canvas_width < $canvas_height);
    #封面底色
    $pline->move(0,0);
    $pline->fillcolor('#f2ead9');
    $pline->rect(0, 0, $plx, $canvas_height);
    $pline->fill();
    #封面中间细竖线
    $pline->move($plx-50, $canvas_height);
    $pline->linewidth(2);
    $pline->strokecolor('#f2f2f2');
    $pline->line($plx-50, $canvas_height, $plx-50, 0);
    $pline->stroke();
    $pline->move($plx+50, $canvas_height);
    $pline->line($plx+50, $canvas_height, $plx+50, 0);
    $pline->stroke();
    #封面中间细横线
    foreach my $lid (0..$canvas_height/200) {
        $pline->move($plx-50, $canvas_height-200*$lid);
        $pline->line($plx-50, $canvas_height-200*$lid, $plx+50, $canvas_height-200*$lid);
        $pline->stroke();
    }
    #封面中间粗竖线
    $pline->linewidth(20);
    $pline->strokecolor('#f2f2f2');
    $pline->move($plx, $canvas_height);
    $pline->line($plx, $canvas_height, $plx, 0);
    $pline->stroke();
    #封面标题文字
    foreach my $i (0..$#tchars) {
        my $fs = $cover_title_font_size;
        my $fn = get_font($tchars[$i], \@tfns);
            $fs *= $font_scale{$fn} if $if_font_metric_adjust;
        my ($fx, $fy) = ($fs*1.5, $canvas_height-$cover_title_y-$fs*$i*1.2);
        $vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tchars[$i], -color => $cover_font_color);
    }
    #封面作者文字
    foreach my $i (0..$#achars) {
        my $fs = $cover_author_font_size;
        my $fn = get_font($achars[$i], \@tfns);
            $fs *= $font_scale{$fn} if $if_font_metric_adjust;
        my ($fx, $fy) = ($fs*1.2, $canvas_height-$cover_author_y-$fs*$i*1.2);
        $vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $achars[$i], -color => $cover_font_color);
    }
    #封面书房名称
    my ($ltx, $lty, $ltfs) = ($plx-300, 60, 30);
    $vpage->text->textlabel($ltx, $lty, $vfonts{$fn1}, $ltfs, $logo_text, -color => $cover_font_color);
}

#依次处理每个文本，逐字打印到PDF页面
my %outlines; #自动建立目录
my @fpages; #各文本首页PDF文件页码数组
my ($pid, $pcnt) = (0, 0); #非常重要：$pcnt，每页写入文字的当前标准字位指针

foreach my $tid ($from..$to) {
    last if(defined $opts{'z'} and $pid == $opts{'z'}); #达到测试页数退出
    print "读取'books/$book_id/text/'目录下第 $tid "."个文本文件...\n";
    #正文标注标识：字体缩放，书名号，方框，圆框，圈注，点注
    my ($flag_ztag, $flag_btag, $flag_rtag, $flag_ctag, $flag_otag, $flag_ptag, $flag_ltag) = (0, 0, 0, 0, 0, 0, 0);
    #批注标注标识：书名号，方框，圆框
    my ($rflag_btag, $rflag_rtag, $rflag_ctag) = (0, 0, 0);
    my $dat = $dats[$tid]; #文本字符内容
    my @chars = split //, $dat; #文本字符数组
    my $chars_num = $#chars+1; #需要处理的总字符数
    my @rchars = (); #保存标注文本字符；因标注文本可能跨页，故设置为全局变量，创建新页后优先处理上页遗留的标注文字
    my (@tpchars, @last, $tptitle, $tcnt, $last_char, $tbcnt, $rbcnt); #标题字符数组，上一个字符坐标，标题，正文圆角框字符计数器，上一个字符（用于圆角框补齐）

    if(defined $title_postfix) {
        my $cid = ($if_text000 == 1) ? $tid-1 : $tid;
        my $tpost = $title_postfix;
        $tpost =~ s/X/$zhnums{$cid}/; #替换为卷章回数字
        $tpost = '序' if($cid == 0);	
        $tpost = '附' if($if_text999 == 1 and $tid == $#dats);		
        @tpchars = split //, $title.$tpost;
    } else {
        @tpchars = split //, $title;
    }
    $tptitle = join '', @tpchars;

    if($tptitle) {
        $outlines{$tptitle} = $pid+2 if(not $outlines{$tptitle}); #添加到自动目录
    }
    print "创建新PDF页[$pid]...\n";
    $vpage = $vpdf->page();
    $vpage->object($vpimg, 0, 0); #添加刻本背景图
    #print "$tid first page: ", $pid+2, "\n";
    push @fpages, $pid+2; #每文本首页PDF页码

    foreach my $i (0..$#tpchars) {
        my $fs = $title_font_size;
        my $fn = get_font($tpchars[$i], \@tfns);
            $fs *= $font_scale{$fn} if $if_font_metric_adjust;
        my ($fx, $fy) = ($canvas_width/2-$fs/2, $title_y-$fs*$i*$title_ydis);
        $vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tpchars[$i], -color => $title_font_color) if($lc_width > 0);
    }
    #标注文本采用双排后，每页、每列文字数是变化的，页数、列数不能提前确定，需逐个字符处理，直至全部字符处理完，期间指针到达整页时创新新页
    while(1) {
        last if(defined $opts{'z'} and $pid == $opts{'z'}); #达到测试页数退出
        #非常重要：核心跳转机制
        RCHARS:
        if($pcnt == $page_chars_num or (not scalar @chars and not scalar @rchars)) { #满整页或所有字符处理完时，打印当前页，创建新页，初始化相关全局变量
            $pid++;
            $pcnt = 0;
            #打印版心页码
            my @pchars_zh = split //, $zhnums{$pid};
            foreach my $i (0..$#pchars_zh) {
            	my $px = $canvas_width/2-$pager_font_size/2;
            	my $py = $pager_y - $pager_font_size*$i*1.1;
            	my $pc = $pchars_zh[$i];
            	$vpage->text->textlabel($px, $py, $vfonts{$fn1}, $pager_font_size, $pc, -color => $pager_font_color);
            }
            last if(not scalar @chars and not scalar @rchars); #所有字符（包括批注字符数组）处理完时退出While循环
            print "创建新PDF页[$pid]...\n";
            $vpage = $vpdf->page(); #新页
            $vpage->object($vpimg, 0, 0); #添加刻本背景图
            #打印版心标题
            foreach my $i (0..$#tpchars) {
                my $fs = $title_font_size;
                my $fn = get_font($tpchars[$i], \@tfns);
                $fs *= $font_scale{$fn} if $if_font_metric_adjust;
                my ($fx, $fy) = ($canvas_width/2-$fs/2, $title_y-$fs*$i*$title_ydis);
                $vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tpchars[$i], -color => $title_font_color) if($lc_width > 0);
            }
        }
        #优先处理【】标注文本页内跨列、跨页的情况
        if(scalar @rchars) { #BUG记录：标注文本最后一个字符未处理
            my $cnt;
            my @r_pos; #存储标注双排打印对应的坐标
            #每次跳转重新计算标注文字双排占用的标准字位长度，向上取整
            my $rctmp = join '', @rchars;
            $rctmp =~ s/$comment_comma_nop_tmp//g if($comment_comma_nop_tmp); #去除批注中不占字符位置的标点
            my @rcstmp = split //, $rctmp;
            if(($#rcstmp+1) % 2 ==0) {
                $cnt = int(($#rcstmp+1)/2);
            } else {
                $cnt = int(($#rcstmp+1)/2)+1;
            }
            my $pcol;
            if($pcnt+1 % $row_num == 0) { #+1，否则挂死，原因待定
                $pcol = $pcnt/$row_num;
            } else {
                $pcol = int($pcnt/$row_num)+1;
            }
            #是否跨列
            if($pcnt+$cnt <= $pcol*$row_num) {
                @r_pos = (@pos_r[$pcnt+1..$pcnt+$cnt], @pos_l[$pcnt+1..$pcnt+$cnt]);
            } else {
                @r_pos = (@pos_r[$pcnt+1..$pcol*$row_num], @pos_l[$pcnt+1..$pcol*$row_num]);
            }
            #在对应位置打印标注文本字符
            my $rpref; #当前字符使用的坐标数组
            my @rlast; #上个字符位置
            my $rtcnt = 0; #圆角方框内字符计数
            while(my $rc = shift @rchars) {
                #批注文字支持下面的特殊符号
                if($if_tagbl and $rc eq '《') { $rflag_btag = 1; next; } #左侧书名号
                if($if_tagbl and $rc eq '》') { $rflag_btag = 0; $rbcnt = 0; next; }
                if($if_tagrf and $rc eq '〔') { $rflag_rtag = 1; next; } #圆角方框
                if($if_tagrf and $rc eq '〕') { $rflag_rtag = 0; $rtcnt = 0; next; }
                if($if_tagcf and $rc eq '〈') { $rflag_ctag = 1; next; } #圆形框
                if($if_tagcf and $rc eq '〉') { $rflag_ctag = 0; next; }

                my $fn = get_font($rc, \@cfns);
                if(not $fn) { $rc = '□'; $fn = get_font($rc, \@cfns); } #字体数组内字体不支持时
                my ($fsize, $fcolor, $fdgrees) = ($fonts{$fn}->[1], $comment_font_color, $fonts{$fn}->[2]); #批注文字大小、颜色、旋转角度参数
                $fsize *= $font_scale{$fn} if $if_font_metric_adjust;
                my ($fx, $fy); #批注文字坐标

                print "\t[$pid/$pcnt] $rc -> $fn\n" if(defined $opts{'v'});
                if($comment_comma_nop =~ m/$rc/) { #不占字符位标点
                    ($fx, $fy) = @rlast; #获取上一个字符坐标
                    $fsize = $fsize*$comment_comma_nop_size;
                    $fx+= $cw/2*$comment_comma_nop_x;
                    $fy-= $rh*$comment_comma_nop_y;
                    if($fy-$margins_bottom < 10) { $fy = $margins_bottom+2; } #列末y坐标微调，批注列末$pcnt无规律
                } else {
                    $rpref = shift @r_pos; #当前字符使用的坐标数组
                    if(not $rpref) { unshift @rchars, $rc;  goto RCHARS; } #非常重要：如果位置数组为空，将字符重新重新放回并跳转建立新页
                    ($fx, $fy) = @$rpref;
                    #@rlast = @$rpref;
                    $fx+= ($cw-$fsize*2)/4; #左右居中
                    $fy+= ($rh-$fsize)/4; #上下居中
                    if($comment_comma_90 =~ m/$rc/) { #旋转90度的标点
                        $fdgrees = -90;
                        $fsize = $fsize*$comment_comma_90_size;
                        $fx+= $cw/2*$comment_comma_90_x;
                        $fy+= $rh*$comment_comma_90_y;
                    }
                    $pcnt+=0.5; #批注占半个字符位
                }
                $fcolor = 'blue' if(defined $opts{'z'} and $fn ne $cfns[0]);
                if($rflag_btag == 1 and $rc ne ' ') { #书名左侧边线
                    $rbcnt++;
                    my $ty = $fy+$rh*0.8;
                    my $by = $fy-$rh*0.2;
                    $ty = $canvas_height-$margins_top-5 if($ty >= $canvas_height-$margins_top);
                    $ty-= $rh*0.25 if($rbcnt == 1);
                    $by = $margins_bottom+2 if($by <= $margins_bottom);
                    #draw_line($fx, $by, $fx, $ty, $bline_w, $bline_c);
                    draw_wavy_line($fx, $by, $fx, $ty, $bline_w, $bline_c);
                }
                if($rflag_rtag == 1 and $rc ne ' ') { #圆角方框
                    $rtcnt++; #正文圆角方框内文字计数器
                    my $r = 5; #顶点圆角半径
                    my ($x, $y, $h) = ($fx+$r, $fy-$fsize*$comm_rty, $fsize*(1+$comm_rth));
                    if($y <= $margins_bottom+10) { $y = $fy-6; $h-= 6; }
                    if($y+$h >= $canvas_height-$margins_top-5) { $h-= 8; }
                    if($rect_type == 0) { #单字符，带外边框
                        draw_rect0($x-2, $y-2, $fsize-2*$r+4, $h+4, $r, $rect_bcolor);
                        draw_rect0($x-1, $y-1, $fsize-2*$r+2, $h+2, $r, 'white');
                        draw_rect0($x+1, $y+1, $fsize-2*$r-2, $h-2, $r, $rect_bcolor);
                    }
                    if($rect_type == 1) { #不带外边框，支持多字符连续
                        draw_rect1($x, $y, $fsize-2*$r, $h, $r, 'comm', $rtcnt, $last_char, $rlast[1], $rect_bcolor);
                    }
                    $fcolor = $rect_fcolor;	
                }
                if($rflag_ctag == 1 and $rc ne ' ') { #圆形框
                    my ($cx, $cy, $cr) = ($fx+$fsize/2, $fy+$fsize/2+$fsize*$comm_cy, $fsize/2*$comm_cr+1);
                    if($circle_type == 0) { #带外边框
                        draw_circle1($cx, $cy, $cr+3, $circle_bcolor);
                        draw_circle1($cx, $cy, $cr+1, 'white');
                        draw_circle1($cx, $cy, $cr, $circle_bcolor);
                    }
                    if($circle_type == 1) { #不带外边框
                        draw_circle1($cx, $cy, $cr, $circle_bcolor);
                    }
                    $fcolor = $circle_fcolor;
                    $fx+= $fsize*(1-$comm_cf)/2; #圆心x坐标
                    $fy+= $fsize*(1-$comm_cf)/2; #圆心y坐标
                    $fsize = $fsize*$comm_cf; #圆框内文字大小微调
                }
                if($rc =~ m/[a-z]/i or $rc =~ m/ā|á|ǎ|à|ō|ó|ǒ|ò|ē|é|ě|è|ī|í|ǐ|ì|ū|ú|ǔ|ù|ǖ|ǘ|ǚ|ǜ|ü/) {
                    $fx+= $fsize/4;
                    $fy+= $fsize/2;
                    $fdgrees = -90;
                }
                if ($if_fallback_bold && $fn ne $tfns[0]) {
                    $vpage->gfx()->linewidth($fallback_bold_stroke_width);
                    $vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $rc, -rotate => $fdgrees, -color => $fcolor, -render => 2, -strokecolor => $fcolor);
                } else {
                    $vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $rc, -rotate => $fdgrees, -color => $fcolor);
                }
                @rlast = @$rpref;
                $last_char = $rc;
            }
            #print $pcnt, "\n"; #有效断点
            if($#rchars > 0) { goto RCHARS; } #若标注文本有遗留，说明发生跨页或页内跨列，跳转直至本次标注文本处理完
            $pcnt = int($pcnt+0.5); #指针前进
            if($pcnt == $page_chars_num) { goto RCHARS; } #如果此时到达页尾跳转写入图片并新建
        }
        #正文文字打印
        if(not scalar @chars) { goto RCHARS; }
        my $char = shift @chars;
        #特殊符号标识
    	if($char eq '$') { #前进半页或整页
    		shift @chars for(1..$row_num-1); #跳过$后补齐列高的空格
    		next if($pcnt == 0 or $pcnt == $page_chars_num/2);
    		if($pcnt < $page_chars_num/2) {
    			$pcnt = $page_chars_num/2; next;
    		} else {
    			$pcnt = $page_chars_num; next;
    		}
    	}
        if($char eq '%') { #分页符
            shift @chars for (1..$row_num-1); #跳过%后补齐列高的空格
            if($pcnt > 1) {
                $pcnt = $page_chars_num; goto RCHARS;
            } else {
                $pcnt = 0; next;
            }
        }
        if($char eq '&') { #跳至页最后一列
            shift @chars for (1..$row_num-1); #跳过&后补齐列高的空格
            if($pcnt <= $page_chars_num-$row_num+1) {
                $pcnt = $page_chars_num-$row_num; goto RCHARS;
            }
        }
        if($if_tagbl and $char eq '《') { $flag_btag = 1; next; } #书名号左侧线
        if($if_tagbl and $char eq '》') { $flag_btag = 0; $tbcnt = 0; next; }
        if($if_tagrf and $char eq '〔') { $flag_rtag = 1; next; } #圆角方框
        if($if_tagrf and $char eq '〕') { $flag_rtag = 0; $tcnt = 0; next; }
        if($if_tagtz and $char eq '（') { $flag_ztag = 1; next; } #正文文字大小调整
        if($if_tagtz and $char eq '）') { $flag_ztag = 0; next; }
        if($if_tagcf and $char eq '〈') { $flag_ctag = 1; next; } #圆形框
        if($if_tagcf and $char eq '〉') { $flag_ctag = 0; next; }
        if($if_tagcn and $char eq '｛') { $flag_otag = 1; next; } #正文文字右侧圈注
        if($if_tagcn and $char eq '｝') { $flag_otag = 0; next; }
        if($if_tagpn and $char eq '＜') { $flag_ptag = 1; next; } #正文文字右侧点注
        if($if_tagpn and $char eq '＞') { $flag_ptag = 0; next; }
        if($if_tagln and $char eq '［') { $flag_ltag = 1; next; } #正文文字右侧线注
        if($if_tagln and $char eq '］') { $flag_ltag = 0; next; }
        #注意：原始文本中的标注文本需严格使用【】区别
        if($char eq '【') {
            my $rdat;
            while(my $rchar = shift @chars) {
                last if($rchar eq '】' );
                $rdat.= $rchar;
            }
            @rchars = split //, $rdat if($rdat); #更新全局标注文本变量
            goto RCHARS; #处理标注文字
        } else { #正文文字处理
            $pcnt++ if($pcnt < $page_chars_num); #如果未达到页尾，指针前进，到达即停止
            if($pcnt <= $page_chars_num) {
                my $fn = get_font($char, \@tfns);
                if(not $fn) { $char = '□'; $fn = get_font($char, \@tfns); }
                my ($fsize, $fcolor, $fdgrees)  = ($fonts{$fn}->[0], $text_font_color, $fonts{$fn}->[2]);
                $fsize *= $font_scale{$fn} if $if_font_metric_adjust;
                my ($fx, $fy) = @{$pos_l[$pcnt]};

                print "[$pid/$pcnt] $char -> $fn\n" if(defined $opts{'v'});
                if($char eq 'T') {
                    my $grect = $vpage->gfx();
                    #canvas绘制背景图时，边距、线宽参数通常为整数，但计算列宽后可能为小数，为确保首尾两列进一字时绘制边框对齐，需对坐标进行取整微调，但背景图配置文件变化时可能需要更新
                    #采用填充覆盖法绘制边框更易实现对齐
                    #外粗线框延伸
                    $grect->move($fx, $fy);
                    $grect->fillcolor('black');
                    $grect->rect($fx-$ohm-$olw, $fy+$rh+$ovm*2, int($cw+$ohm*2+$olw*2)+1, $rh+$ovm*2);
                    $grect->fill();
                    $grect->fillcolor('white');
                    $grect->rect(int($fx-$ohm+1), $fy+$rh, int($cw+$ohm*2+0.5), $rh+$ovm*2); #覆盖下边
                    $grect->fill();
                    #内细线框延伸
                    $grect->fillcolor('black');
                    $grect->rect($fx, $fy+$rh+$ovm-$olw, int($cw)+1, $rh+$ovm*2);
                    $grect->fill();
                    $grect->fillcolor('white');
                    $grect->rect($fx+$ilw, $fy+$rh+$ovm-$olw-$ilw, int($cw-$ilw*2)+1, $rh+$ovm*2); #覆盖下边
                    $grect->fill();
                    #打印前进一格的字符
                    $char = shift @chars;
                    $fn = get_font($char, \@tfns);
                    ($fsize, $fcolor, $fdgrees)  = ($fonts{$fn}->[0], $text_font_color, $fonts{$fn}->[2]);
                    $fy+= $rh;
                    $fx+= ($cw-$fsize)/2;
                    $vpage->text()->textlabel($fx, $fy+$ovm, $vfonts{$fn}, $fsize, $char, -rotate => $fdgrees, -color => $fcolor);
                    $pcnt--;
                    next;
                }
                if($text_comma_nop =~ m/$char/) { #不占字符位标点
                    $pcnt--;
                    $fsize = $fsize*$text_comma_nop_size;
                    ($fx, $fy) = @last; #上个字符位置
                    $fx+= $cw*$text_comma_nop_x;
                    $fy-= $rh*$text_comma_nop_y;
                    if($fy-$margins_bottom < 10) {
                        $fy = $margins_bottom+5;
                        $fy+= $fsize/2 if($char =~ m/…|—/);
                    }
                    if($text_comma_90 =~ m/$char/) {
                        $fdgrees = -90;
                    }
                } else {
                    if($text_comma_90 =~ m/$char/) { #旋转90度标点
                        $fsize = $fsize*$text_comma_90_size;
                        $fx+= $cw*$text_comma_90_x;
                        $fy+= $rh*$text_comma_90_y;
                        $fdgrees = -90;
                    } else {
                        $fx+= ($cw-$fsize)/2;
                    }
                    @last = @{$pos_l[$pcnt]};
                }
                $fcolor = 'blue' if(defined $opts{'z'} and $fn ne $tfns[0]);
                #print "$char -> $fn\n";
                if($flag_ztag == 1) { #正文文字大小调整
                    $fx+= $fsize*(1-$text_zoom)/2; #因文字大小调整，更新文字x坐标
                    $fsize = $fsize*$text_zoom;
                }
                if($flag_otag == 1 and $char ne ' ') { #正文文字右侧圈注
                    my ($ox, $oy, $or, $ow, $oc) =
                        ($fx+$cw/2+$fsize*$text_note_ox, $fy+$fsize*$text_note_oy, $fsize*$text_note_or, $text_note_ow, $text_note_oc);
                    draw_circle0($ox, $oy, $or, $ow, $oc);
                }
                if($flag_ptag == 1 and $char ne ' ') { #正文文字右侧点注
                    my $fchar = '、';
                    my $ffn = get_font($fchar, \@tfns);
                    my ($px, $py, $ps, $pc) = ($fx+$cw/2+$fsize*$text_note_px, $fy+$fsize*$text_note_py, $fsize*$text_note_ps, $text_note_pc);
                    $vpage->text()->textlabel($px, $py, $vfonts{$ffn}, $ps, $fchar, -color => $pc);
                }
                if($flag_ltag == 1 and $char ne ' ') { #正文文字右侧线注
                    my ($ty, $by) = ($fy+$rh*(1+$text_note_ly), $fy+$rh*$text_note_ly); #线段上、下端点y坐标
                    my $lx = $fx+$cw/2+$fsize*$text_note_lx; #线段x坐标
                    $ty = $canvas_height-$margins_top-5 if($pcnt % $row_num == 1); #列首微调
                    $by = $margins_bottom+4 if($pcnt % $row_num == 0); #列末微调
                    draw_line($lx, $by, $lx, $ty, $text_note_lw, $text_note_lc);
                }
                if($flag_btag == 1 and $char ne ' ') { #书名左侧边线
                    $tbcnt++;
                    my ($ty, $by) = ($fy+$rh*0.8, $fy-$rh*0.2); #线段上、下端点y坐标
                    $ty = $canvas_height-$margins_top-5 if($pcnt % $row_num == 1); #列首微调
                    $ty-= 5 if($tbcnt == 1);
                    $by = $margins_bottom+4 if($pcnt % $row_num == 0); #列末微调
                    #draw_line($fx-2, $by, $fx-2, $ty, $bline_w, $bline_c);
                    draw_wavy_line($fx-2, $by, $fx-2, $ty, $bline_w+1, $bline_c);
                }
                if($flag_rtag == 1 and $char ne ' ') { #圆角方框
                    $tcnt++; #正文圆角方框内文字计数器
                    my $r = 10; #顶点圆角半径
                    my $tfs = $fs1_text;
                    my ($x, $y, $h) = ($fx+$r, $fy-$rh*$text_rty, $tfs*(1+$text_rth));
                    if($pcnt % $row_num == 0) { $y = $fy+2; $h-= 4; } #列末微调
                    if($pcnt % $row_num == 1) { $h-= 4; } #列首微调
                    #if($tcnt == 1) { $h+=15; } #56

                    if($rect_type == 0) { #带外边框，单字时使用
                        draw_rect0($x-2, $y-2, $fsize-2*$r+4, $h+4, $r, $rect_bcolor);
                        draw_rect0($x-1, $y-1, $fsize-2*$r+2, $h+2, $r, 'white');
                        draw_rect0($x+1, $y+1, $fsize-2*$r-2, $h-2, $r, $rect_bcolor);
                    }
                    if($rect_type == 1) { #不带外边框，支持多字符连续
                        draw_rect1($x, $y, $fsize-2*$r, $h, $r, 'text', $tcnt, $last_char, $last[1], $rect_bcolor);
                    }
                    $fcolor = $rect_fcolor;
                }
                if($flag_ctag == 1 and $char ne ' ') { #圆形框
                    my ($cx, $cy, $cr) = ($fx+$fsize/2, $fy+$fsize/2+$fsize*$text_cy, $fsize/2*$text_cr+1);
                    if($circle_type == 0) { #带外边框
                        draw_circle1($cx, $cy, $cr+4, $circle_bcolor);
                        draw_circle1($cx, $cy, $cr+2, 'white');
                        draw_circle1($cx, $cy, $cr, $circle_bcolor);
                    }
                    if($circle_type == 1) { #不带外边框
                        draw_circle1($cx, $cy, $cr, $circle_bcolor);
                    }
                    $fcolor = $circle_fcolor;
                    $fx+= $fsize*(1-$text_cf)/2; #圆心x坐标
                    $fy+= $fsize*(1-$text_cf)/2; #圆心y坐标
                    $fsize = $fsize*$text_cf; #圆内文字大小微调
                }
                if($char =~ m/[a-z]/i or $char =~ m/ā|á|ǎ|à|ō|ó|ǒ|ò|ē|é|ě|è|ī|í|ǐ|ì|ū|ú|ǔ|ù|ǖ|ǘ|ǚ|ǜ|ü/) {
                    $fdgrees = -90;
                    $fx+= $fsize/4;
                    $fy+= $fsize/2;
                }
                if ($if_fallback_bold && $fn ne $tfns[0]) {
                    $vpage->gfx()->linewidth($fallback_bold_stroke_width);
                    $vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $char, -rotate => $fdgrees, -color => $fcolor, -render => 2, -strokecolor => $fcolor);
                } else {
                    $vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $char, -rotate => $fdgrees, -color => $fcolor);
                }
                if($pcnt == $page_chars_num) {
                    if(scalar @chars) {
                        my $next_char = shift @chars; #达到页尾后，提前获取下一个字符，看是否非占位标点，若是则先打印再跳转建新页，不是再放入数组
                        #unshift @chars, $next_char and next if($next_char =~ m /《|〔|（|〈|{||＜|］/);
                        if($if_tagbl and $next_char eq '《') { unshift @chars, $next_char and next; }
                        if($if_tagbl and $next_char eq '》') { $flag_btag = 0; $tbcnt = 0; next; } #书名号
                        if($if_tagrf and $next_char eq '〔') { unshift @chars, $next_char and next; }
                        if($if_tagrf and $next_char eq '〕') { $flag_rtag = 0; $tcnt = 0; next; } #圆角方框
                        if($if_tagcf and $next_char eq '（') { unshift @chars, $next_char and next; }
                        if($if_tagtz and $next_char eq '）') { $flag_ztag = 0; next; } #正文字体缩放
                        if($if_tagcf and $next_char eq '〈') { unshift @chars, $next_char and next; }
                        if($if_tagcf and $next_char eq '〉') { $flag_ctag = 0; next; } #圆框
                        if($if_tagcn and $next_char eq '｛') { unshift @chars, $next_char and next; }
                        if($if_tagcn and $next_char eq '｝') { $flag_otag = 0; next; } #圈注
                        if($if_tagpn and $next_char eq '＜') { unshift @chars, $next_char and next; }
                        if($if_tagpn and $next_char eq '＞') { $flag_ptag = 0; next; } #点注
                        if($if_tagln and $next_char eq '［') { unshift @chars, $next_char and next; }
                        if($if_tagln and $next_char eq '］') { $flag_ltag = 0; next; } #线注
                        if($text_comma_nop =~ m/$next_char/) {
                            ($fx, $fy) = @{$pos_l[$pcnt]};
                            $fsize = $fsize*$text_comma_nop_size;
                            $fx+= $cw*$text_comma_nop_x;
                            $fy-= $rh*$text_comma_nop_y;
                            if($fy-$margins_bottom < 10) {
                                $fy = $margins_bottom+5;
                                $fy+= $fsize/2 if($char =~ m/…|—/);
                            } #列末y坐标微调
                            $vpage->text->textlabel($fx, $fy, $vfonts{$fn1}, $fsize, $next_char, -rotate => $fdgrees, -color => $fcolor);
                        } else {
                            unshift @chars, $next_char; #占位字符放回字符串数组头部，放到新页
                        }
                    }
                }
            }
            $last_char = $char;
        }
        last if(defined $opts{'z'} and $pid == $opts{'z'}); #达到测试页数退出
    }#while
}

if($title_directory == 1) {
    my %outlines_tmp;
    foreach my $ok (keys %outlines) {
    	$outlines_tmp{$outlines{$ok}} = $ok;
    }

    my $otlines = $vpdf->outline();
    foreach my $otpid (sort {$a<=>$b} keys %outlines_tmp) {
    	my $item = $otlines->outline();
    	my $ottitle = $outlines_tmp{$otpid};
    	print "\t$ottitle -> $otpid\n";
    	$item->title($ottitle);
    	$item->dest($vpdf->open_page($otpid)); #目录
    }
}

my $pdfn = "《$title》文本$from"."至$to";

$pdfn = $pdfn.'_test' if($opts{'z'});
print "生成PDF文件'books/$book_id/$pdfn.pdf'...";
$vpdf->save("books/$book_id/$pdfn.pdf");
print "完成！\n";

if(defined $opts{'c'}) {
    my $input = "books/$book_id/$pdfn.pdf";
    my $output = "books/$book_id/$pdfn".'_已压缩.pdf';

    if($^O =~ m/darwin/i) {
        print "压缩PDF文件'$output'...";
        #使用ghostscript指令压缩PDF文件
        `gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$output $input`;
        `rm $input`;
        print "完成！\n";
    }

    my $fptmp = $pdfn.'_已压缩.tmp';
    open FPTMP, "> books/$book_id/$fptmp";
    print FPTMP join '|', @fpages;
    close(FPTMP);
} else {
    print "建议：使用'-c'参数对PDF文件进行压缩！\n"
}

# print_welcome — 打印欢迎信息
sub print_welcome {
    print '-'x60, "\n";
    print "\t$software $version"."，兀雨古籍刻本电子书制作工具\n";
    print "\t\tGitHub\@shanleiguang，小红书\@兀雨书屋，2025\n";
    print '-'x60, "\n";
}

# print_help — 打印命令行帮助信息
sub print_help {
    print <<END
   ./$software\t$version，兀雨古籍刻本直排电子书制作工具
    -h\t帮助信息
    -v\t显示更多信息
    -c\t压缩PDF（MacOS）
    -z\t测试模式，仅输出指定页数，生成带test标识的PDF文件，用于调试参数
    -b\t书籍ID
      \t书籍文本需保存在书籍ID的text目录下，多文本时采用001、002...不间断命名以确保顺序处理
    -f\t书籍文本的起始序号，注意不是文件名的数字编号，而是顺序排列的序号
    -t\t书籍文本的结束序号，注意不是文件名的数字编号，而是顺序排列的序号
        作者：GitHub\@shanleiguang，小红书\@兀雨书屋，2025
END
}

# ============================================================================
# 绘图工具函数
# ============================================================================

# draw_line — 绘制直线（用于书名号左侧线、右侧线注）
#   参数：起点xy, 终点xy, 线宽, 颜色
sub draw_line {
    my ($fx, $fy, $tx, $ty, $lw, $lc) = @_;
    my $gline = $vpage->gfx();
    $gline->linewidth($lw);
    $gline->strokecolor($lc);
    $gline->move($fx, $fy);
    $gline->line($fx, $fy, $tx, $ty);
    $gline->stroke();
}

# draw_circle0 — 绘制描边圆形（用于圈注、圆形框边框）
#   参数：圆心xy, 半径, 线宽, 线颜色
sub draw_circle0 { #圆框
    my ($x, $y, $r, $w, $c) = @_; #圆形坐标，半径，线宽，线颜色
    my $gcircle = $vpage->gfx();
    $gcircle->strokecolor($c);
    $gcircle->linewidth($w);
    $gcircle->move($x, $y);
    $gcircle->circle($x, $y, $r);
    $gcircle->stroke();
}

# draw_circle1 — 绘制填充圆形（用于圆形框底色）
#   参数：圆心xy, 半径, 填充色
sub draw_circle1 { #填充圆形
    my ($x, $y, $r, $c) = @_; #圆形坐标，半径，填充色
    my $gcircle = $vpage->gfx();
    $gcircle->fillcolor($c);
    $gcircle->move($x, $y);
    $gcircle->circle($x, $y, $r);
    $gcircle->fill();
}

#圆角方框，顶点四个圆+内外两个矩形叠加
# 〇=====〇
# ||    ||
# ||    ||
# 〇=====〇
# draw_rect0 — 绘制带边框圆角方框（顶点四圆+内外矩形叠加，适用单字符）
#   参数：左下xy, 宽, 高, 顶点圆半径, 填充色
sub draw_rect0 { #用于嵌套生成带边框圆角方框，适用单个字符
    my ($x, $y, $w, $h, $r, $c) = @_; #左下顶点坐标，长，高，顶点圆半径，填充色
    my $grect = $vpage->gfx();
    $grect->fillcolor($c);
    $grect->move($x, $y);
    $grect->circle($x, $y, $r);
    $grect->circle($x+$w, $y, $r);
    $grect->circle($x, $y+$h, $r);
    $grect->circle($x+$w, $y+$h, $r);
    $grect->rect($x-$r, $y, $w+2*$r, $h);
    $grect->rect($x, $y-$r, $w, $h+2*$r);
    $grect->fill();
}

# draw_rect1 — 绘制不带边框圆角方框（支持多字符连续，自动补齐字符间连接）
#   参数：左下xy, 宽, 高, 顶点圆角半径, text/comm, 框内字符计数, 上字符, 上字符y, 填充色
sub draw_rect1 { #不带边框的圆角方框，支持多字符连续
    #左下顶点坐标，长，高，顶点圆角半径，正文还是批注，圆角框内字符计数器，上一个字符，上个字符y轴，填充色
    my ($x, $y, $w, $h, $r, $t, $n, $l, $ly, $c) = @_;
    my $grect = $vpage->gfx();
    $grect->fillcolor($c);
    $grect->move($x, $y);
    $grect->circle($x, $y, $r);
    $grect->circle($x+$w, $y, $r);
    $grect->circle($x, $y+$h, $r);
    $grect->circle($x+$w, $y+$h, $r);
    $grect->rect($x-$r, $y, $w+2*$r, $h);
    $grect->rect($x, $y-$r, $w, $h+2*$r);
    if($y < $canvas_height-$margins_top-$rh) { #不是列首（正文或批注），由于批注$pcnt不确定，采用字符y坐标判断
        if($n > 1 and $l ne ' ') { #不是框首字符、上一个字符不是空格且不换列时，添加与上个字符圆角框的连接补齐
            #print "$y, $ly\n";
            my $cnth = ($t eq 'text') ? $r*$text_rtr : $r*$comm_rtr;
            if($t eq 'commn' and $y < $ly-$row_delta_y) {
                $grect->rect($x-$r, $y+$h, $w+2*$r, $cnth); #长条
                $grect->rect($x-$r, $y+$h, $r, 2*$r); #长条两端添加圆角半径的小正方形，实现连接
                $grect->rect($x+$w, $y+$h, $r, 2*$r); #长条两端添加圆角半径的小正方形，实现连接
            }
            if($t eq 'text') {
                $grect->rect($x-$r, $y+$h, $w+2*$r, $cnth); #长条
                $grect->rect($x-$r, $y+$h, $r, 2*$r); #长条两端添加圆角半径的小正方形，实现连接
                $grect->rect($x+$w, $y+$h, $r, 2*$r); #长条两端添加圆角半径的小正方形，实现连接				
            }
        }
    }
    $grect->fill();	
}

# draw_wavy_line — 绘制书名号波浪线
#   参数：起点xy, 终点xy, 线宽, 颜色
sub draw_wavy_line { #书名号波浪线
    my ($x1, $y1, $x2, $y2, $w, $c) = @_;
    my $gfx = $vpage->gfx();

    # 默认参数
    my $amplitude = 1.25;
    my $wavelength = 10;
    my $color = $c || 'black';
    my $width = $w || 1;
    
    # 计算线的长度和角度
    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;
    my $length = sqrt($dx**2 + $dy**2);
    my $angle = atan2($dy, $dx);
    
    # 计算波浪线的点
    my $segments = int($length / ($wavelength / 5));
    my @points;
    
    for my $i (0..$segments) {
        my $t = $i / $segments;
        my $distance = $t * $length;
        my $wave_offset = $amplitude * sin(2 * pi * $distance / $wavelength);
        
        # 计算垂直方向的偏移
        my $perp_x = -sin($angle) * $wave_offset;
        my $perp_y = cos($angle) * $wave_offset;
        
        my $x = $x1 + cos($angle) * $distance + $perp_x;
        my $y = $y1 + sin($angle) * $distance + $perp_y;
        
        push @points, [$x, $y];
    }
    
    # 绘制波浪线
    $gfx->move($points[0][0], $points[0][1]);
    for my $i (1..$#points) {
        $gfx->line($points[$i][0], $points[$i][1]);
    }
    $gfx->strokecolor($color);
    $gfx->linewidth($width);
    $gfx->stroke();
}

# get_pid_zh — 阿拉伯数字转中文数字（用于章回、页码显示）
#   例：10 → 十, 25 → 二十五
sub get_pid_zh {
    my $cid = shift;
    my @chars_zh = ('〇', '一', '二', '三', '四', '五', '六', '七', '八', '九');
    $cid =~ s/^0//;
    $cid =~ s/(\d)/$chars_zh[$1]/g;
    $cid =~ s/^一〇$/十/; #10
    $cid =~ s/^一([一|二|三|四|五|六|七|八|九])/十$1/; #11-19
    $cid =~ s/^([二|三|四|五|六|七|八|九])〇/$1十/; #20,30...90
    return $cid;
}

#字体度量微调：获取字体中参考字符的字形高度
# get_glyph_height — 获取字体中参考字符的字形高度（已缩放至参考尺寸）
#   若 glyph 不存在则返回 undef，交由 compute_font_scales 的 face 级回退处理
#   参数：字体文件名, 字符, 参考尺寸(pt)
sub get_glyph_height {
    my ($font_file, $char, $ref_size) = @_;
    
    my $face;
    if ($face_cache{$font_file}) {
        $face = $face_cache{$font_file};
    } else {
        my $freetype = Font::FreeType->new();
        $face = $freetype->face("fonts/$font_file");
        $face_cache{$font_file} = $face;
    }
    
    $face->set_char_size($ref_size, $ref_size, 72, 72);
    my $glyph = $face->glyph_from_char($char);
    if ($glyph) {
        my $height = $glyph->height();
        if (!$height || $height == 0) {
            my ($xmin, $ymin, $xmax, $ymax) = $glyph->outline_bbox();
            $height = $ymax - $ymin if defined $xmin;
        }
        return $height if $height && $height > 0;
    }

    return undef;
}

#字体度量微调：获取字体的 face 级高度（ascender - descender）
# get_face_height — 获取字体的 face 级高度（ascender - descender）
#   用于 compute_font_scales 中不含参考字符的字体校准估算
#   参数：字体文件名, 参考尺寸(pt)
sub get_face_height {
    my ($font_file, $ref_size) = @_;

    my $face;
    if ($face_cache{$font_file}) {
        $face = $face_cache{$font_file};
    } else {
        my $freetype = Font::FreeType->new();
        $face = $freetype->face("fonts/$font_file");
        $face_cache{$font_file} = $face;
    }

    $face->set_char_size($ref_size, $ref_size, 72, 72);
    my $h = $face->ascender() - $face->descender();
    return $h;
}

#字体度量微调：为所有字体预计算缩放因子
# compute_font_scales — 为所有字体预计算缩放因子（两阶段：glyph 级 → face 级校准回退）
#   Phase 1: 用参考字符获取各字体 glyph 高度
#   Phase 2: 对不含参考字符的字体（如 Plane02 生僻字字体），用 face 度量+校准因子估算
#   参数：主字体文件名, 参考字符, 参考尺寸(pt)
sub compute_font_scales {
    my ($primary_font, $ref_char, $ref_size) = @_;
    return unless $primary_font;

    my @all_fonts;
    push @all_fonts, $fn1 if $fn1;
    push @all_fonts, $fn2 if $fn2;
    push @all_fonts, $fn3 if $fn3;
    push @all_fonts, $fn4 if $fn4;
    push @all_fonts, $fn5 if $fn5;

    $font_scale{$primary_font} = 1.0;

    # Phase 1: 用参考字符获取各字体的 glyph 级高度
    my %heights;
    my @needs_fallback;
    my $primary_height = get_glyph_height($primary_font, $ref_char, $ref_size);
    return unless $primary_height && $primary_height > 0;
    $heights{$primary_font} = $primary_height;

    for my $font (@all_fonts) {
        next unless $font;
        next if $font eq $primary_font;
        my $h = get_glyph_height($font, $ref_char, $ref_size);
        if ($h && $h > 0) {
            $heights{$font} = $h;
        } else {
            push @needs_fallback, $font;
        }
    }

    # Phase 2: 对于不含参考字符的字体，用 face 级度量 + 校准因子估算
    if (@needs_fallback) {
        my $primary_face_h = get_face_height($primary_font, $ref_size);
        if ($primary_face_h && $primary_face_h > 0) {
            my $calibration = $primary_height / $primary_face_h;
            for my $font (@needs_fallback) {
                next unless $font;
                my $face_h = get_face_height($font, $ref_size);
                next unless $face_h && $face_h > 0;
                $heights{$font} = $face_h * $calibration;
            }
        }
    }

    # 计算缩放因子
    for my $font (@all_fonts) {
        next unless $font;
        next if $font eq $primary_font;
        next unless $heights{$font} && $heights{$font} > 0;
        $font_scale{$font} = $primary_height / $heights{$font};
    }
}


# ============================================================================
# 字体工具函数
# ============================================================================

# get_font — 多字体回退选择（按优先级数组顺序检查字符是否存在）
#   参数：字符, 字体数组引用
#   返回：首个包含该字符的字体文件名，无则返回 undef
sub get_font {
    my ($char, $fref) = @_;
    my @fonts = @$fref;
    foreach my $f (@fonts) {
        return $f if(font_check($f, $char));
    }
    return undef;
}

# font_check — 检查字符是否存在于指定字体（使用 Font::FreeType glyph 检测）
#   参数：字体文件名, 字符
sub font_check {
    my ($font, $char) = @_;
    my $freetype = Font::FreeType->new();
    my $face = $freetype->face("fonts/$font");
    my $fontglyph = $face->glyph_from_char($char);

    return 1 if($fontglyph);
    return 0;
}
