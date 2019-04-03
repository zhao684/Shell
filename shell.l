
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <iostream>
#include <string>
#include <vector>
#include <limits.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include "shell.hh"
#include "y.tab.hh"

extern int lastbackpid;
static  void yyunput (int c,char *buf_ptr  );
extern "C" char * read_line();


int mygetc(FILE * f) {
 static char *p;
 char ch;

 if (!isatty(0)) {
 // stdin is not a tty. Call real getc
   return getc(f);
 }

 // stdin is a tty. Call our read_line.
 if (p==NULL || *p == 0) {
   char * s = read_line();
   p = s;
 }

 ch = *p;
 p++;

 return ch;
}

#undef getc
#define getc(f) mygetc(f)

void myunputc(int c) {
  unput(c);
}

%}

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

">>" {
  return GREATGREAT;
}

"|" {
  return PIPE;
}

"&" {
  return AMPERSAND;
}

"<" {
  return LESS;
}

">&" {
  return GREATAMPERSAND;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"2>" {
  return ERRORGREAT;
}

\".*\"  {
  /* Assume that file names have only alpha chars */
//  char * temp;
  std::string temp = yytext;
  temp.erase(temp.begin());
  temp.erase(temp.end()-1);
  yylval.cpp_string = new std::string(temp);
  return WORD;
}


\$\(.*\) {
	//take off $()
	//std::cout<<"ha..."<<std::endl;
	std::string temp = yytext;
	//std::string word = "ol";
	std::string word = "";
	temp.erase(temp.begin(), temp.begin()+2);
    temp.erase(temp.end()-1);
	//set defult in/out
	
	int defout = dup(1);
	int fdout;
	
	//set up pipe and in/out
	int fdpipe[2];
	if ( pipe(fdpipe) == -1){
		perror("pipe");
		exit(2);
	}

	fdout = fdpipe[1];
	dup2(fdout,1);
	close(fdout);

	
	
	//split string in subshell
	int index = 0;
	
	//std::cout<<temp<<std::endl;
	std::vector<char*> chararg{};
	while((index = temp.find(" "))!=std::string::npos){
		std::string token = temp.substr(0,index);
		chararg.push_back(const_cast<char*>(token.c_str()));
		temp.erase(0, index+1);
	}
	chararg.push_back(const_cast<char*>(temp.c_str()));
	chararg.push_back(nullptr);
	
	//start process
	int ret = fork();
	
	if (ret == 0){
		execvp(chararg.data()[0], chararg.data());
		perror("execvp");
		_exit(1);
	}

	dup2(defout, 1);
	close(defout);
	waitpid(ret,NULL,0);
	
	//std::cout<<"I'm what in pipe:"<<std::endl;
	char s;

	while (read(fdpipe[0], &s, 1)) {
		if (s == '\n'){
			word+=" ";
		}else{
			word+=s;
		}
	}
	for(int i = word.length()-1; i>=0; i--){
		myunputc(word[i]);
	}
	//std::cout<<word;
	//yylval.cpp_string = new std::string(word);
	//return WORD;
}


((\\.)|[^ &<>|\t\n])+  {
  /* Assume that file names have only alpha chars */
 std::string temp = yytext;
 //escape
  bool prev = 1;
  for(int i = 0; i < temp.length(); i++){
    if (temp[i] == '\\'){
       if(prev){
	 temp.erase(i,1);
	 i--;
	 if(temp[i+1] == '\\'){
	   prev = 0;
	 }
       }else{
	 prev = 1;
       }
    }
  }
 //expend env
  std::string com = "";
  while(temp.length() > 0){
	if(temp[0] == '$' && temp[1] == '{' || temp.find('$')!=std::string::npos){
		if (temp[0] == '$'){
			temp.erase(0,2);
		}
		std::string dict = "";
		while(temp[0] != '}' && !(temp[0] == '$' && temp[1] == '{')){
			dict += temp[0];
			temp.erase(0,1);
		}
		if (temp[0] == '}'){
			if(dict.length() == 1){
				if(dict[0] == '$'){ //PID of shell process
					dict = std::to_string(getpid());
					com += dict;
				}else if(dict[0] == '?'){ //last executed simple command; may be in command.cc?
					dict = std::to_string(Shell::_currentCommand._status);
					com += dict;
				}else if(dict[0] == '!'){ // pid of last background process
					dict = std::to_string(Shell::_currentCommand._lastback);
					com += dict;
				}else if(dict[0] == '_'){ // last argument
					dict = Shell::_currentCommand.getLast();
					com += dict;
				}else{
					com += getenv(const_cast<char*>(dict.c_str()));
				}
			}else if (dict.length() == 5 && dict[0] == 'S'){
				char path[100];
				realpath("../shell",path);
				std::string p(path);
				com += p;
			}else{
				com += getenv(const_cast<char*>(dict.c_str()));
			}
			temp.erase(0,1);
		}else{
			com += dict;
		}
	}else{
		com += temp[0];
		temp.erase(0,1);
	}
  }
  //tilde

  if(com[0] == '~'){
  	if(com.length() == 1){
		com = getenv("HOME");
  	}else{
  		com.erase(0,1);
		com = "/homes/" + com;
 	 }
  }
  yylval.cpp_string = new std::string(com);
  return WORD;
}
