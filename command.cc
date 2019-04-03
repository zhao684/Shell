/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <sys/types.h>
#include <unistd.h>
#include <sys/wait.h>
#include <iostream>
#include <string>
#include <cstring>
#include <fcntl.h>
#include <vector>
#include "command.hh"
#include "shell.hh"

extern char **environ;
std::string prevcommand;

Command::Command() {
	// Initialize a new vector of Simple Commands
	_simpleCommands = std::vector<SimpleCommand *>();

	_over = false;
	_outFile = NULL;
	_inFile = NULL;
	_errFile = NULL;
	_background = false;
	_left = -1;
	_status = -1;
	_lastback = -1;
}

std::string Command::getLast(){
	return prevcommand;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
	// add the simple command to the vector
	_simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
	// deallocate all the simple commands in the command vector
	for (auto simpleCommand : _simpleCommands) {
		delete simpleCommand;
	}

	// remove all references to the simple commands we've deallocated
	// (basically just sets the size to 0)
	_simpleCommands.clear();

	if ( _outFile && _outFile != _inFile && _outFile != _errFile) {
		delete _outFile;
	}
	_outFile = NULL;

	if ( _inFile && _inFile != _errFile) {
		delete _inFile;
	}
	_inFile = NULL;

	if ( _errFile ) {
		delete _errFile;
	}
	_errFile = NULL;

	_over = false;

	_background = false;

	_left = -1;
}

void Command::print() {
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");

	int i = 0;
	// iterate over the simple commands and print them nicely
	for ( auto & simpleCommand : _simpleCommands ) {
		printf("  %-3d ", i++ );
		simpleCommand->print();
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n",
			_outFile?_outFile->c_str():"default",
			_inFile?_inFile->c_str():"default",
			_errFile?_errFile->c_str():"default",
			_background?"YES":"NO");
	printf( "\n\n" );
}

void Command::execute() {
	// Don't do anything if there are no simple commands
	if ( _simpleCommands.size() == 0 ) {
		std::cout<<"here"<<std::endl;
		Shell::prompt();
		return;
	}
	_left = _simpleCommands.size();
	// Print contents of Command data structure
	//	print();
	//save default input
	int defin = dup(0);
	int defout = dup(1);
	int deferr = dup(2);
	int fdin;
	int fdout;
	int fderr;
	if(_inFile){
		fdin = open(_inFile->c_str(),O_RDONLY, 666);
	}else{
		fdin = dup(defin);
	}
	if(_errFile){
		if(_over){
			//		fderr = creat(_errFile->c_str(), 666);
			fderr = open(_errFile->c_str(), O_RDWR|O_CREAT|O_TRUNC, 0666);
		}else{
			fderr = open(_errFile->c_str(), O_RDWR|O_CREAT|O_APPEND, 0666);
		}
	}else{
		fderr = dup(deferr);
	}
	// Add execution here
	int ret;
	if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(),"exit")){
		printf("Bye!\n");
		_exit(0);
	}

	for (unsigned i = 0; i < _simpleCommands.size(); i++) {
		//redirect input
		dup2(fdin,0);
		close(fdin);

		if(i == _simpleCommands.size()-1){
			if(_outFile){
				if(_over){
					fdout = open(_outFile->c_str(), O_RDWR|O_CREAT|O_TRUNC, 0666);
				}else{
					fdout = open(_outFile->c_str(), O_RDWR|O_CREAT|O_APPEND, 0666);
				}
			}else{
				fdout = dup(defout);
			}
		}else{
			// pipe 
			int fdpipe[2];
			if ( pipe(fdpipe) == -1){
				perror("pipe");
				exit(2);
			}
			fdout = fdpipe[1];
			fdin = fdpipe[0];
		}
		dup2(fdout, 1);
		close(fdout);
		dup2(fderr, 2);
		close(fderr);


		std::vector<char*> chararg{};
		for(unsigned j = 0; j < _simpleCommands[i]->_arguments.size(); j++){
			chararg.push_back(const_cast<char*>(_simpleCommands[i]->_arguments[j]->c_str()));
			prevcommand = _simpleCommands[i]->_arguments[j][0];
		}
		chararg.push_back(nullptr);
		// fork
		if(!strcmp(chararg.data()[0], "cd")){
			//prevcommand = "cd";
			int done = -1;
			if(chararg.size() > 2){
				done = chdir(chararg.data()[1]);
			}
			if(chararg.size() == 2){
				done = chdir(getenv("HOME"));
			}
			if(done == -1){
				fprintf(stderr, "cd: can't cd to %s\n", chararg.data()[1], strerror(errno)); 
			}
			ret = 1;
		}else if(!strcmp(chararg.data()[0], "setenv")){
				//prevcommand = "setenv";
				setenv(chararg.data()[1], chararg.data()[2], 1);
				ret = 1;
		}else if(!strcmp(chararg.data()[0], "unsetenv")){
				//prevcommand = "unsetenv";
				unsetenv(chararg.data()[1]);
				ret = 1;
		}else{
			ret = fork();
		}
		// excute command
		if (ret < 0){
			perror("fork");
			exit(2);
		}else if (ret == 0){
			if (!strcmp(chararg.data()[0], "printenv")){
				//prevcommand = "printenv";
				char ** env = environ;
				while(*env!=NULL){
					printf("%s\n", *env);
					env++;
				}
				exit(0);
			}else{
				//prevcommand = chararg.data()[0];
					execvp(_simpleCommands[i]->_arguments[0]->c_str(), chararg.data());
				_left --;
				perror("execvp");
				_exit(1);
			}
		}else{
			//waitpid(ret,NULL,0);
		}
	}
	dup2(defin, 0);
	dup2(defout, 1);
	dup2(deferr, 2);
	close(defin);
	close(defout);
	close(deferr);
	close(fdin);
	close(fdout);
	close(fderr);
	if(!_background){
		int status;
		waitpid(ret,&status,0);
		_status = WEXITSTATUS(status);
	}else{
		_lastback = ret;
	}
	// For every simple command fork a new process
	// Setup i/o redirection
	// and call exec
	//prevcommand = _simpleCommands[_simpleCommands.size()]->_arguments[_simpleCommands[_simpleCommands.size()-1]->_arguments.size()-1][0];
	// Clear to prepare for next command
	clear();
	// Print new prompt
	Shell::prompt();

}

SimpleCommand * Command::_currentSimpleCommand;
