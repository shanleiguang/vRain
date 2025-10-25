#!/usr/bin/perl
#vRain中文古籍刻本风格直排电子书制作工具
#by shanleiguang@gmail.com, 2025/07
use strict;
use warnings;

use PDF::Builder;
use Font::FreeType;
use Math::Trig qw(pi);
use Encode::HanConvert;
use Getopt::Std;
use POSIX qw(strftime);
use Encode;
use utf8;

$| = 1; #autoflush

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my $software = 'vRain';
my $version = 'v1.42';

#程序输入参数设置
my %opts;

getopts('hcvz:b:f:t:', \%opts);
if(defined $opts{'h'}) { print_help(); exit; }

#读取卷、回、页码等阿拉伯数字转为特定中文，如12->十二，103->百三
my %zhnums;
open ZHNUM, '< db/num2zh_jid.txt';
while(<ZHNUM>) {
	chomp;
	$_ = decode('utf-8', $_);
	my ($a, $b) = split /\|/, $_;
	$zhnums{$a} = $b;
}
close(ZHNUM);

my $book_id = $opts{'b'};
my $from = $opts{'f'} ? $opts{'f'} : 1;
my $to = $opts{'t'} ? $opts{'t'} : 1;

if(not -d "books/$book_id") { print "错误：未发现该书籍目录'books/$book_id'！\n"; exit; }
if(not -d "books/$book_id/text" ) { print "错误: 未发现该书籍文本目录'books/$book_id/text'！\n"; exit; }
if(not -f "books/$book_id/book.cfg") { print "错误：未发现该书籍排版配置文件'books/$book_id/book.cfg'！\n"; exit; }

print_welcome();

if(defined $opts{'z'}) { print "注意：-z 测试模式，仅输出", $opts{'z'}, "页用于调试排版参数！\n"; }

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
print "\t标题：$book{'title'}\n";
print "\t作者：$book{'author'}\n";
print "\t背景：$book{'canvas_id'}\n";
print "\t每列字数：$book{'row_num'}\n";
print "\t是否无标点：$book{'if_nocomma'}\n";
print "\t标点归一化：$book{'if_onlyperiod'}\n";
close(BCONFIG);

#书籍标题、作者、背景图ID
my ($author, $title) = ($book{'author'}, $book{'title'});
my ($canvas_id, $row_num, $row_delta_y) = ($book{'canvas_id'}, $book{'row_num'}, $book{'row_delta_y'});
#字体
my ($fn1, $fn2, $fn3, $fn4, $fn5) = ($book{'font1'}, $book{'font2'}, $book{'font3'}, $book{'font4'}, $book{'font5'});
my ($fnr1, $fnr2, $fnr3, $fnr4, $fnr5) = ($book{'font1_rotate'}, $book{'font2_rotate'}, $book{'font3_rotate'}, $book{'font4_rotate'}, $book{'font5_rotate'});
my ($fs1_text, $fs2_text, $fs3_text, $fs4_text, $fs5_text) = ($book{'text_font1_size'}, $book{'text_font2_size'}, $book{'text_font3_size'}, $book{'text_font4_size'}, $book{'text_font5_size'});
my ($fs1_comm, $fs2_comm, $fs3_comm, $fs4_comm, $fs5_comm) = ($book{'comment_font1_size'}, $book{'comment_font2_size'}, $book{'comment_font3_size'}, $book{'comment_font4_size'}, $book{'comment_font5_size'});
my ($tfsarray, $cfsarray) = ($book{'text_fonts_array'}, $book{'comment_fonts_array'}); #正文及批注文字的字体数组
my $try_st = $book{'try_st'}; #是否进行简繁转换，有可能改善字体支持情况

