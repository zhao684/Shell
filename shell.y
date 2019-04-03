
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <string.h>
#include <regex.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <iostream>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE GREATGREAT PIPE AMPERSAND LESS GREATAMPERSAND GREATGREATAMPERSAND ERRORGREAT

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include "command.hh"

void yyerror(const char * s);
int yylex();

void expandWildCardsIfNecessary(std::string * arg);
void expandWc(std::string * prefix, std::string * suffix);

%}

%%
goal:
    commands
  ;

commands:
	command
  | commands command
  ;

command:
       command_line
  ;

command_line:
	    pipe_list io_modifier_list background_opt NEWLINE{
   // printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE
  | error NEWLINE{ yyerrok; }
  ;

/*         Pipe*/
pipe_list:
	 pipe_list PIPE command_and_args
  | command_and_args 
  ;

command_and_args:
		command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

command_word:
	    WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;
argument_list:
	     argument_list argument
  | /* can be empty */
  ;

argument:
	WORD {
   // printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
   //Command::_currentSimpleCommand->insertArgument( $1 );
   if(strcmp(Command::_currentSimpleCommand->_arguments[0]->c_str(), "echo") == 0 && strchr($1->c_str(), '?')){
		Command::_currentSimpleCommand->insertArgument( $1 );
   }else{
		expandWildCardsIfNecessary($1);
   }

}
  ;

/*                io modifier*/
io_modifier_list:
		io_modifier_list io_modifier
  | /*empty*/
  ;


io_modifier:
	   GREATGREAT WORD {
   // printf("   Yacc: insert gg output \"%s\"\n", $2->c_str());
if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._over = false;
  }
  | GREAT WORD {
   // printf("   Yacc: insert g output \"%s\"\n", $2->c_str());
    if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._over = true;
  }
  | GREATAMPERSAND WORD {
  //  printf("   Yacc: insert ga output \"%s\"\n", $2->c_str());
if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._over = true;
  }
  | GREATGREATAMPERSAND WORD{
if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
    //printf("   Yacc: insert gga output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._over = false;
  }
  | LESS WORD{
if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
   // printf("   Yacc: insert l output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | ERRORGREAT WORD{
if(Shell::_currentCommand._outFile != NULL){
	printf("Ambiguous output redirect.\n");
	exit(2);
    }
   // printf("   Yacc: insert er output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._over = true;
  }
  ;

/*         background */
background_opt:
	      AMPERSAND {
    Shell::_currentCommand._background = true;
  }
  | /*empty*/
  ;


%%

int maxEntries = 20;
int nEntries = 0;
char ** entries;

int cmpfunc (const void *file1, const void *file2) {
	const char *_file1 = *(const char **)file1;
	const char *_file2 = *(const char **)file2;
	return strcmp(_file1, _file2);
}

void expandWildCardsIfNecessary(std::string * arg) {
	
	maxEntries = 20;
	nEntries = 0;
	entries = (char **) malloc (maxEntries * sizeof(char *));

	if (arg->find('*') != std::string::npos || arg->find('?') != std::string::npos) {
		expandWc(NULL, arg);
		qsort(entries, nEntries, sizeof(char *), cmpfunc);
		//std::cout<<arg[0]<<std::endl;
		for (int i = 0; i < nEntries; i++){
			std::string ts(entries[i]);
			if(arg[0]!="*" && arg[0]!=".*"){
				ts = '/' + ts;
			}
			std::string * temp = new std::string(ts.c_str());
			
			//std::cout<<i<<" "<<entries[i]<<" "<<std::endl;
			Command::_currentSimpleCommand->insertArgument(temp);
		}
	
	}else{
		Command::_currentSimpleCommand->insertArgument(arg);
	}
	return;
}

void expandWc(std::string * prefix, std::string * suffix){
	if (suffix->length() == 0 || suffix == NULL) {
		if(nEntries == maxEntries){
			maxEntries *= 2;
			entries = (char **) realloc (entries, maxEntries * sizeof(char *));
		}
		
		//if ( prefix != NULL && prefix->length() != 0 ) {
			//std::string p(prefix->c_str());
		entries[nEntries] = (char*)prefix->c_str();
			//std::cout<<entries[nEntries]<<" "<<std::endl;
		nEntries++;
		//}
		/*for (int i = 0; i < nEntries; i++){
			std::cout<<entries[i]<<"\t";
		}
		std::cout<<std::endl;*/
		//Command::_currentSimpleCommand->insertArgument(prefix);
		return;
	}
	//take out the a from /a/b/c/d
	
	std::string fdir;
	std::string temp(suffix->c_str());
	int flag = 0;
	if(suffix[0][0]=='/'){
		temp.erase(0,1);
		//flag = 1;
	}
	int found = temp.find('/');
	if(found!= std::string::npos){
		fdir=temp.substr(0,found);
		temp=temp.substr(found+1);
	}else{
		fdir=temp;
		temp = "";
	}
	std::string myprefix;
	//std::cout<<"prefix "<<prefix->c_str()<<std::endl;
	if (!prefix && suffix[0][0] == '/') {
		myprefix = "/";
	} else if(!prefix){
		myprefix = "";
	}
	else{
		std::string ttt(prefix->c_str());
		myprefix = ttt;
	}
	//std::cout<<"prefix: "<<myprefix<<" suffix: "<<suffix[0]<<std::endl;
	//std::cout<<"fdir: "<<fdir<<" temp: "<<temp<<std::endl;
	//do not need to expand
	if (fdir.find('*') == std::string::npos && fdir.find('?') == std::string::npos){
		
		if ( prefix == NULL || prefix->length() == 0 ) {
			std::string * fdir1 = new std::string(fdir);
			std::string * temp1 = new std::string(temp);
			expandWc(fdir1, temp1);
		} else {
			std::string p(prefix->c_str());
			p = p+"/"+fdir;
			std::string * p1 = new std::string(p);
			std::string * temp1 = new std::string(temp);
			expandWc(p1, temp1);
		}
		return;
	}
	
	//need to expand
	char * reg = (char*)malloc(2*suffix->length()+10);
	char * a = (char*)fdir.c_str();
	char * r = reg;
	*r = '^'; r++; // match beginning of line
	while (*a) {
		if (*a == '*') { *r='.'; r++; *r='*'; r++; }
		else if (*a == '?') { *r='.'; r++;}
		else if (*a == '.') { *r='\\'; r++; *r='.'; r++;}
		else { *r=*a; r++;}
		a++;
	}
	*r='$'; r++; *r=0;// match end of line and add null char
	// compile regex
	regex_t re;
	if ( regcomp(&re, reg, REG_EXTENDED|REG_NOSUB) != 0 ) {
		perror("regcomp");
		exit(1);
	}
	char* dName;
	if(myprefix.length() == 0){
		dName = (char*)".";
		flag = 1;
	}else{
		dName = (char*)myprefix.c_str();
	}
	std::string act(dName);
	if(flag == 0){
	act = "/" + act;
	}
	//std::cout<<"here"<<std::endl;
	//std::cout<<"dir"<<act<<std::endl;
	// open the directory
	DIR * dir = opendir(act.c_str());
	if (dir == NULL) {
		return;
	}
	//std::cout<<"here "<<act<<std::endl;
	struct dirent * ent;
	regmatch_t match;
	while ( (ent = readdir(dir)) != NULL ) {
		if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
			char * send = (char*)malloc(128);
			
			if (prefix == NULL || prefix->length() == 0) {
				sprintf(send, "%s", ent->d_name);
			} else {
				sprintf(send, "%s/%s", prefix->c_str(), ent->d_name);
			}
			
			std::string pass(send);
			std::string * p1 = new std::string(pass);
			std::string * temp1 = new std::string(temp);
			if (ent->d_name[0] == '.') { 
				if (fdir[0] == '.') {
					expandWc(p1, temp1);
				}
			}else {
				expandWc(p1, temp1);
			}
			
		}
	}
	closedir(dir);
}

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}


#if 0
main()
{
  yyparse();
}
#endif
