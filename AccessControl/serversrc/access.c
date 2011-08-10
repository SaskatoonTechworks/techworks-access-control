#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <sys/types.h>
#include <linux/input.h>
#include <termios.h>
#include <signal.h>
#include <time.h>
#include <string.h>

#define MAX_CODE_LEN 15 /*completely arbitrary*/
#define WHITELIST_FILE "/home/kaldonis/accesscontrol/whitelist.txt" /*terrible location for this file*/

#define DOOR_DEVICE "/dev/ttyACM"

#define LOG_FILE "/var/log/access.log"

int dd;
int deviceNumber;

char device[12];
char *code;

int connectToDevice()
{
	deviceNumber = 0;
	do
	{
		if(deviceNumber==100)
		{
			sleep(1);
			deviceNumber = 0;	
		}
		sprintf(device,"%s%d",DOOR_DEVICE,deviceNumber);		
		printf("Trying to open device at %s\n",device);
		dd = open(device, O_RDWR | O_NOCTTY);
		deviceNumber++;
	} while(dd==-1);

	if(dd==-1)
		return 1;
	else
		return 0;
}

char *readSerial()
{
        int rv,res = 0;
	fd_set set;
        char *buffer = (char*) malloc(255*sizeof(char));
	struct timeval timeout;

        do
        {
		timeout.tv_sec = 1; /*one second timeout waiting for data*/
		timeout.tv_usec = 0;
                memset(buffer,0,255);
		FD_ZERO(&set);
		FD_SET(dd,&set);
        	rv = select(dd+1,&set,NULL,NULL,&timeout);
		//printf("rv:%d\n",rv);
		if(rv==-1)/*error, reconnect to device*/
		{
			connectToDevice();
			continue;
		}
		else if(rv==0)/*timeout, keep waiting*/
		{
			printf("still waiting...\n");
			continue;
		}
		else
		{
	                res = read(dd,buffer,255);
			printf("Read: (%s)\n",buffer);
			if(buffer[0]==0) /*read a null string, means device disconnected or something*/
			{
				connectToDevice();
				continue;
			}
		}
        } while (buffer[0]==':' || res < 2); /*silly hack to get around read being stupid - Jeremy*/

        buffer[res-1] = 0;

        //printf("read: %s\n",buffer);

        return buffer;
}

void daemonize()
{
        int i,lfp;
        char str[10];

        if(getppid()==1) return;
	i=0;
        i=fork();
        if (i<0) exit(1); /* fork error */
        if (i>0) exit(0); /* parent exits */
        /* child (daemon) continues */
        setsid(); /* obtain a new process group */
        for (i=getdtablesize();i>=0;--i) close(i); /* close all descriptors */
        i=open("/dev/null",O_RDWR); dup(i); dup(i); /* handle standard I/O */
        umask(027); /* set newly created file permissions */

        /* first instance continues */

        signal(SIGCHLD,SIG_IGN); /* ignore child */
        signal(SIGTSTP,SIG_IGN); /* ignore tty signals */
        signal(SIGTTOU,SIG_IGN);
        signal(SIGTTIN,SIG_IGN);
}

/* this could definitely be set up better... ideally i'd like
 * to see the access logging going to a separate file than any
 * of the other log messages just for ease of parsing into a db
 * - Jeremy
 */
void log_access(char *message) 
{
        FILE *logfile;
        time_t ltime;
        struct tm *tm;

        ltime = time(NULL);
        tm = localtime(&ltime);

        logfile=fopen(LOG_FILE,"a");
        if(!logfile) return;
        fprintf(logfile,"%02d/%02d/%02d %02d:%02d:%02d - %s - %s",tm->tm_year+1900,tm->tm_mon+1,tm->tm_mday,tm->tm_hour,tm->tm_min,tm->tm_sec,code,message);
        fclose(logfile);
}

int openDoor(char* code)
{
        int x;
        FILE *whitelist;
        char validCode[64];
        char* serialMsg;

        //printf("%d\n",code);

        if((whitelist = fopen(WHITELIST_FILE,"r"))==NULL)
        {
                log_access("FAILED TO OPEN WHITELIST\n");
                return 1;
        }

        while(fscanf(whitelist,"%s",&validCode)!=EOF)
        {
                //printf("tried:%s correct:%s\n",code,validCode);
                if(strcmp(code, validCode) == 0)
                {
                        x = write(dd, "12345\r", 6);
                        if(x<0)
                        {
                                log_access("GOOD CODE, WRITE FAIL\n");
                                fclose(whitelist);
                                return 1;
                        }
                        else
                        {

                                log_access("SUCCESS\n");
                                fclose(whitelist);
                                return 0;
                        }
                }
        }

        //printf("Code failed\n");
        x = write(dd,"54321\r",6);
        if(x<0)
                log_access("INVALID CODE, WRITE FAIL\n");
        else
                log_access("INVALID CODE\n");

        fclose(whitelist);

        return 1;
}

int main()
{
        struct input_event ev;
        struct termios options;
        int x;

        daemonize();

	connectToDevice();
        sleep(3);

        /* set serial options, not sure what some of this does
         * I just copied it from somewhere -Jeremy
         */

        tcgetattr(dd,&options);
        bzero(&options,sizeof(options));

        options.c_cflag = B115200 | CS8 | CLOCAL | CREAD;
        options.c_iflag = IGNPAR | ICRNL;
        options.c_oflag = 0;
        options.c_lflag = ICANON;

        options.c_cc[VINTR]    = 0;     /* Ctrl-c */
        options.c_cc[VQUIT]    = 0;     /* Ctrl-\ */
        options.c_cc[VERASE]   = 0;     /* del */
        options.c_cc[VKILL]    = 0;     /* @ */
        options.c_cc[VEOF]     = 4;     /* Ctrl-d */
        options.c_cc[VTIME]    = 50;     /* inter-character timer unused 
*/
        options.c_cc[VMIN]     = 0;
        options.c_cc[VSWTC]    = 0;     /* '\0' */
        options.c_cc[VSTART]   = 0;     /* Ctrl-q */
        options.c_cc[VSTOP]    = 0;     /* Ctrl-s */
        options.c_cc[VSUSP]    = 0;     /* Ctrl-z */
        options.c_cc[VEOL]     = 0;     /* '\0' */
        options.c_cc[VREPRINT] = 0;     /* Ctrl-r */
        options.c_cc[VDISCARD] = 0;     /* Ctrl-u */
        options.c_cc[VWERASE]  = 0;     /* Ctrl-w */
        options.c_cc[VLNEXT]   = 0;     /* Ctrl-v */
        options.c_cc[VEOL2]    = 0;     /* '\0' */

        tcflush(dd,TCIFLUSH);
        tcsetattr(dd,TCSANOW,&options);

        while(1)
        {
                code = readSerial();

                if(openDoor(code)==0)
                        sleep(1); /*sleep for 4 seconds on successful code, not really necessary*/
                free(code);
        }

        return 0;
}
