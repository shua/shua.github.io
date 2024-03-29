.POSIX:

FIND_POSTS = find . -path './20??*'

.PHONY: all
all: posts.mk index.html 404.html posts.html feed.xml

include posts.mk

.PHONY: posts.mk
posts.mk:
	@{ \
		tmp=$$(mktemp); \
		{ \
		printf 'POSTS ='; \
		$(FIND_POSTS) '(' -iname '*.md' -o -iname '*.html' ')' \
			|sed 's/^\.\///; s/\.[a-z][a-z]*$$/.html/i' \
			|sort |uniq \
			|awk '{printf " \\\n\t%s", $$0}'; \
		printf "\n\n"; \
		} >$$tmp; \
		cmp $$tmp $@ || mv $$tmp $@; \
	}

.SUFFIXES: .md .html .xml .css
.md.html:
	./render.sh -t post <$< >$@

new_posts.md: $(POSTS)
	ls $(POSTS) |sort -r |head -n5 |./posts.sh embed >$@
index.html: index.md new_posts.md
	cat index.md new_posts.md |./render.sh -t person >$@
404.html: 404.md
	./render.sh <$< >$@

posts.html: $(POSTS)
	ls $(POSTS) |sort -r |./posts.sh |./render.sh -t menu >$@

feed.xml: $(POSTS)
	./feed.sh >$@

.PHONY: clean
clean:
	rm -f *.html {2018,2019,2020,2022,2023}/*.html feed.xml
	rm new_posts.md
	rm -rf pub

.PHONY: pub
pub:
	@echo "=> copy generated artifacts"
	@find . '(' -regex '\./pub\|./drafts\|./well-known\|.*/\..*' ')' -prune -o '(' \
		'(' \
			-type d -exec mkdir -p pub/{} ';' \
		')' , '(' \
			-type f -a \! '(' \
				-regex '.*/\.[^/]*\|.*\.md\|.*/Makefile\|.*\.mk' -o -executable \
			')' \
			-exec cp {} pub/{} ';' \
		')' \
	')'
	@rm -rf pub/.well-known && cp -R well-known pub/.well-known
