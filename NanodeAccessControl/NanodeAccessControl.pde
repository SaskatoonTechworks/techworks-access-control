// SD Card
#include <SdFat.h>

// EtherShield webserver demo
#include <EtherShield.h>
#include <NanodeMAC.h>

#define SDCARD_CS           10

// please modify the following two lines. mac and ip have to be unique
// in your local area network. You can not have the same numbers in
// two devices:
static uint8_t mymac[6] = {
  0x00,0x04,0xA3,0x2C,0x0F,0x93}; 

static uint8_t myip[4] = {
  192,168,0,222};
//  10,10,220,184};

#define MYWWWPORT 80
#define BUFFER_SIZE 550
static uint8_t buf[BUFFER_SIZE+1];
static uint8_t sdcard_error;

// The ethernet shield
EtherShield es=EtherShield();
NanodeMAC mac( mymac );

// SD Card
SdFat sd;
SdFile myFile;

uint16_t http200ok(void)
{
  return(es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

uint16_t addResponse_p(uint16_t plen, PROGMEM const char *response)
{
  return es.ES_fill_tcp_data_p(buf,plen,response);
}

uint16_t addResponse(uint16_t plen, const char *response)
{
  return es.ES_fill_tcp_data(buf,plen,response);
}

// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage()
{
  uint16_t plen;
  plen=http200ok();

  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<html><head><title>Saskatoon TechWorks - Access Control</title></head><body>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<center><h1>Welcome to Arduino ENC28J60 Ethernet Shield V1.0</h1>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<hr><br><h2><font color=\"blue\">-- Put your ARDUINO online -- "));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br> Control digital outputs"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br> Read digital analog inputs HERE"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("<br></font></h2>") );
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("</center><hr>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("V1.0 <a href=\"http://blog.thiseldo.co.uk\">blog.thiseldo.co.uk</a>"));
  plen=es.ES_fill_tcp_data_p(buf,plen,PSTR("</body></html>"));

  return(plen);
}

uint16_t print_webpage_paramtest(const char *params)
{
  uint16_t plen;
  plen=http200ok();

  plen=addResponse_p(plen,PSTR("<html><head><title>Secret Webpage</title></head><body>"));
  plen=addResponse_p(plen,PSTR("<blink>abc</blink><pre>"));
  plen=addResponse(plen,params);
  plen=addResponse_p(plen,PSTR("</pre></body></html>"));

  return plen;
}

