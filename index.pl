#!/usr/bin/perl -W
# $Id: index.pl,v 1.21 2013/09/17 14:55:15 yanovich Exp $

use GD;
use CGI;
use Errno qw(:POSIX);
use Fcntl qw(:flock);
use FreezeThaw qw(freeze thaw);
use File::Basename;
use strict;
use warnings;

my $DIR = dirname $ENV{SCRIPT_FILENAME};
my $FN_THUMBS = ".thumbs";
my $FN_IDX = ".index";

our %cfg;
require "$DIR/.config";

my $RESW = 120;
my $RESH = 90;
my $QUAL = 60;

my $q = CGI->new(shift);
my $prhd = 0;

sub mydie {
	unless ($prhd) {
		print $q->header, <<EOF;
<!DOCTYPE html>
<html lang="en-US">
	<head>
		<title>$cfg{title} albums</title>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
	</head>
	<body>
		<h2>Error</h2>
EOF
	}
	print "@_\n";
	exit 1;
}

sub cachedata {
	my ($fn, @data) = @_;

	open F, ">", $fn;
	flock F, LOCK_EX;
	print F freeze(@data);
	flock F, LOCK_UN;
	close F;
}

sub in_array {
	my ($a, $k) = @_;
	for my $i (@$a) {
		return 1 if $i eq $k;
	}
	return 0;
}

sub findpos {
	my ($a, $k) = @_;
	for (my $i = 0; $i < @$a; $i++) {
		return $i if $a->[$i] eq $k;
	}
	return -1;
}

sub loadalbum {
	my ($alnam, $top) = @_;

	my $fn_dir = "$DIR/$alnam";
	my $fn_tdir = "$DIR/$FN_THUMBS/$alnam";
	unless (-e $fn_tdir) {
		mkdir $fn_tdir or mydie("mkdir $fn_tdir: $!");
	}

	my %albums;
	my $ad;

	unless ($top) {
		$ad = {
		    n		=> 0,
		    photos	=> [ ],
		    taglist	=> { },
		    captions	=> { },
		};
	}

	my $fn_idx = "$fn_tdir/$FN_IDX";
	if (-e $fn_idx) {
		open IDX, "<", $fn_idx or
		    mydie "open $fn_idx: $!";
		my $data = <IDX>;
		close IDX;

		if ($top) {
			eval {
				%albums = thaw $data;
			};
		} else {
			eval {
				($ad) = thaw $data;
			};
		}
		return $ad ? $ad : %albums if !$@ and
		    (stat $fn_dir)[9] < (stat $fn_idx)[9];
	}

	my %aold = %albums;
	%albums = ();

	opendir D, $fn_dir or mydie "opendir $fn_dir: $!";
	while (my $fn = readdir D) {
		next if
		    $fn eq "." or
		    $fn eq ".." or
		    $fn eq ".git" or
		    $fn =~ /^\.ht/ or
		    $fn =~ /\.pl$/ or
		    $fn eq $FN_THUMBS;
		$albums{$fn} = loadalbum($fn, 0) if
		    -d "$fn_dir/$fn";
		if ($ad) {
			$ad->{n}++;
			push @{ $ad->{photos} }, $fn unless
			    in_array($ad->{photos}, $fn);
		}
	}
	closedir D;

	@{ $ad->{photos} } = sort @{ $ad->{photos} } if $ad;

	cachedata($fn_idx, $top ? %albums : $ad);
	return $ad ? $ad : %albums;
}

sub thumb {
	my ($alnam, $fn) = @_;
	my $dir = "$DIR/$alnam";
	my $thdir = "$DIR/$FN_THUMBS/$alnam";
	my $th = "$thdir/$fn";
	my $im = "$dir/$fn";
	if (-f $im and !-e $th) {
		if ($fn =~ /\.(?:MOV|mp4)$/i) {
			system("/usr/local/bin/ffmpeg -r 1 -i \Q$im\E -s ${RESW}x$RESH " .
			    " -loglevel quiet -n -f image2 -vframes 1 \Q$th\E >&2");
		} elsif (my $img = GD::Image->new($im)) {
			my $res;
			$res = int($RESH * $img->width / $img->height) . "x$RESH";
			system("convert \Q$im\E -quality $QUAL -scale $res -auto-orient \Q$th\E &");
		} else {
			#print "$im: $!\n";
		}
	}
	my @a = (qq{<img id="$fn" height="$RESH" src="$FN_THUMBS/$alnam/$fn" />});
	if ($fn =~ /\.(?:MOV|mp4)$/i) {
		$a[0] =~ s/<img /<img onload="center(this.parentNode)" /;
		@a = (qq{<div style="display: inline-block; position: relative">},
		    @a,
		    qq{<img src="play.svg" class="meta" />},
		    qq{</div>});
	}
	return @a;
}

my $act = $q->param('act') || "";

print $q->header, <<EOF;
<!DOCTYPE html>
<html lang="en-US">
	<head>
		<title>$cfg{title} albums</title>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
		<link rel="stylesheet" type="text/css" href="main.css" />
		<script type="text/javascript" src="main.js"></script>
		<style type='text/css'>
			body {
				background-color: $cfg{bgcolor};
			}
			#panel {
				background-color: $cfg{bgcolor};
			}
		</style>
	</head>
	<body>
EOF
$prhd = 1;

my %albums = loadalbum(".", 1);

