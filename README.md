$ perl -Mlib=lib -Mojo -E 'plugin "PODBook"; app->podbook("/perldoc", ["h1#GUIDES + dl dt > a[href]", "h1#REFERENCE + p + ul li > p > a[href]"], "div#wrapperlicious")' > ~/Mojolicious-5.44.html 
$ ./kindlegen ~/Mojolicious-5.44.html -o Mojolicious-5.44.mobi
$ wkhtmltopdf ~/Mojolicious-5.44.html ~/Mojolicious-5.44.pdf