if(not $canvas_id) { print "错误：未定义背景图ID 'canvas_id'！\n"; exit; }
if(not -f "canvas/$canvas_id.cfg") { print "错误：未发现背景图cfg配置文件！\n"; exit; }
if(not -f "canvas/$canvas_id.jpg") { print "错误：未发现背景图jpg图片文件！\n"; exit; }
if(not $fn1) { print "错误：主字体'font1'未定义！\n"; exit; }
if($fn1 and not -f "fonts/$fn1") { print "错误：未发现字体'fonts/$fn1'！\n"; exit; }
if($fn2 and not -f "fonts/$fn2") { print "错误：未发现字体'fonts/$fn2'！\n"; exit; }
if($fn3 and not -f "fonts/$fn3") { print "错误：未发现字体'fonts/$fn3'！\n"; exit; }
if($fn4 and not -f "fonts/$fn4") { print "错误：未发现字体'fonts/$fn4'！\n"; exit; }
if($fn5 and not -f "fonts/$fn5") { print "错误：未发现字体'fonts/$fn5'！\n"; exit; }

my @tchars = split //, $title;
my @achars = split //, $author;
my (@fns, @tfns, @cfns, %fonts);

if($fn1) { push @fns, $fn1; $fonts{$fn1} = [$fs1_text, $fs1_comm, $fnr1]; }
if($fn2) { push @fns, $fn2; $fonts{$fn2} = [$fs2_text, $fs2_comm, $fnr2]; }
if($fn3) { push @fns, $fn3; $fonts{$fn3} = [$fs3_text, $fs3_comm, $fnr3]; }
if($fn4) { push @fns, $fn4; $fonts{$fn4} = [$fs4_text, $fs4_comm, $fnr4]; }
if($fn5) { push @fns, $fn5; $fonts{$fn5} = [$fs5_text, $fs5_comm, $fnr5]; }

#正文字体数组
foreach my $fid (split //, $tfsarray) {
	push @tfns, $fns[$fid-1];
}
#批注字体数组
foreach my $fid (split //, $cfsarray) {
	push @cfns, $fns[$fid-1];
}

#正文、批注文字颜色
my ($text_font_color, $comment_font_color) = ($book{'text_font_color'}, $book{'comment_font_color'});
#封面标题、作者字体
my ($cover_title_font_size, $cover_title_y) = ($book{'cover_title_font_size'}, $book{'cover_title_y'});
my ($cover_author_font_size, $cover_author_y) = ($book{'cover_author_font_size'}, $book{'cover_author_y'});
my $cover_font_color = $book{'cover_font_color'};
#版心标题、页码字体
my ($if_tpcenter, $title_postfix, $title_directory) = ($book{'if_tpcenter'}, $book{'title_postfix'}, $book{'title_directory'});
my ($title_font_size, $title_font_color, $title_y, $title_ydis) = ($book{'title_font_size'}, $book{'title_font_color'}, $book{'title_y'}, $book{'title_ydis'});
my ($pager_font_size, $pager_font_color, $pager_y) = ($book{'pager_font_size'}, $book{'pager_font_color'}, $book{'pager_y'});
#书名号是否处理为侧线
my $if_book_vline = $book{'if_book_vline'};
my ($bline_w, $bline_c) = ($book{'book_line_width'}, $book{'book_line_color'});
#标点符号替代规则
my ($exp_replace_comma, $exp_replace_number) = ($book{'exp_replace_comma'}, $book{'exp_replace_number'});
#标点符号过滤规则
my $exp_delete_comma = $book{'exp_delete_comma'};
#无标点符号模式、标点符号归一化模式
my ($if_nocomma, $if_onlyperiod) = ($book{'if_nocomma'}, $book{'if_onlyperiod'});
my ($exp_nocomma, $exp_onlyperiod) = ($book{'exp_nocomma'}, $book{'exp_onlyperiod'});
my $onlyperiod_color = $book{'onlyperiod_color'}; #归一化模式下句号颜色
#正文中不占字符位的标点符号、旋转直排的标点符号
my ($text_comma_nop, $text_comma_90) = ($book{'text_comma_nop'}, $book{'text_comma_90'});
my ($text_comma_nop_size, $text_comma_nop_x, $text_comma_nop_y) = 
		($book{'text_comma_nop_size'}, $book{'text_comma_nop_x'}, $book{'text_comma_nop_y'});
