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

window.onkeydown = function(e) {
	switch (e.keyCode) {
	case 27:
		hideFocus()
		break
	}
}
