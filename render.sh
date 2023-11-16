#!/bin/sh

usage() {
	echo "usage: render.sh [ -s CSS ]*"
}

title=""
created=""

while case "$1" in
-t) type="$2"; shift 1;;
*) false;;
esac; do shift; done

meta() {
	echo "$1" |sed 's/<[^>]*>//g'
}

prettydate() {
	if [ $# -lt 1 ]; then read date; else date=$1; fi
	y=$(echo "$date" |cut -d'-' -f1)
	m=$(echo "$date" |cut -d'-' -f2)
	d=$(echo "$date" |cut -d'-' -f3)
	m=$(printf "Jan\nFeb\nMar\nApr\nMay\nJun\nJul\nAug\nSep\nOct\nNov\nDec\n" |sed -n ${m}p)
	d=$(echo "$d" |sed 's/^0//')
	echo "$y $m $d"
}

while { if [ -z "$nometa" ]; then read line; else false; fi; } do
	case "$line" in
	'<pmeta id="title">'*) title=$(meta "$line") ;;
	'<pmeta id="created">'*) created=$(meta "$line") ;;
	'<pmeta id="updated">'*) updated=$(meta "$line") ;;
	"<pmeta"*) echo ">> some other pmeta: $(meta "$line")" >&2 ;;
	*) nometa=1;;
	esac
done
if [ -n "$updated" ]; then modified=$updated; else modified=$created; fi

cat <<HEADER
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<link href="/f/Nunito.css" rel="stylesheet">
<link href="/feed.xml" type="application/atom+xml" rel="alternate" title="Blog Atom feed" />
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🤔</text></svg>">
HEADER

case "$type" in
person)
cat <<LDJSON
<script type="application/ld+json">
{ "@context": "http://schema.org"
, "@type": "Person"
, "name": "Joshua Lloret"
}
</script>
LDJSON
;;
post)
cat <<LDJSON
<script type="application/ld+json">
{ "@context": "http://schema.org"
, "@type": "BlogPosting"
, "headline": "$title"
, "author": {"@type": "Person", "name": "Joshua Lloret"}
, "datePublished": "$created"
, "dateModified": "$modified"
}
</script>
LDJSON
;;
esac

while [ $# -gt 0 ]; do
	case "$1" in
	"-s")
		echo '<link rel="stylesheet" type="text/css" href="'"$2"'" >'
		shift 2
		;;
	*)
		echo "Unrecognized option $1" >&2
		usage
		exit 1
		;;
	esac
done

[ -n "$title" ] && echo "<title>$title</title>"

cat <<HEADER
</head>
<body>
<div>
HEADER

echo "<header>"
if [ -n "$created" ]; then
	echo -n "	<created>$(prettydate "$created")"
	[ -n "$updated" ] && echo -n "<br/><i>updated: $(prettydate "$updated")</i>"
	echo "</created>"
fi
[ -n "$title" ] && echo "	<ptitle><h1>&gt;&nbsp;$title</h1></ptitle>"
echo "</header>"

signature='**-<a href="https://isthisa.website" rel="author">JD</a>**'
(echo "$line"; cat; [ "$type" = "post" ] && printf "\n%s" "$signature") |pulldown-cmark

cat <<FOOTER
</div>
</body>
</html>
FOOTER
