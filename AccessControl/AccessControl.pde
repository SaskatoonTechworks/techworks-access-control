/*
 * Access Control
 * SKTechWorks July 2011
 * Based Crazy People by Mike Cooks April 2009
 */


// Definitions
#define LATCH_UNLOCK_PIN    12

#define READER_DATA0_INT    0
#define READER_DATA0_PIN    2
#define READER_DATA1_INT    1
#define READER_DATA1_PIN    3
#define READ_TIMEOUT_MS     1000
#define MAX_CODE_LEN        32

#define LED_OUT_PIN         13

#define ACCESSGRANTED_CODE  "12345"
#define ACCESSDENIED_CODE   "54321"

// Variables
volatile uint64_t reader1 = 0;
volatile int reader1Count = 0;


// Board Setup
void setup() {
  // Door Latch Setup  
  // initialize pin 12 as digital output to control the Latch Unlock
  pinMode(LATCH_UNLOCK_PIN, OUTPUT);
  
  // Serial Port (aka PC communications) Setup
  // start serial port at 115200 bps.
  Serial.begin(115200);
  
  // Wiegnad RFID Reader Interface Setup
  // put the reader input variables to zero
  reader1 = 0;
  reader1Count = 0;
  
  // Attach pin change interrupt service routines from the Wiegand RFID readers and make them inputs
  attachInterrupt(READER_DATA0_INT, reader1Zero, FALLING);//DATA0 to pin 2
  attachInterrupt(READER_DATA1_INT, reader1One, FALLING); //DATA1 to pin 3
  
  delay(10);
  
  pinMode(LED_OUT_PIN, OUTPUT);
  digitalWrite(LED_OUT_PIN, LOW);
  
  delay(10);
}


// Main Run Loop
void loop() {
  char accessCode[MAX_CODE_LEN];
  
  Serial.println(":Waiting for code...");
  waitForWiegandAccessCode(accessCode);
  
  if (accessCodeIsValid(accessCode))
  {
    Serial.print(":SUCCESS: ");
    Serial.println(accessCode);
    
    // Trigger unlock for 3 seconds.
    digitalWrite(LATCH_UNLOCK_PIN, HIGH);   // set the LED on
    Serial.println(":Door unlocked");
    delay(3000);              // wait for a second
    digitalWrite(LATCH_UNLOCK_PIN, LOW);    // set the LED off
    
    Serial.println(":Door relocked");
    
    // Delay 500 ms before attempting to read next access code.. for debounce.
    delay(500);
    
    // clear out reader bits
    reader1 = 0;
    reader1Count = 0;
  }
  else
  {
    Serial.print(":FAIL: ");
    Serial.println(accessCode);
  }
}


// Functions
// Wiegand Interrupts
void reader1One(void) {
  reader1Count++;
  reader1 = reader1 << 1;
  reader1 |= 1;
}

void reader1Zero(void) {
  reader1Count++;
  reader1 = reader1 << 1;
}

// 
void waitForWiegandAccessCode(char accessCode[])
{
  unsigned long startTime;
  unsigned long codeLow;
  unsigned long codeHigh;
  
  // wait for first bit
  while (reader1Count == 0);
  digitalWrite(LED_OUT_PIN, HIGH);
  startTime = millis();
  
  // wait until no more bits are coming in
  while (reader1Count < 36)
  {
    if ((millis() - startTime) > READ_TIMEOUT_MS)
      break;
  }
  
  digitalWrite(LED_OUT_PIN, LOW);
  
  Serial.print(":Read ");
  Serial.print(reader1Count);
  Serial.println(" bits");
  
  codeLow = (reader1 & 0x00000000FFFFFFFF);
  codeHigh = (reader1 >> 32);
  
  Serial.print(":codeHigh:");
  Serial.println(codeHigh, HEX);
  Serial.print(":codeLow:");
  Serial.println(codeLow, HEX);
  
  ultoa(codeLow, accessCode, 10);
  //sprintf(accessCode, "%08X%08X", codeHigh, codeLow);
  
  reader1 = 0;
  reader1Count = 0;
}

boolean accessCodeIsValid(char accessCode[])
{
  char inChar = 0;
  int charIdx = 0;
  char commandBuffer[100];
  
  Serial.flush();
  
  // send out accessCode for authorization
  Serial.println(accessCode);
  
  // wait for instruction from sheeva
  do
  {
    while (Serial.available() <= 0) { }
    inChar = (char)Serial.read();
    commandBuffer[charIdx++] = inChar;
  } while ((inChar != 13) && (charIdx < MAX_CODE_LEN));
  
  // keep accepting characters until CR, but ignore them.. max length is MAX_CODE_LEN
  while (inChar != 13)
  {
    while (Serial.available() <= 0) { }
    inChar = (char)Serial.read();
  }
  // replace CR with null terminator
  commandBuffer[charIdx-1] = 0;
  
  // Sheeva plug will have to send the UNLOCK_CODE if RFID code is authorized.
  if (strncmp(commandBuffer, ACCESSGRANTED_CODE, MAX_CODE_LEN) == 0)
  {
    return true;
  }
  else
  {
    return false;
  }
}


