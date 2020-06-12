%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
#define YYSTYPE char*
#define NUM_COMMANDS 15
#define NUM_ARGS 5


char command_chain[256];
int cmd_i,arg_j;
char *cmds[NUM_COMMANDS][NUM_ARGS];
_Bool cmd_bckgrnd;
_Bool outputFile;
_Bool stdErrFile;
_Bool stdErrOut[NUM_COMMANDS];
char nameOutputFile[256];


extern int yylex();
void yyerror(const char *s);
void addCmd(char *nombre);
void addArg(char *nombre);
void addOutputFile(char *nombre);
void executeCommand();
void print_Cmd_Matrix();

%}

%token PIPE RS RSE RSES NOMBRE NL BG EXIT IS RSC

%%

command_list: /* nothing */
	| command_list NL
	| command_list comandos NL {executeCommand();};

comandos: comando
        | comando BG {cmd_bckgrnd=0;}
        | comando PIPE comandos
        | comando RS output_file
        | RS output_file
        | comando RSE { stdErrFile=0; } output_file
        | RSE { stdErrFile=0; } output_file
        | comando RSES PIPE { stdErrOut[cmd_i] = 0;} comandos
        ;


output_file:
        NOMBRE { strcpy(command_chain,$1); $$=command_chain;
                  addOutputFile($1);} comandos
        | NOMBRE { strcpy(command_chain,$1); $$=command_chain;
                   addOutputFile($1);}
        ;


comando:
          NOMBRE { strcpy(command_chain,$1); $$=command_chain;
                  addCmd($1);}
         | comando NOMBRE { sprintf(command_chain,"%s %s",command_chain,$2);
                            $$=command_chain; addArg($2);}
         | EXIT {exit(0);}
         ;


%%


#include <stdio.h>
char *progname;

void addCmd(char *nombre){
  cmd_i=cmd_i+1;
  cmds[cmd_i][0] = nombre;
  arg_j = 0;
}

void addArg(char *nombre){
  arg_j=arg_j+1;
  cmds[cmd_i][arg_j] = nombre;
}

void addOutputFile(char *nombre){
  outputFile = 0;
  strncpy(nameOutputFile, nombre, 256);
}


void print_Cmd_Matrix(){
  int i,j;
  printf("cmd_i: %d  \n",cmd_i);

  for(i=0;i<NUM_COMMANDS;i++){
    for(j=0;j<NUM_ARGS;j++){
      printf(" %s ",cmds[i][j]);
    }
    printf("\n");
  }

  for(i=0;i<NUM_COMMANDS;i++){
    printf("\%d", stdErrOut[i]);
    printf("\n");
  }
}

void executeCommand(){

  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2);

  int fdin;
  fdin = dup(tmpin);

  /*Inicio de iteracion de comandos*/
  int ret;
  int fdout;
  int i;
  for(i=0;i<=cmd_i;i++){
    dup2(fdin, 0);
    close(fdin);

    /*Validación del último comando*/
    if(i == cmd_i){
      if(outputFile ==0){
        fdout = open(nameOutputFile, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (stdErrFile==0){
          dup2(fdout, 2);
        }
      }else{
        fdout=dup(tmpout);
      }
    }
    else{
      /*Comando regular*/
      int fdpipe[2];
      int resPipe;
      resPipe = pipe(fdpipe);

      fdin = fdpipe[0];
      fdout = fdpipe[1];
    }

    dup2(fdout, 1);
    if(stdErrOut[i]==0){
      dup2(fdout,2);
    }

    /*Proceso hijo*/
    ret = fork();
    if(ret == 0){
      close(fdin);
      execvp(cmds[i][0], cmds[i]);
      perror("execvp");
      exit(1);
    }else if( ret > 0){
       close(fdout);
       waitpid(ret,NULL,0);
       close(fdout);
       close(2);
    }
  }

  /*Restablecimiento de stdout y stderror*/
  dup2(tmpin,0);
  dup2(tmpout,1);
  dup2(tmperr,2);
  close(tmpin);
  close(tmpout);
  close(tmperr);

  /*Si el proceso está en foreground*/
  if(cmd_bckgrnd!=0){
    waitpid(ret,NULL,0);
  }

	int m,k;

  for(m=0;m<NUM_COMMANDS;m++){
    stdErrOut[m] = 1;
		/*Reestablecimiento de matriz de comandos y argumentos*/
    for(k=0;k<NUM_ARGS;k++){
      cmds[m][k] = NULL;
    }
  }
	/*1 = background*/
	cmd_bckgrnd = 1;
	/*Archivo de salida*/
	outputFile = 1;
	/*Redirección al error*/
	stdErrFile = 1;
	strncpy(nameOutputFile, "", 256);
	/*Número de Comando*/
	cmd_i = -1;
	/*Número de argumento*/
	arg_j = 0;
	/*Formato para nuevas líneas*/
	printf(" > ");

}



int main( int argc, char *argv[] )
{
  printf("WELCOME \n");
  printf("End the session with 'exit' \n" );

	int i,j;

	for(i=0;i<NUM_COMMANDS;i++){
		stdErrOut[i] = 1;
		for(j=0;j<NUM_ARGS;j++){
			cmds[i][j] = NULL;
		}
	}

	cmd_bckgrnd = 1;
	outputFile = 1;
	stdErrFile = 1;
	strncpy(nameOutputFile, "", 256);
	cmd_i = -1;
	arg_j = 0;
	printf(" > ");


  progname = argv[0];
  yyparse();
  return 0;
}

void yyerror (const char * s )
{
  fprintf( stderr ,"%s: %s\n" , progname , s );
}
