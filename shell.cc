#include <cstdio>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#include "shell.hh"

int yyparse(void);
extern int lastbackpid;
void Shell::prompt() {
  if( isatty(0) ){
	printf("myshell>");
  fflush(stdout);
  }
}

extern "C" void ctrlc(int sig){
	printf("\n");
	if (Shell::_currentCommand._left > 0){
		Shell::_currentCommand.clear();
	}else{
		Shell::prompt();
	}
}

void zombie(int sig){
	int pid = waitpid(-1, 0, 0);
	while ( pid!= -1){
		pid = waitpid(-1, NULL, WNOHANG);
		if (Shell::_currentCommand._background) {
                       printf("[%ld] exited.\n", (long)getpid());
		       //Shell::prompt();
		       //return;
		}
	}
}

int main() {
	struct sigaction sa;
	sa.sa_handler = ctrlc;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = SA_RESTART;
	if (sigaction(SIGINT, &sa, NULL)){
		perror("sigaction");
		exit(2);
	}
	struct sigaction ch;
	ch.sa_handler = zombie;
	sigemptyset(&ch.sa_mask);
	ch.sa_flags = SA_RESTART;
	if (sigaction(SIGCHLD, &ch, NULL)){
                perror("sigaction");
                exit(2);
        }
  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
