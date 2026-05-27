#!/usr/bin/perl
#整段缩进文本格式化脚本
#将本脚本放到书籍目录下，将原始文本保存在tmp目录下，需要整段缩进的段首添加S2标识（2代表缩进2个空格）
#脚本格式化后的文本将存入text目录下，用于书籍制作
#by shanleiguang, 2025.03
use strict;
use warnings;

use Font::FreeType;
use Getopt::Std;
use Encode;
use utf8;

my (%opts, $from, $to, $output);
my (%book, $row_num);

getopts('f:t:', \%opts);
($from, $to) = ($opts{'f'}, $opts{'t'});
open BCONFIG, "book.cfg";
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

my $font = $book{'font1'};
my $if_tagbl = $book{'if_tag_bookline'};
my ($if_tagrf, $if_tagcf) = ($book{'if_tag_rectframe'}, $book{'if_tag_circleframe'});
my $if_tagtz = $book{'if_tag_textzoom'};
my ($if_tagcn, $if_tagpn, $if_tagln) = ($book{'if_tag_circlenote'}, $book{'if_tag_pointnote'}, $book{'if_tag_linenote'});

if($if_tagbl) { $book{'text_comma_nop'}.= '|《|》'; $book{'comment_comma_nop'}.= '|《|》'; } #书名左侧线
if($if_tagrf) { $book{'text_comma_nop'}.= '|〔|〕'; $book{'comment_comma_nop'}.= '|〔|〕'; } #圆角方框
if($if_tagcf) { $book{'text_comma_nop'}.= '|〈|〉'; $book{'comment_comma_nop'}.= '|〈|〉'; } #圆框
if($if_tagtz) { $book{'text_comma_nop'}.= '|（|）'; $book{'comment_comma_nop'}.= '|（|）'; } #正文字符字体大小缩放
if($if_tagcn) { $book{'text_comma_nop'}.= '|｛|｝'; $book{'comment_comma_nop'}.= '|｛|｝'; } #正文字符右侧圈注
if($if_tagpn) { $book{'text_comma_nop'}.= '|＜|＞'; $book{'comment_comma_nop'}.= '|＜|＞'; } #正文字符右侧点注
if($if_tagln) { $book{'text_comma_nop'}.= '|［|］'; $book{'comment_comma_nop'}.= '|［|］'; } ##正文字符右侧线注

my @nianhaos = (
	'洪武', '建文', '永樂', '洪熙', '宣德', '正統', '景泰', '天順', '成化', '弘治', '正德', '嘉靖', '隆慶', '萬曆', '泰昌', '天啓', '天啟', '崇禎',
	'崇德', '順治', '康熙', '雍正', '乾隆', '嘉慶', '道光', '咸豐', '同治', '光緒', '宣統'
);

