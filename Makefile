.POSIX:

FIND_POSTS = find . -path './20??*'

.PHONY: all
all: index.html 404.html posts.html feed.xml

include posts.mk

posts.mk:
	@{ \
	printf 'POSTS ='; \
	$(FIND_POSTS) '(' -iname '*.md' -o -iname '*.html' ')' \
		|sed 's/^\.\///; s/\.[a-z][a-z]*$$/.html/i' \
		|sort |uniq \
		|awk '{printf " \\\n\t%s", $$0}'; \
	printf "\n\n"; \
	} >$@

.SUFFIXES: .md .html .xml .css
.md.html:
	./render.sh -t post -s /post.css <$< >$@

new_posts.md: $(POSTS)
	ls $(POSTS) |sort -r |head -n5 |./posts.sh embed >$@
index.html: index.md new_posts.md
	cat index.md new_posts.md |./render.sh -t person -s /menu.css >$@
404.html: 404.md
	./render.sh -s /menu.css <$< >$@

posts.html: $(POSTS)
	ls $(POSTS) |sort -r |./posts.sh |./render.sh -s "/menu.css" >$@

feed.xml: $(POSTS)
	./feed.sh >$@

.PHONY: clean
clean:
	rm -f *.html {2018,2019,2020,2022}/*.html feed.xml
	rm new_posts.md
	rm -rf pub

pub/.git:
	@echo "=> init pub/.git"
	@mkdir -p pub; cp -R .git pub/.git; cd pub; git symbolic-ref HEAD refs/heads/pub
	@cd pub; git pull || echo "unable to fetch latest version of pub"

.PHONY: pub
pub: pub/.git
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
	@install -d ./well-known pub/.well-known
	@cd pub; git add .; git status
