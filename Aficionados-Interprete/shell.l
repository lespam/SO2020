%{
#define YYSTYPE char *

#include <stdlib.h>
#include <string.h>
#include "y.tab.h"

%}
/*Definicion de tokens*/
%%

"2>&1" { return RSES; }
"2>" { return RSE;}
">>" { return RSC;}
">"  { return RS;}
"<"  { return IS; }
"|"  { return PIPE;}
"&"  { return BG;}
"exit" { return EXIT; }
[^><\&\|\ \t\n]* { yylval = strdup(yytext); return NOMBRE; };
[\ \t] ;
"\n" { return NL; }

%%