uint16_t print_webpage_access(const char *params)
{
  uint16_t plen;
  plen = http200ok();

  plen = addResponse_p(plen, "<html><head><title>Access Control</title></head><body><h2>Saskatoon Techworks : Access Control</h2>");
  plen = addResponse_p(plen, "<table border=\"1\" cellpadding=\"3\" cellspacing=\"3\">");
  plen = addResponse_p(plen, "<thead><tr><th colspan=\"3\">Recent Activity</th></tr><tr><th>Fob ID</th><th>Name</th><th>Swipe Time</th></tr></thead><tbody>");

  plen = addResponse_p(plen, "<!-- Last 10 log record entries -->");
  plen = addResponse_p(plen, "<tr><td>192380912</td><td>Matthew Drotar</td><td>2010-10-22 15:22:01</td></tr>");
  plen = addResponse_p(plen, "<tr><td>98340928333</td><td style=\"background-color:red\">[Invalid Key]</td><td>2010-10-22 15:22:01</td></tr>");

  plen = addResponse_p(plen, "</tbody></table><a href=\"log/\">Browse Log Files</a><p />");
  plen = addResponse_p(plen, "<form action=\"page.html\" method=\"get\"><input type=\"hidden\" name=\"op\" value=\"delete\" /><table border=\"1\" cellpadding=\"3\" cellspacing=\"3\">");
  plen = addResponse_p(plen, "<thead><tr><th colspan=\"4\">Current Fobs</th></tr><tr><th>Fob ID</th><th>Owner</th><th>Activated By</th><th>Delete</th></tr></thead><tbody>");

  plen = addResponse_p(plen, "<!-- All current fobs -->");
  plen = addResponse_p(plen, "<tr><td>192380912</td><td>Matthew Drotar</td><td>Admin</td><td><center><input type=\"checkbox\" name=\"fob\" value=\"192380912\" /></center></td></tr>");
  plen = addResponse_p(plen, "<tr><td>98340928333</td><td>Bill Cosby</td><td>Admin</td><td><center><input type=\"checkbox\" name=\"fob\" value=\"98340928333\" /></center></td></tr>");

  plen = addResponse_p(plen, "<tr><td colspan=\"4\" align=\"right\"><input type=\"submit\" value=\"Update\" /></td></tr></tbody></table></form>");
  plen = addResponse_p(plen, "<form action=\"page.html\" method=\"get\"><input type=\"hidden\" name=\"op\" value=\"add\" /><table border=\"1\" cellpadding=\"3\" cellspacing=\"3\">");
  plen = addResponse_p(plen, "<tr><th colspan=\"3\">Add Fob</th></tr><tr><th>Fob ID</th><th>Name</th></tr>");
  plen = addResponse_p(plen, "<tr><td><input type=\"text\" name=\"fob\" value =\"\" /></td><td><input type=\"text\" name=\"name\" value =\"\" /></td><td><input type=\"submit\" value=\"Add\" /></td></tr>");
  plen = addResponse_p(plen, "</table></form><p>");
  plen = addResponse_p(plen, "To activate a new fob, a existing valid fob is required. After clicking \"Add\" you will be asked to swipe your valid fob. Your name will be linked to the newly activated fob.");
  plen = addResponse_p(plen, "</p></body></html>");

  return plen;
}

uint8_t logAccess(char *fob, char *name)
{
  if (sdcard_error) return 1;

  // open the file for write at end like the Native SD library
  if (!myFile.open("access.txt", O_RDWR | O_CREAT | O_AT_END)) {
    return 1;
  }
  // if the file opened okay, write to it:
  myFile.print("0000-00-00T00:00:00");
  myFile.print(",");
  myFile.print(fob);
  myFile.print(",");
  myFile.println(name);

  // close the file:
  myFile.close();

  return 0;
}

uint8_t logFobChange(char *fob, char *name, char *op, char *authFob, char *authName)
{
  if (sdcard_error) return 1;

  // open the file for write at end like the Native SD library
  if (!myFile.open("access.txt", O_RDWR | O_CREAT | O_AT_END)) {
    return 1;
  }
  // if the file opened okay, write to it:
  myFile.print("0000-00-00T00:00:00");
  myFile.print(",");
  myFile.print(op);
  myFile.print(",");
  myFile.print(fob);
  myFile.print(",");
  myFile.print(name);
  myFile.print(",");
  myFile.print(authFob);
  myFile.print(",");
  myFile.println(authName);

  // close the file:
  myFile.close();

  return 0;
}

void setup(){

  Serial.begin(115200);

  Serial.println("Initializing SPI");
  // Initialise SPI interface
  es.ES_enc28j60SpiInit();

  Serial.println("Initializing ENC28J60");
  // initialize enc28j60
  es.ES_enc28j60Init(mymac,8);

  Serial.println("Initializing Network Stack");
  // init the ethernet/ip layer:
  es.ES_init_ip_arp_udp_tcp(mymac,myip, MYWWWPORT);

  Serial.println("Initializing SD Card");

  // Initialize SdFat or print a detailed error message and halt
  // Use half speed like the native library.
  // change to SPI_FULL_SPEED for more performance.
  if (!sd.init(SPI_HALF_SPEED, SDCARD_CS)) 
  {
    //sd.initErrorHalt();
    sd.initErrorPrint();
    sdcard_error = 1;
    Serial.println("sd.init() failed");
  }
  else
  {
    // open the file for write at end like the Native SD library
    if (!myFile.open("prog.txt", O_RDWR | O_CREAT | O_AT_END)) {
      sdcard_error = 1;
      Serial.println("open prog.txt for write failed");
      sd.errorPrint("opening prog.txt for write failed");
    }
    else
    {
      // if the file opened okay, write to it:
      myFile.print("0000-00-00T00:00:00");
      myFile.println(" Application started");

      // close the file:
      myFile.close();
    }
  }

  Serial.println("Init Done.");

}

