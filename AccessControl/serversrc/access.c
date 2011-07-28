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

#define DOOR_DEVICE "/dev/ttyUSB0" /*this will need to be USB0 if we switch back to seeeduino*/
#define DOOR_MODE "0666" /*can probably be tighter than this, only needs to be read and written to by daemon*/

#define LOG_FILE "/var/log/access.log"

int door;
char *code;

char *readSerial()
{
        int res;
        char *buffer = (char*) malloc(255*sizeof(char));

        do
        {
                memset(buffer,0,255);
                res = read(door,buffer,255);
        } while (buffer[0]==':' || res < 5); /*silly hack to get around read being stupid - Jeremy*/

        buffer[res-1] = 0;

        printf("read: %s\n",buffer);

        return buffer;
}

void daemonize()
{
        int i,lfp;
        char str[10];

        if(getppid()==1) return;
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

int openDoor(int code)
{
        int x;
        FILE *whitelist;
        int validCode;
        char* serialMsg;

        //printf("%d\n",code);

        if((whitelist = fopen(WHITELIST_FILE,"r"))==NULL)
        {
                log_access("FAILED TO OPEN WHITELIST\n");
                return 1;
        }

        while(fscanf(whitelist,"%d",&validCode)!=EOF)
        {
                printf("tried:%d correct:%d\n",code,validCode);
                if(code==validCode)
                {
                        x = write(door, "12345\r", 6);
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

        printf("Code failed\n");
        x = write(door,"54321\r",6);
        if(x<0)
                log_access("INVALID CODE, WRITE FAIL\n");
        else
                log_access("INVALID CODE\n");

        fclose(whitelist);

        return 1;
}

/*this may be completely unnecessary now that this is running as a daemon - Jeremy*/
void initializePermissions() 
{
        int dm = strtol(DOOR_MODE,0,8);

        if(chmod(DOOR_DEVICE, dm) < 0)
        {
                log_access("Error setting door device permissions. Are you root?\n");
                exit(1);
        }
}

int main()
{
        struct input_event ev;
        struct termios options;
        int x;

        initializePermissions();

        daemonize();

        door = open(DOOR_DEVICE, O_RDWR | O_NOCTTY | O_NDELAY);

        if(door==-1)
        {
                printf("Failed to open serial port\n");
                exit(1);
        }
        sleep(3);

        /* set serial options, not sure what some of this does
         * I just copied it from somewhere -Jeremy
         */

        tcgetattr(door,&options);
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
        options.c_cc[VTIME]    = 0;     /* inter-character timer unused */
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

        tcflush(door,TCIFLUSH);
        tcsetattr(door,TCSANOW,&options);

        while(1)
        {
                code = readSerial();

                if(openDoor(atoi(code))==0)
                        sleep(4); /*sleep for 4 seconds on successful code, not really necessary*/
                free(code);
        }

        return 0;
}