my ($text_comma_90_size, $text_comma_90_x, $text_comma_90_y) =
		($book{'text_comma_90_size'}, $book{'text_comma_90_x'}, $book{'text_comma_90_y'});
#批注中不占字符位的标点符号、旋转直排的标点符号
my ($comment_comma_nop, $comment_comma_90) = ($book{'comment_comma_nop'}, $book{'comment_comma_90'});
my ($comment_comma_nop_size, $comment_comma_nop_x, $comment_comma_nop_y) = 
		($book{'comment_comma_nop_size'}, $book{'comment_comma_nop_x'}, $book{'comment_comma_nop_y'});
my ($comment_comma_90_size, $comment_comma_90_x, $comment_comma_90_y) =
		($book{'comment_comma_90_size'}, $book{'comment_comma_90_x'}, $book{'comment_comma_90_y'});

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
print "\t尺寸：$canvas{'canvas_width'} x $canvas{'canvas_height'}\n";
print "\t列数：$canvas{'leaf_col'}\n";
close(CCONFIG);

#背景图参数
my ($canvas_width, $canvas_height) = ($canvas{'canvas_width'}, $canvas{'canvas_height'});
my ($margins_top, $margins_bottom) = ($canvas{'margins_top'}, $canvas{'margins_bottom'});
my ($margins_left, $margins_right) = ($canvas{'margins_left'}, $canvas{'margins_right'});
my ($col_num, $lc_width) = ($canvas{'leaf_col'}, $canvas{'leaf_center_width'});
my $logo_text = $canvas{'logo_text'};
#计算列宽、行高
my $cw = ($canvas_width - $margins_left - $margins_right - $lc_width)/$col_num;
my $rh = ($canvas_height - $margins_top - $margins_bottom)/$row_num;
#叶面位置数组
my (@pos, $pos_x, $pos_y); #单列
my @pos_l = ([]); #单列左右双排左列位置数组
my @pos_r = ([]); #单列左右双排右列位置数据
#生成文字坐标，$pos_l、$pos_r用于批注双排，$pos_l用于正文单排
foreach my $i (1..$col_num) {
	foreach my $j (1..$row_num) {
		$pos_x = $canvas_width - $margins_right - $cw*$i if($i <= $col_num/2);
		$pos_x = $canvas_width - $margins_right - $cw*$i - $lc_width if($i > $col_num/2);
		$pos_y = $canvas_height - $margins_top - $rh*$j + $row_delta_y;
		#$pos_l[ ($i-1)*$row_num+$j ] = [$pos_x, $pos_y];
		#$pos_r[ ($i-1)*$row_num+$j ] = [$pos_x+$cw/2, $pos_y];
		push @pos_l, [$pos_x, $pos_y]; #由计算元素序号改为push到数据
		push @pos_r, [$pos_x+$cw/2, $pos_y];
	}
}

my $page_chars_num = $col_num*$row_num; #重要常量：每页字符计数器
my ($if_text000, $if_text999) = (0, 0); #是否存在用于保存前言及序的000.txt文件
my @dats = ('');
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
				if($k =~ m/\.|\!|\?|\(|\)|\[|\]/) { $k = '\\'.$k; }
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

    	s/$text_comma_nop//g if($text_comma_nop); #去除正文中不占字符位的标点
    	s/$comment_comma_nop//g if($comment_comma_nop); #去除批注中不占字符位的标点
    	s/《|》//g if(defined $if_book_vline and $if_book_vline == 1); #书名号处理为侧线时去除书名号
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
my $vpimg = $vpdf->image("canvas/$canvas_id.jpg"); #读取背景图片
my $vpage = $vpdf->page(); #创新新页面
#加载主辅字体
my %vfonts;
$vfonts{$fn1} = $vpdf->ttfont("fonts/$fn1", -noembed=>0, -nosubset=>1) if($fn1);
$vfonts{$fn2} = $vpdf->ttfont("fonts/$fn2", -noembed=>0, -nosubset=>1) if($fn2);
$vfonts{$fn3} = $vpdf->ttfont("fonts/$fn3", -noembed=>0, -nosubset=>1) if($fn3);
$vfonts{$fn4} = $vpdf->ttfont("fonts/$fn4", -noembed=>0, -nosubset=>1) if($fn4);
$vfonts{$fn5} = $vpdf->ttfont("fonts/$fn5", -noembed=>0, -nosubset=>1) if($fn5);

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

