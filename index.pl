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
	my ($fn_dir, $top) = @_;

	my $fn_tdir = "$fn_dir/$FN_THUMBS";
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
		    $fn eq "CVS" or
		    $fn =~ /^\.ht/ or
		    $fn =~ /\.pl$/ or
		    $fn eq $FN_THUMBS;
		$albums{$fn} = loadalbum("$fn_dir/$fn", 0) if
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
	my $thdir = "$dir/$FN_THUMBS";
	my $th = "$thdir/$fn";
	my $im = "$dir/$fn";
	if (-f $im and !-e $th) {
		if ($fn =~ /\.(?:MOV|mp4)$/i) {
			system("/usr/local/bin/ffmpeg -r 1 -i $im -s ${RESW}x$RESH " .
			    " -loglevel quiet -n -f image2 -vframes 1 $th >&2");
		} elsif (my $img = GD::Image->new($im)) {
			my $res;
			$res = int($RESH * $img->width / $img->height) . "x$RESH";
			system("convert $im -quality $QUAL -scale $res -auto-orient $th &");
		} else {
			#print "$im: $!\n";
		}
	}
	my @a = (qq{<img id="$fn" height="$RESH" src="$alnam/$FN_THUMBS/$fn" />});
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

print $q->header, <<'EOF';
<!DOCTYPE html>
<html lang="en-US">
	<head>
		<title>$cfg{title} albums</title>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
		<style type="text/css">
		body {
			background-color: #424;
			padding: 0;
			margin: 0;
			color: white;
			font-weight: bold;
			text-shadow: .1em .1em .1em rgba(0,0,0,.5);
		}
		img {
			border: 0;
			margin: 0;
			vertical-align: bottom;
			align: left;
		}
		.album {
			text-align: center;
			display: inline-block;
			margin: 5px;
		}
		form {
			display: inline;
		}
		.album img {
			border: 1px solid #303;
			box-shadow: 3px 3px 3px rgba(0,0,0,.5);
		}
		a {
			text-decoration: none;
			color: white;
			font-weight: bold;
		}
		#focus {
			display: none;
			position: fixed;
			top: 0px;
			left: 0px;
			background-color: rgba(0,0,0,.8);
			width: 100%;
			height: 100%;
			z-index: 10;
			text-align: center;
		}
		img.meta {
			position: absolute;
			left: 0px;
			top: 0px;
			z-index: 5;
			visibility: hidden;
		}
		#panel {
			position: fixed;
			padding-top: 4px;
			left: 0px;
			bottom: 0px;
			width: 100%;
			height: 35px;
			background-color: #525;
			text-align: center;
			border-top: 1px solid #303;
			box-shadow:
			   0 2px 6px rgba(0,0,0,0.5),
			   inset 0 1px rgba(255,255,255,0.3),
			   inset 0 10px 5px rgba(255,255,255,0.1),
			   inset 0 10px 20px rgba(255,255,255,0.25),
			   inset 0 -15px 30px rgba(0,0,0,0.3);
			z-index: 15;
		}
		.sel {
			outline: 5px groove #f90;
			-webkit-filter: sepia(73%);
			transition: all .1s linear;
		}
		input[type='text'] {
			background-color: #525;
			border: 1px solid white;
			padding: 1px;
			padding-left: 2px;
			padding-right: 2px;
			color: #fff;
			width: 100px;
			font-weight: bold;
			text-shadow: .1em .1em .1em rgba(0,0,0,.5);
			box-shadow:
			   0 1px 2px 2px rgba(0,0,0,0.25),
			   inset 0 10px 5px rgba(255,255,255,0.1),
			   inset 2px 3px 3px rgba(0,0,0,0.3);
		}
		h3 {
			text-align: center;
		}
		</style>
		<script type="text/javascript">
			function getObj(id) {
				return (document.getElementById(id))
			}

			function cancelBubble(e) {
				if (!e)
					e = window.event
				if (e.stopPropagation)
					e.stopPropagation()
				if (e.cancelBubble)
					e.cancelBubble = true
			}

			function thumbFocus(alnam, im, tags, caps) {
				var o = getObj('focus')
				o.style.display = 'block'
				var w = window.innerWidth
				var h = window.innerHeight
				o.style.pixelWidth = w
				o.style.pixelHeight = h
				w = Math.round(.83 * w)
				h = Math.round(.83 * h)
				if (h > 25)
					h -= 25
				var st = '', sc = ''
				for (var i in tags)
					st += (st == '' ? '' : ', &nbsp; ') +
					    tags[i] + '<sup><a href="?act=detag;' +
						'album=' + alnam +
						';tag=' + tags[i] + ';im=' + im +
						'">x</a></sup>'
				for (var i in caps)
					sc += caps[i] + '<br />'
				o.innerHTML =
				    '<span onclick="cancelBubble(event)">' +
				    '<img style="border: 2px solid black; ' +
				      'box-shadow: 0px 4px 4px rgba(0,0,0,.5); ' +
				      'max-width: ' + w + 'px;' +
				      'max-height: ' + h + 'px" src="' +
				    alnam + '/' + im + '" /><br />' +
				    caps +
				    'tags: &nbsp; ' + st + '<br />' +
				    '<form action="#">' +
				      '<input type="hidden" name="act" value="tag" />' +
				      '<input type="hidden" name="album" value="' + alnam + '" />' +
				      '<input type="hidden" name="im" value="' + im + '" />' +
				      'add tag: &nbsp; ' +
				      '<input type="text" name="tag" />' +
				    '</form>' +
				    '</span>'
			}

			function hideFocus() {
				getObj('focus').style.display = 'none'
			}

			function displayAttrs(o) {
				var s = ''
				for (var i in o)
					s += i + ': ' + o[i] +'\n'
				alert(s)
			}

			function center(o) {
				var b = o.childNodes[0]
				var i = o.childNodes[1]
				i.style.pixelLeft =
				    b.clientWidth/2 -
				    i.clientWidth/2
				i.style.pixelTop =
				    b.clientHeight/2 -
				    i.clientHeight/2
				i.style.visibility = 'visible'
			}

			var MOD_THUMB = 0
			var MOD_SEL = 1
			var actionMode = MOD_THUMB
			var selIm = []
			var albums = []

			function startSel(type) {
				resetSel()
				actionMode = MOD_SEL
			}

			function selectIm(alnam, im) {
				if (deselectIm(alnam, im))
					return
				selIm.push([alnam, im])
				var o = getObj(im)
				o.className += ' sel '
			}

			function deselectIm(alnam, im) {
				for (var i = 0; i < selIm.length; i++) {
					if (selIm[i][0] == alnam &&
					    selIm[i][1] == im) {
						selIm.splice(i, 1)
						var o = getObj(im)
						var s = o.className
						o.className = s.replace(/\bsel\b/, '')
						return 1
					}
				}
				return 0
			}

			function resetSel() {
				while (selIm.length > 0)
					deselectIm(selIm[0][0], selIm[0][1])
			}

			function doAction(alnam, im, tags, caps) {
				if (actionMode == MOD_THUMB)
					thumbFocus(alnam, im, tags, caps)
				else if (actionMode == MOD_SEL)
					selectIm(alnam, im)
			}

			function gatherIm(f) {
				for (var i in selIm) {
					var e = document.createElement('input')
					e.name = 'im'
					e.type = 'hidden'
					e.value = selIm[i][1]
					f.appendChild(e)
				}
				//alert(f.innerHTML)
			}

			function batchClear() {
				resetSel()
				actionMode = MOD_THUMB
				getObj('batch').innerHTML = ''
			}

			function batchTag(al) {
				if (actionMode == MOD_SEL) {
					batchClear()
					return
				}

				startSel()

				var o = getObj('batch')
				o.innerHTML =
				    ':&nbsp; <form action="?" onsubmit="gatherIm(this)">' +
				       '<input type="hidden" name="act" value="tag" />' +
				       '<input type="hidden" name="album" value="' + al + '" />' +
				       '<input type="text" name="tag" />' +
				    '</form>'
			}

			function promptNew(o) {
				var lo = o.options[o.length - 1]
				if (o.selectedIndex == o.length - 1)
					lo.value = lo.text =
					    prompt('New album name:')
				else
					lo.value = lo.text = 'new...'
			}

			function moveIm(al) {
				if (actionMode == MOD_SEL) {
					submit;
					return
				}

				startSel()

				var opts = ''
				for (i in albums)
					if (al != albums[i])
						opts += '<option>' + albums[i] + '</option>'
				opts += '<option>new...</option>'

				var o = getObj('move')
				o.innerHTML =
				    '<form action="?" onsubmit="gatherIm(this)">' +
				       '<input type="hidden" name="act" value="move" />' +
				       '<input type="hidden" name="from" value="' + al + '" />' +
				       '<select name="to" onchange="promptNew(this)">' +
				       opts +
				       '</select>' +
				       '<input type="submit" value="Go" />' +
				    '</form>'
			}

			function searchPrompt() {
				var o = getObj('focus')
				o.style.display = 'block'
				o.innerHTML =
				    '<span onclick="cancelBubble(event)">' +
				     '<form action="?">' +
					'<input type="hidden" name="act" value="search" />' +
					'<br />' +
					'search tags:<br />' +
					'<input type="text" name="q" />' +
				     '</form>' +
				    '</span>'
			}
		</script>
	</head>
	<body>
EOF
$prhd = 1;

my %albums = loadalbum($DIR, 1);

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
		cachedata("$DIR/$alnam/$FN_THUMBS/$FN_IDX", $ad);
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
		mkdir("$path_t/$FN_THUMBS");
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
		unlink("$path_f/$FN_THUMBS/$im");
	}
	cachedata("$DIR/$t_a/$FN_THUMBS/$FN_IDX", $t_ad);
	cachedata("$DIR/$f_a/$FN_THUMBS/$FN_IDX", $f_ad);
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