void loop(){

  processWebRequests();



}

// requestString is the entire request string, ex) "GET /abc?param1=value1&param2=value2 HTTP/1.0"
// method will get filled with "GET"
// resource will get filled with "/abc?param1=value1&param2=value2"
void parseWebRequest(char *requestString, char *method, char *resource, char *params)
{
  int methodLen;
  char *resourceStart;
  int resourceLen;
  char *paramStart;
  int paramLen;
  char *tailStart;

  // initialize all output to blank strings
  method[0] = '\0';
  resource[0] = '\0';
  params[0] = '\0';

  resourceStart = (char*)memchr(requestString, ' ', 10);
  if (resourceStart != NULL)
  {
    // copy data into method
    methodLen = resourceStart - requestString;

    Serial.println("methodLen:");
    Serial.println(methodLen);

    memcpy(method, requestString, methodLen);
    method[methodLen] = '\0';

    Serial.println("method:");
    Serial.println(method);

    resourceStart++;    
    // find questionmark param delimiter
    paramStart = (char*)memchr(resourceStart, '?', 50);
    if (paramStart == NULL)
    {
      Serial.println("noparams");
      // No params. Copy to resource.
      tailStart = (char*)memchr(resourceStart, ' ', 50);
      resourceLen = tailStart - resourceStart;
      memcpy(resource, resourceStart, resourceLen);
      resource[resourceLen] = '\0';
    }
    else
    {
      // params exist. copy resource.
      resourceLen = paramStart - resourceStart;
      memcpy(resource, resourceStart, resourceLen);
      resource[resourceLen] = '\0';

      tailStart = (char*)memchr(resourceStart, ' ', 50);
      if (tailStart != NULL)
      {
        paramLen = tailStart - paramStart;
        memcpy(params, paramStart, paramLen);
        params[paramLen] = '\0';
        Serial.println("params:");
        Serial.println(params);
      }
    }
  }

}

void processWebRequests(){
  uint16_t dat_p;
  char requestMethod[10];
  char requestedResource[50];
  char requestParams[50];

  // read packet, handle ping and wait for a tcp packet:
  dat_p=es.ES_packetloop_icmp_tcp(buf,es.ES_enc28j60PacketReceive(BUFFER_SIZE, buf));

  /* dat_p will be unequal to zero if there is a valid 
   * http get */
  if(dat_p==0){
    // no http request
    return;
  }
  // tcp port 80 begin
  parseWebRequest((char *)&buf[dat_p], requestMethod, requestedResource, requestParams);
  Serial.print(":: ");
  Serial.print(requestMethod);
  Serial.print(" | ");
  Serial.print(requestedResource);
  Serial.print(" | ");
  Serial.print(requestParams);
  Serial.println(" | ");

  if (strcmp("GET",requestMethod)!=0){
    // head, post and other methods:
    dat_p=http200ok();
    dat_p=es.ES_fill_tcp_data_p(buf,dat_p,PSTR("<h1>lol</h1>"));
    goto SENDTCP;
  }
  // just one web page in the "root directory" of the web server
  if (strcmp("/", requestedResource)==0){
    dat_p=print_webpage();
    goto SENDTCP;
  }
  else if (strcmp("/paramtest", requestedResource)==0){
    dat_p=print_webpage_paramtest(requestParams);
    goto SENDTCP;
  }
  else if (strcmp("/access", requestedResource)==0){
    dat_p=print_webpage_access(requestParams);
    goto SENDTCP;
  }
  else{
    dat_p=es.ES_fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 401 Unauthorized\r\nContent-Type: text/html\r\n\r\n<h1>401 Unauthorized</h1>"));
    goto SENDTCP;
  }
SENDTCP:
  es.ES_www_server_reply(buf,dat_p); // send web page data
  // tcp port 80 end

}