$row_num = $book{'row_num'};
foreach my $pid ($from..$to) {
	my ($content, $text);
	
	open TMP, "< tmp/$pid.txt";
	{ $/ = undef; $content = <TMP>; }
	close(TMP);

	#○
	$content = decode('utf-8', $content);
	$content =~ s/S11（/\n\%\nS22（/g;
	$content =~ s/\@（/\n\%\nS22（/g;
	$content =~ s/S22張山來曰/S11張山來曰/g;
	$content =~ s/‌//g;
	$content =~ s/猂/悍/g;
	#鹹誌餘雲麵


	my $ctmp = $content;
	$ctmp =~ s/【.*?】//g;
	foreach my $nh (@nianhaos) {
		while($ctmp =~ m/$nh/g) {
			print "年号：$nh\n";
		}
	}
	#$content =~ s/S11（/\n\%\nS22（/g;
	#$content =~ s/\@（/\n\%\nS22（/g;
	#print $content and exit;

	my $fflag = 0;
	my @lines = split /\n/, $content;

	foreach (@lines) {
		chomp;
		#$line = decode('utf-8', $line);
		s/\s//g;
		#print "$line\n";
		if($book{'exp_replace_comma'}) {
			foreach my $kv (split /\|/, $book{'exp_replace_comma'}) {
				my ($k, $v) = split //, $kv;
				if($k =~ m/\.|\!|\?|\(|\)|\[|\]|\-/) { $k = '\\'.$k; }
				s/$k/$v/g;
			}
		}
		if($book{'exp_replace_number'}) {
			foreach my $kv (split /\|/, $book{'exp_replace_number'}) {
				my ($k, $v) = split //, $kv;
				s/$k/$v/g if(not m/^S\d/);
			}
		}
		s/$book{'exp_delete_comma'}//g;
		if($book{'if_nocomma'} == 1) {
			s/$book{'exp_nocomma'}//g;
		}
		if($book{'if_onlyperiod'} == 1) {
			s/$book{'exp_onlyperiod'}/。/g;
			s/。+/。/g;
			s/^。//;
			s/〕。/〕/g;
		}
		my ($rflag, $cnt) = (0, 0); #批注字符标识，列字数计数器
		s/^（虞初新志卷/（虞初新志卷之/;
		if(m/^（虞初新志卷之(.*?)）/) {
			push @lines, '&';
			push @lines, "卷$1【終】";
		}
		s/清张潮輯/\@\@\@\@\@\@新安張\@潮山來氏輯/;
		if(m/\%/ and $fflag == 0) {
			$fflag = 1;
			next;
		}
		#s/(☐+)/〔$1〕/g;
		if(m/^S(\d+)(.*?)$/) { #需要缩进的段落
			my ($sns, $line) = ($1, $2);
			my ($sn1, $sn2) = split //, $sns;
			$sn2 = $sn2 ? $sn2 : 0;

			my $flflag = 1;
			my @lchars = split //, $line; #格式化前原字符数组
			my @nchars; #格式化后字符数组
			while(my $lchar = shift @lchars) {
				my $snum = ($flflag == 1) ? $sn1 : $sn2;
				if($lchar eq '【') {
					push @nchars, $lchar;
					$rflag = 1; #夹批开始标识
					$cnt = int($cnt+0.5);
					next;
				}
				if($lchar eq '】') {
					push @nchars, $lchar;
					$rflag = 0; #夹批结束标识
					next;
				}
				if($lchar =~ m/$book{'text_comma_nop'}/ or $lchar =~ m/$book{'comment_comma_nop'}/) {
					push @nchars, $lchar;
					next;
				}
				$cnt = int($cnt+0.5)+1 if($rflag == 0); #正文字符，计数器向上取整
				$cnt+= 0.5 if($rflag == 1); #夹批字符，计数器+0.5
				if($rflag == 0) { #正文字符时
					if($cnt == 1) { #每列首字符前添加空格，实现缩进
						push @nchars, '@'x$snum.$lchar;
					} else {
						if($cnt <= $row_num-$snum) {
							push @nchars, $lchar;
						} else {
							unshift @lchars, $lchar;
							$flflag = 0;
							$cnt = 0;
						}
					}
				} #if($rflag == 0
				if($rflag == 1) { #批注文字时
					if($cnt == 0.5) { #每列首字符前添加空格，实现缩进
						push @nchars, '@@'x$snum.'】【'.$lchar;
					} else {
						if(int($cnt+0.5) <= $row_num-$snum) {
							push @nchars, $lchar;
						} else {
							unshift @lchars, $lchar;
							$flflag = 0;
							$cnt = 0;
						}
					}
				} #if$flag == 1
			} #while
			$_ = join '', @nchars;
		}
		$text.= "$_\n";
	}
	#close(TMP);
	#print $text;
	open TEXT, "> text/$pid.txt";
	print TEXT $text;
	close(TEXT);
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
	my $face = $freetype->face("../../fonts/$font");
	my $fontglyph = $face->glyph_from_char($char);

	return 1 if($fontglyph);
	return 0;
}