#添加封面，封面图片不存在时添加简易封面
if(-f "books/$book_id/cover.jpg") {
	print "发现封面图片'$book_id/boos/$book_id/cover.jpg ...\n";
	my $cpimg = $vpdf->image("books/$book_id/cover.jpg");
	$vpage->object($cpimg);
} else {
	print "未发现封面文件'$book_id/boos/$book_id/cover.jpg，创建简易封面...\n";
	my $pline = $vpage->gfx();
	my $plx = $canvas_width/2;
	$plx = $canvas_width if($canvas_width < $canvas_height);
	#中间细竖线
	$pline->linewidth(1);
	$pline->strokecolor('#cccccc');
	$pline->move($plx-50, $canvas_height);
	$pline->line($plx-50, $canvas_height, $plx-50, 0);
	$pline->stroke();
	$pline->move($plx+50, $canvas_height);
	$pline->line($plx+50, $canvas_height, $plx+50, 0);
	$pline->stroke();
	#中间细横线
	foreach my $lid (0..$canvas_height/200) {
		$pline->move($plx-50, $canvas_height-200*$lid);
		$pline->line($plx-50, $canvas_height-200*$lid, $plx+50, $canvas_height-200*$lid);
		$pline->stroke();
	}
	#中间粗竖线
	$pline->linewidth(20);
	$pline->strokecolor('gray');
	$pline->move($plx, $canvas_height);
	$pline->line($plx, $canvas_height, $plx, 0);
	$pline->stroke();
	#打印封面标题文字
	foreach my $i (0..$#tchars) {
		my $fs = $cover_title_font_size;
		my $fn = get_font($tchars[$i], \@tfns);
		my ($fx, $fy) = ($fs, $canvas_height-$cover_title_y-$fs*$i*1.2);
		$vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tchars[$i], -color => $cover_font_color);
	}
	#打印封面作者文字
	foreach my $i (0..$#achars) {
		my $fs = $cover_author_font_size;
		my $fn = get_font($achars[$i], \@tfns);
		my ($fx, $fy) = ($fs/2, $canvas_height-$cover_author_y-$fs*$i*1.2);
		$vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $achars[$i], -color => $cover_font_color);
	}
}

