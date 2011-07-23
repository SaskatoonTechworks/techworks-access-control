/*
  Access Control.
 */
 
#define LATCH_UNLOCK_PIN 12
#define MAX_CODE_LEN 32
#define ACCESS_CODE "12345"

void setup() {                
  // initialize pin 12 as digital output to control the Latch Unlock
  pinMode(LATCH_UNLOCK_PIN, OUTPUT);
  
  // start serial port at 115200 bps.
  Serial.begin(115200);
}

void loop() {
  char accessCode[MAX_CODE_LEN];
  
  Serial.println("Waiting for code...");
  waitForAccessCode(accessCode);
  
  if (authorizeAccessCode(accessCode))
  {
    Serial.print("Code Accepted: ");
    Serial.println(accessCode);
    
    // Trigger unlock for 3 seconds.
    digitalWrite(LATCH_UNLOCK_PIN, HIGH);   // set the LED on
    Serial.println("Door unlocked");
    delay(3000);              // wait for a second
    digitalWrite(LATCH_UNLOCK_PIN, LOW);    // set the LED off
    
    Serial.println("Door relocked");
    
    // Delay 1 second before attempting to read next access code.. for debounce.
    delay(1000);
  }
  else
  {
    Serial.print("Invalid Code: ");
    Serial.println(accessCode);
  }
}

void waitForAccessCode(char accessCode[])
{
  char inChar = 0;
  int charIdx = 0;
  
  Serial.flush();
  
  do
  {
    while (Serial.available() <= 0) { }
    inChar = (char)Serial.read();
    accessCode[charIdx++] = inChar;
  } while ((inChar != 13) && (charIdx < MAX_CODE_LEN));
  
  // keep accepting characters until CR, but ignore them.. max length is MAX_CODE_LEN
  while (inChar != 13)
  {
    while (Serial.available() <= 0) { }
    inChar = (char)Serial.read();
  }
  
  // replace CR with null terminator
  accessCode[charIdx-1] = 0;
}

boolean authorizeAccessCode(char accessCode[])
{
  // Sheeva plug will have to send the ACCSES_CODE if code entered in keypad is authorized.
  if (strncmp(accessCode, ACCESS_CODE, MAX_CODE_LEN) == 0)
  {
    return true;
  }
  else
  {
    return false;
  }
}
