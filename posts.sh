#!/bin/sh

title() {
	title=$(awk '/<pmeta id="title">/{ gsub(/<[^>]*>/, ""); print }' "$1")
	title=${title:-$(awk '/<title>/{ gsub(/<[^>]*>/, ""); print }' "$1")}
	if [ -n "$title" ]; then
		echo "$title"
	else
		echo "$1" |sed 's/\.md//g; s/^........-//g'
	fi
}

created() {
	created=$(awk '/<pmeta id="created">/{ gsub(/<[^>]*>/, ""); print }' "$1")
	created=${created:-$(awk '/<created>/{ sub(/<[^>]*>/, ""); sub(/<.*/, ""); print }' "$1")}
	echo "$created"
}

html() {
	echo "$1" |sed 's/\.md/.html/'
}

if [ "$1" != "embed" ]; then
cat <<HEADER
Some blog posts
===============

HEADER
else
echo "Some blog posts:"
fi

while read post; do
	echo "- $(created "$post") [$(title "$post")]($(html "$post"))"
done

if [ "$1" = "embed" ]; then
	echo "- [all...](posts.html)"
fi