#依次处理每个文本，逐字打印到PDF页面
my %outlines;
my ($pid, $pcnt) = (0, 0); #非常重要：$pcnt每叶写入字符的当前标准字位指针
my ($flag_tbook, $flag_rbook) = (0, 0); #正文、批注中书名号标识
foreach my $tid ($from..$to) {
	last if(defined $opts{'z'} and $pid == $opts{'z'});
	print "读取'books/$book_id/text/'目录下第 $tid "."个文本文件...\n";
	my $dat = $dats[$tid];
	my @chars = split //, $dat;
	my $chars_num = $#chars+1; #需要处理的总字符数
	my @rchars = (); #保存标注文本字符。因标注文本可能跨页，创建新页后优先处理上叶遗留的标注文字
	my (@tpchars, @last, $tptitle); #标题字符数组，正文上个字符位置，标题

	if(defined $title_postfix) {
		my $cid = ($if_text000 == 1) ? $tid-1 : $tid; #如果存在000.txt文件，文件排序序号-1后计算卷号
		my $tpost = $title_postfix;
		$tpost =~ s/X/$zhnums{$cid}/;
		$tpost = '序' if($cid == 0);	 #序及前言
		$tpost = '附' if($if_text999 == 1 and $tid == $#dats); #附录
		@tpchars = split //, $title.$tpost;
	} else {
		@tpchars = split //, $title;
	}
	$tptitle = join '', @tpchars;
	$outlines{$tptitle} = $pid+2 if(not $outlines{$tptitle}); #添加到目录
	print "创建新PDF页[$pid]...\n";
	$vpage = $vpdf->page();
	$vpage->object($vpimg, 0, 0); #添加背景图
	#打印版心标题文字
	foreach my $i (0..$#tpchars) {
		my $fs = $title_font_size;
		my $fn = get_font($tpchars[$i], \@tfns);
		my ($fx, $fy) = ($canvas_width/2-$fs/2, $title_y-$fs*$i*$title_ydis);
		$fx=-$fs/2 if(defined $if_tpcenter and $if_tpcenter == 0); #标题不居中时位于最左侧，适用现代极简、竹简等无版心背景
		$vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tpchars[$i], -color => $title_font_color);
	}
	#批注文本采用双排，则实际每叶、每列文字数是不固定的，因此每个字符的页数、列数、行数无法提前计算，需逐个字符处理，直至全部字符处理完，期间指针到达整叶时创新新叶
	my $last_char;  #上一个字符，减小书名号第一个字符纵坐标
	while(1) {
		#非常重要：核心跳转机制，处理需要创建新叶的情况
		RCHARS:
		if($pcnt == $page_chars_num or (not scalar @chars and not scalar @rchars)) { #打满整叶或当前文本字符全部处理完时，打印页码，创建新叶，初始化相关全局变量
			$pid++;
			$pcnt = 0;
			#版心页码
            my @pchars_zh = split //, $zhnums{$pid};
            foreach my $i (0..$#pchars_zh) {
            	my $ps = $pager_font_size;
            	my $pc = $pchars_zh[$i];
            	my $px = $canvas_width/2-$pager_font_size/2;
            	my $py = $pager_y - $pager_font_size*$i*$title_ydis;
            	$px=-$ps/2 if(defined $if_tpcenter and $if_tpcenter == 0); #标题不居中时页码位于最左侧，适用现代极简、竹简等无版心背景
            	$vpage->text->textlabel($px, $py, $vfonts{$fn1}, $ps, $pc, -color => $pager_font_color);
            }
            last if(not scalar @chars and not scalar @rchars); #所有字符（包括批注字符数组）处理完时，退出While循环，处理下一文本
			print "创建新PDF页[$pid]...\n";
			$vpage = $vpdf->page(); #新页
			$vpage->object($vpimg, 0, 0);
			foreach my $i (0..$#tpchars) {
				my $fs = $title_font_size;
				my $fn = get_font($tpchars[$i], \@tfns);
				my ($fx, $fy) = ($canvas_width/2-$fs/2, $title_y-$fs*$i*$title_ydis);
				$fx=-$fs/2 if(defined $if_tpcenter and $if_tpcenter == 0);
				$vpage->text->textlabel($fx, $fy, $vfonts{$fn}, $fs, $tpchars[$i], -color => $title_font_color);
			}
		}
		#批注文字采用逐列打印机制
		if(scalar @rchars) { #BUG记录：标注文本最后一个字符未处理
			my $cnt; #批注字符计数器
			my @r_pos; #存储当前列剩余位置可用于打印标注双排字符的位置数组，每次跳转新列后重新计算新列批注双排文字的位置数组，与468行跳转机制对应
			my $rctmp = join '', @rchars;
			$rctmp =~ s/$comment_comma_nop_tmp//g if($comment_comma_nop_tmp); #去除批注中不占字符位置的标点
			$rctmp =~ s/《|》//g if(defined $if_book_vline and $if_book_vline == 1); #去除书名号
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
			if($pcnt+$cnt <= $pcol*$row_num) { #非整列
				@r_pos = (@pos_r[$pcnt+1..$pcnt+$cnt], @pos_l[$pcnt+1..$pcnt+$cnt]);
			} else { #整列
				@r_pos = (@pos_r[$pcnt+1..$pcol*$row_num], @pos_l[$pcnt+1..$pcol*$row_num]);
			}
			#打印批注文本字符
			my @rlast; #上一字符位置数组，用于计算不占字符位标点位置坐标
			while(my $rc = shift @rchars) { #处理批注字符数组剩余元素
				if($rc eq '《') {
					$flag_rbook = 1;
					$last_char = $rc;
					next if(defined $if_book_vline and $if_book_vline == 1);
				}
				if($rc eq '》') {
					$flag_rbook = 0;
					$last_char = $rc;
					next if(defined $if_book_vline and $if_book_vline == 1);
				}

				my $fn = '';
				
				$fn = get_font($rc, \@cfns);
				if($fn ne $fn1 and defined $try_st and $try_st == 1) {
					my $try = try_st_trans($rc);
					if($try) { $rc = $try; $fn = $cfns[0]; }
				}
				if(not $fn) { $rc = '□'; $fn = get_font($rc, \@cfns); }

				my ($fsize, $fcolor, $fdgrees) = ($fonts{$fn}->[1], $comment_font_color, $fonts{$fn}->[2]);
				my ($fx, $fy);

				print "\t[$pid/$pcnt] $rc -> $fn\n" if(defined $opts{'v'});
				if($comment_comma_nop =~ m/$rc/) { #先看该字符是否为不占字符位置标点
					($fx, $fy) = @rlast; #不占字符位置标点以上个字符位置为参照取相对位置
					$fsize = $fsize*$comment_comma_nop_size;
					$fx+= $cw/2*$comment_comma_nop_x;
					$fy-= $rh*$comment_comma_nop_y;
					if($fy-$margins_bottom < 10) { $fy = $margins_bottom+10; } #列尾纵坐标微调不压线
				} else {
					my $rpref = shift @r_pos; #提取批注字符当前可用位置
					if(not $rpref) { unshift @rchars, $rc;  goto RCHARS; } #无可用位置时，说明需要跳转新列，并将字符重新放回批注字符数组
					($fx, $fy) = @$rpref;
					@rlast = @$rpref;
					$fx+= ($cw-$fsize*2)/4;
					$fy+= ($rh-$fsize)/4;
					if($comment_comma_90 =~ m/$rc/) {
						$fdgrees = -90;
						$fsize = $fsize*$comment_comma_90_size;
						$fx+= $cw/2*$comment_comma_90_x;
						$fy+= $rh*$comment_comma_90_y;
					}
					$pcnt+=0.5; #批注占半个字符位
				}
				$fcolor = $onlyperiod_color ? $onlyperiod_color : $fcolor if($if_onlyperiod == 1 and $rc eq '。');
				$fcolor = 'blue' if(defined $opts{'z'} and $fn ne $cfns[0]);
				$vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $rc, -rotate => $fdgrees, -color => $fcolor);
				if(defined $if_book_vline and $if_book_vline == 1 and $rc ne ' ') {
					if($flag_rbook == 1) { #书名侧边线
						my $ply1 = $fy-$rh*0.3;
						my $ply2 = ($last_char eq '《') ? $fy+$rh*0.65 : $fy+$rh*0.7;; #书名第一个字符y坐标微调，避免书名号连续
						$ply2 = $canvas_height-$margins_top-5 if($ply2 >= $canvas_height-$margins_top);
						draw_wavy_line($fx, $ply1, $fx, $ply2, $bline_w, $bline_c);
					}
				}
				$last_char = $rc; #更新批注最近处理的字符
			} #while
			#print $pcnt, "\n"; #有效断点
			if(scalar @rchars) { goto RCHARS; } #若标注文本有遗留，说明批注文字将跨叶，跳转创建新叶继续处理标注文字字符数组
			$pcnt = int($pcnt+0.5); #指针前进数
			if($pcnt == $page_chars_num) { goto RCHARS; } #如果到达页尾，跳转创建新叶
		}
		#正文文字打印
		if(not scalar @chars) { goto RCHARS; } #文本所有字符已处理完，跳转判断批注字符数组是否还未处理完
		my $char = shift @chars;
    	if($char eq '$') { #前进半页或整页
    		shift @chars for(1..$row_num-1); #跳过$后补齐列高的空格
    		next if($pcnt == 0 or $pcnt == $page_chars_num/2);
    		if($pcnt < $page_chars_num/2) {
    			$pcnt = $page_chars_num/2; next;
    		} else {
    			$pcnt = $page_chars_num; next;
    		}
    	}
		if($char eq '%') {
			shift @chars for (1..$row_num-1); #跳过%后补齐列高的空格
			$pcnt = $page_chars_num; goto RCHARS;
		}
		if($char eq '&') { #跳至页最后一列
			shift @chars for (1..$row_num-1); #跳过&后补齐列高的空格
			if($pcnt <= $page_chars_num-$row_num+1) {
				$pcnt = $page_chars_num-$row_num; goto RCHARS;
			}
		}
		if($char eq '《') {
			$flag_tbook = 1;
			$last_char = $char;
			next if(defined $if_book_vline and $if_book_vline == 1);
		}
		if($char eq '》') {
			$flag_tbook = 0;
			$last_char = $char;
			next if(defined $if_book_vline and $if_book_vline == 1);
		}
		#注意：原始文本中的批注文本需严格使用【】区别
		if($char eq '【') {
			my $rdat;
			while(my $rchar = shift @chars) {
				last if($rchar eq '】' );
				$rdat.= $rchar;
			}
			@rchars = split //, $rdat; #更新全局标注文本变量
			goto RCHARS; #处理标注文字
		} else { #正文文字处理
			$pcnt++ if($pcnt < $page_chars_num); #如果未达到叶尾，指针前进，到达即停止
			if($pcnt <= $page_chars_num) {
				my $fn = '';

				$fn = get_font($char, \@tfns);
				if($fn and $fn ne $fn1 and defined $try_st and $try_st == 1) {
					my $try = try_st_trans($char);
					if($try) { $char = $try; $fn = $tfns[0]; }
				}
				if(not $fn) { $char = '□'; $fn = get_font($char, \@tfns); }

				my ($fsize, $fcolor, $fdgrees)  = ($fonts{$fn}->[0], $text_font_color, $fonts{$fn}->[2]);
				my ($fx, $fy) = @{$pos_l[$pcnt]};

				print "[$pid/$pcnt] $char -> $fn\n" if(defined $opts{'v'});
				if($text_comma_nop =~ m/$char/) {
					$fsize = $fsize*$text_comma_nop_size;
					($fx, $fy) = @last;
					$fx+= $cw*$text_comma_nop_x;
					$fy-= $rh*$text_comma_nop_y;
					if($fy-$margins_bottom < 10) { $fy = $margins_bottom+10; }
					$pcnt--;
				} else {
					if($text_comma_90 =~ m/$char/) {
						$fsize = $fsize*$text_comma_90_size;
						$fx+= $cw*$text_comma_90_x;
						$fy+= $rh*$text_comma_90_y;
						$fdgrees = -90;
					} else {
						$fx+= ($cw-$fsize)/2;
					}
					@last = @{$pos_l[$pcnt]};
				}
				$fcolor = $onlyperiod_color ? $onlyperiod_color : $text_font_color if($if_onlyperiod == 1 and $char eq '。');
				$fcolor = 'blue' if(defined $opts{'z'} and $fn ne $fn1);
				#print "$char -> $fn\n";
				$vpage->text()->textlabel($fx, $fy, $vfonts{$fn}, $fsize, $char, -rotate => $fdgrees, -color => $fcolor);
				if(defined $if_book_vline and $if_book_vline == 1 and $char ne ' ') {
					if($flag_tbook == 1) { #书名侧边线
						my $ply1 = $fy-$rh*0.3;
						my $ply2 = ($last_char eq '《') ? $fy+$rh*0.6 : $fy+$rh*0.7; #书名第一个字符y坐标微调，避免书名号连续
						$ply2 = $canvas_height-$margins_top-5 if($ply2 >= $canvas_height-$margins_top);
						draw_wavy_line($fx-2, $ply1, $fx-2, $ply2, $bline_w, $bline_c);
					}
				}
				if($pcnt == $page_chars_num) {
					if(scalar @chars) {
						my $char = shift @chars; #达到叶尾后，提前获取下一个字符，看是否不占位标点，若是则先打印再跳转建新叶
						if($text_comma_nop =~ m/$char/) {
							($fx, $fy) = @{$pos_l[$pcnt]};
							$fsize = $fsize*$text_comma_nop_size;
							$fx+= $cw*$text_comma_nop_x;
							$fy-= $rh*$text_comma_nop_y;
							if($fy-$margins_bottom < 10) { $fy = $margins_bottom+10; }
							$vpage->text->textlabel($fx, $fy, $vfonts{$fn1}, $fsize, $char, -rotate => $fdgrees, -color => $fcolor);
						} else {
							unshift @chars, $char; #占位字符重新放回字符数组头部，放到新叶处理
						}
					}
				}
			}
		}
		$last_char = $char; #更新正文最近处理的字符
		last if(defined $opts{'z'} and $pid == $opts{'z'});
	}#while
}

