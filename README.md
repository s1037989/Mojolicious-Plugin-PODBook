$ perl -Mlib=lib -Mojo -E 'plugin "PODBook"; app->podbook("/perldoc", ["h1#GUIDES + dl dt > a[href]", "h1#REFERENCE + p + ul li > p > a[href]"], "div#wrapperlicious")' > mojolicious-5.44.html 
