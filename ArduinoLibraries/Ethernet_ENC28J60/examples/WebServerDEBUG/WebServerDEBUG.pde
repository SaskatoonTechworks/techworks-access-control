#include <NanodeMAC.h>
#define NANODE

#include "Client.h"
#include "Ethernet.h"
#include "Server.h"



byte mac[] = { 0x00, 0x04, 0xA3, 0x2C, 0x0F, 0x93 };
byte ip[] = { 10, 10, 220, 184 };

Server server(80);
NanodeMAC nanodemac( mac );

#define ETHERSHEILD_DEBUG

void setup() {
#ifdef ETHERSHIELD_DEBUG
  Serial.begin(19200);
#endif

  Ethernet.begin(mac, ip);
  server.begin();
}

void loop() {
  Client client = server.available();

  if (client) {

#ifdef ETHERSHIELD_DEBUG
    Serial.println("New client!");
#endif

    // an http request ends with a blank line
    int current_line_is_blank = 0;
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        Serial.print(c);
        if (c == '\n' && current_line_is_blank) {
#ifdef ETHERSHIELD_DEBUG
          Serial.println("Received headers!");
#endif
          char response[30];
          int size;
          sprintf(response, "millis() = <b>%lu</b>", millis());
          for (size = 0; response[size] != '\0'; size++) {}

          client.println("HTTP/1.0 200 OK");
          client.println("Content-Type: text/html");
          client.print("Content-Length: ");
          client.println(size);
          client.println();
          
          client.print(response);
          break;
        }
        else if (c == '\n') {
          current_line_is_blank = 1;
        }
        else if (c != '\r') {
          current_line_is_blank = 0;
        }
      }
    }

#ifdef ETHERSHIELD_DEBUG
    Serial.println("Disconnected");
#endif

    // give the web browser time to receive the data
    delay(1);
    client.stop();
  }
}