sub ui_thumb {
	my ($ad, $alnam, $im) = @_;

	my $tags = "";
	if (exists $ad->{taglist}{$im}) {
		$tags = join ', ', map { "'$_'" }
		    @{ $ad->{taglist}{$im} };
	}

	my $caps = "";
	if (exists $ad->{captions}{$im}) {
		$caps = join ', ', map { "'$_'" }
		    @{ $ad->{captions}{$im} };
	}

	return qq{<a href="$alnam/$im" },
	    qq{onclick="doAction('$alnam', '$im', },
	    qq{ [$tags], [$caps]); return false">},
	    thumb($alnam, $im), qq{</a>};
}

my $def = 1;

if ($act eq "search") {
	my $tag = $q->param("q");
	foreach my $alnam (keys %albums) {
		my $ad = $albums{$alnam};

		my $found = 0;

		my $rt = $ad->{taglist};
		foreach my $im (keys %$rt) {
			if (in_array($rt->{$im}, $tag)) {
				unless ($found) {
					print qq{<h3>$alnam</h3>};
					print qq{<div align="center">};
				}
				print ui_thumb($ad, $alnam, $im);
				$found = 1;
			}
		}

		print qq{</div>} if $found;
	}
	$def = 0;
}

if ($act eq "detag") {
	$def = 0;
}

if ($act eq "tag") {
	my $alnam = $q->param("album");
	my @im = $q->param("im");
	my $tag = $q->param("tag");
	if (exists $albums{$alnam}) {
		my $ad = $albums{$alnam};
		foreach my $im (@im) {
			$ad->{taglist}{$im} = [] unless
			    exists $ad->{taglist}{$im};
			push @{ $ad->{taglist}{$im} }, $tag unless
			    in_array($ad->{taglist}{$im}, $tag);
		}
		cachedata("$DIR/$FN_THUMBS/$alnam/$FN_IDX", $ad);
		cachedata("$DIR/$FN_THUMBS/$FN_IDX", %albums);
	} else {
		mydie "No such album.";
	}
	$act = "album";
	$def = 0;
}

if ($act eq "move") {
	my $f_a = $q->param("from");
	my $t_a = $q->param("to");
	my @im = $q->param("im");

	my $path_f = "$DIR/$f_a";
	my $path_t = "$DIR/$t_a";

	mydie "Source album does not exist." unless exists $albums{$f_a};

	unless (exists $albums{$t_a}) {
		mydie("Invalid destination name.") unless
		    $t_a =~ /^[A-Za-z0-9._ -]+$/;
		mkdir($path_t);
		mkdir("$DIR/$FN_THUMBS/$t_a");
	}

	my @sav_im;
	my $t_ad = $albums{$t_a};
	my $f_ad = $albums{$f_a};
	foreach my $im (@im) {
		my $pos = findpos($f_ad->{photos}, $im);
		next if $pos < 0;

		if (exists $f_ad->{photos}) {
			$t_ad->{taglist}{$im} = $f_ad->{taglist}{$im};
			delete $f_ad->{taglist}{$im};

			$t_ad->{captions}{$im} = $f_ad->{captions}{$im};
			delete $f_ad->{captions}{$im};
		}

		splice @{ $f_ad->{photos} }, $pos, 1;
		my $tim = $im;
		$tim =~ s/\./.0./ while in_array($t_ad->{photos}, $tim);
		push @{ $t_ad->{photos} }, $tim;
		rename("$path_f/$im", "$path_t/$tim") or
		    warn "rename $f_a/$im: $!\n";
		unlink("$DIR/$FN_THUMBS/$f_a/$im");
	}
	cachedata("$DIR/$FN_THUMBS/$t_a/$FN_IDX", $t_ad);
	cachedata("$DIR/$FN_THUMBS/$f_a/$FN_IDX", $f_ad);
	cachedata("$DIR/$FN_THUMBS/$FN_IDX", %albums);
	$act = "album";
	$q->param("album", $f_a);
	$def = 0;
}

if ($act eq "album") {
	print qq{<script type='text/javascript'> albums = [};
	foreach my $al (keys %albums) {
		print " '$al', ";
	}
	print qq{ 0 ]; albums.pop() </script>};

	my $alnam = $q->param("album");
	my $n = $q->escapeHTML($alnam);
	print qq{<div>};
	if (exists $albums{$alnam}) {
		my $ad = $albums{$alnam};
		for (@{ $ad->{photos} }) {
			print ui_thumb($ad, $alnam, $_);
		}
	} else {
		mydie("no such album: $n");
	}
	print <<EOF;
	</div>
	<div style="height: 35px">&nbsp;</div>
	<div id="panel">
		<a href="?">albums</a> &nbsp; &middot; &nbsp;
		<a href="#" onclick="searchPrompt(); return false">search</a> &nbsp; &middot; &nbsp;
		<a href="#" onclick="batchTag('$alnam'); return false">tag</a>
		<span id="batch"></span> &nbsp; &middot; &nbsp;
		<a href="#" onclick="moveIm('$alnam'); return false">move</a>
		<span id="move"></span>
	</div>
	<div id="focus" onclick="hideFocus()"></div>
EOF
	$def = 0;
}

if ($def) {
	for my $alnam (keys %albums) {
		my $ad = $albums{$alnam};
		my $n = $q->escapeHTML($alnam);
		print qq{<div class="album"><a href="?act=album;album=$n">},
		    thumb($n, $ad->{photos}->[0]),
		    qq{<br />$n (},
		    scalar(@{ $ad->{photos} }),
		    qq{)</a></div>\n};
	}
}

		print <<EOF;
	</body>
</html>
EOF
