CSS="/menu.css"
POSTS={2020,2019,2018}/*.md


.PHONY: all
all: index.html 404.html posts.html

%.html: %.md
	./render.sh -s $(CSS) <$< >$@

posts.html: 2018/*.md 2019/*.md 2020/*.md
	make -e CSS="/post.css" $$(ls $(POSTS) |sed 's/.md/.html/')
	ls $(POSTS) |sort -r |./posts.sh |./render.sh -s "/menu.css" >$@

.PHONY: clean
clean:
	rm -f *.html {2018,2019,2020}/*.html
	rm -rf out

out:
	mkdir -p out
	find . -path './20??*' -type d -exec mkdir -p out/{} \;
	find . \( \( -path './out*' -o -path './draft*' \) -prune -o -name '*.html' \) -type f -exec cp {} out/{} \;