if(defined $title_directory and $title_directory == 1) {
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
    	$item->dest($vpdf->open_page($otpid));
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
		`gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$output $input`;
		`rm $input`;
		print "完成！\n";
	}
} else {
	print "建议：使用'-c'参数对PDF文件进行压缩！\n"
}

sub print_welcome {
	print '-'x60, "\n";
	print "\t$software $version"."，兀雨古籍刻本电子书制作工具\n";
	print "\t作者：GitHub\@shanleiguang 小红书\@兀雨书屋\n";
	print '-'x60, "\n";
}

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
		作者：GitHub\@shanleiguang, 小红书\@兀雨书屋，2025
END
}

sub try_st_trans {
	my $char = shift;
	my $char_s2t = simp_to_trad($char);
	my $char_t2s = trad_to_simp($char);
	my ($fn_s2t, $fn_t2s);
	if($char_s2t) {
		$char_s2t =~ s/\[\]//g;
		$char_s2t = (split //, $char_s2t)[0];
		$fn_s2t = get_font($char_s2t, \@fns);
		#print "$char -> $char_s2t, $fn_s2t\n";
	}
	if($char_t2s) {
		$char_t2s =~ s/\[\]//g;
		$char_t2s = (split //, $char_t2s)[0];
		$fn_t2s = get_font($char_t2s, \@fns);
		#print "$char -> $char_t2s, $fn_t2s\n";
	}
	return $char_s2t if($fn_s2t eq $fn1);
	return $char_t2s if($fn_t2s eq $fn1);
	return '';
}

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

sub get_cid_zh {
	my $cid = shift;
	my @chars_zh = ('〇', '一', '二', '三', '四', '五', '六', '七', '八', '九');
	$cid =~ s/^0//;
	$cid =~ s/(\d)/$chars_zh[$1]/g;
	return $cid;
}

sub get_font {
	my ($char, $fref) = @_;
	my @fonts = @$fref;
	foreach my $f (@fonts) {
		return $f if(font_check($f, $char));
	}
	return undef;
}

sub font_check {
	my ($font, $char) = @_;
	my $freetype = Font::FreeType->new();
	my $face = $freetype->face("fonts/$font");
	my $fontglyph = $face->glyph_from_char($char);

	return 1 if($fontglyph);
	return 0;
}
