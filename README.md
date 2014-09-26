$ perl -Mlib=lib -Mojo -E 'plugin PODBook => {sections => ["h1#GUIDES + dl dt > a[href]", "h1#REFERENCE + p + ul li > p > a[href]"], text => "div#wrapperlicious"}; app->start' get /podbook > ~/Mojolicious-5.44.html
$ ./kindlegen ~/Mojolicious-5.44.html -o Mojolicious-5.44.mobi
$ wkhtmltopdf ~/Mojolicious-5.44.html ~/Mojolicious-5.44.pdf
