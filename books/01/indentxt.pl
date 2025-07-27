#!/usr/bin/perl
#整段缩进文本格式化脚本
#将本脚本放到书籍目录下，将原始文本保存在tmp目录下，需要整段缩进的段首添加S2标识（2代表缩进2个空格）
#脚本格式化后的文本将存入text目录下，用于书籍制作
#by shanleiguang, 2025.03
use strict;
use warnings;

use Getopt::Std;
use Encode;
use utf8;

my (%opts, $from, $to, $output);
my (%book, $row_num);

getopts('nf:t:', \%opts);
($from, $to, $output) = ($opts{'f'}, $opts{'t'}, $opts{'o'});
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

my %zhnums;
open ZHNUM, '< ../../db/num2zh_jid.txt';
while(<ZHNUM>) {
	chomp;
	$_ = decode('utf-8', $_);
	my ($a, $b) = split /\|/, $_;
	$zhnums{$a} = $b;
}
close(ZHNUM);

$row_num = $book{'row_num'};
foreach my $pid ($from..$to) {
	my ($text, $t1, $t2);
	
	open TMP, "< tmp/$pid.txt";
	while(<TMP>) {
		chomp;
		$_ = decode('utf-8', $_);

		s/\s//g;
		if($book{'exp_replace_comma'}) {
			foreach my $kv (split /\|/, $book{'exp_replace_comma'}) {
				my ($k, $v) = split //, $kv;
				if($k =~ m/\.|\!|\?|\(|\)|\[|\]|\-/) { $k = '\\'.$k; }
				s/$k/$v/g;
			}
		}
		if($book{'if_nocomma'} == 1) {
			s/$book{'exp_nocomma'}//g;
		}
		if($book{'if_onlyperiod'} == 1) {
			s/$book{'exp_onlyperiod'}/。/g;
			s/。+/。/g;
			s/^。//;
			s/】【//g;
			s/【。/【/g;
		}

		my ($rflag, $cnt) = (0, 0); #批注字符标识，列字数计数器

		if(m/^S(\d)(.*?)$/) { #需要缩进的段落
			my ($snum, $line) = ($1, $2);
			my @lchars = split //, $line; #格式化前原字符数组
			my @nchars; #格式化后字符数组
			while(my $lchar = shift @lchars) {
				if($lchar =~ m/$book{'text_comma_nop'}/ or $lchar =~ m/$book{'comment_comma_nop'}/) {
					push @nchars, $lchar;
					next;
				}
				if($book{'if_book_vline'}) {
					if($lchar =~ m/《|》/) {
						push @nchars, $lchar;
						next;
					}
				}
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
							$cnt = 0;
						}
					}
				} #if$flag == 1
			} #while
			$_ = join '', @nchars;
		} #if(m/^S
		$text.= "$_\n";
	}
	close(TMP);

	$pid = '00'.$pid if($pid <= 9);
	$pid = '0'.$pid if($pid > 9 and $pid <= 99);

	open TEXT, "> text/$pid.txt";
	print TEXT $text;
	close(TEXT);
}
