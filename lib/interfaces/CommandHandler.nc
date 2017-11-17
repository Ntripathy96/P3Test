interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer();
   event void setTestClient(uint16_t dest, uint16_t sourcePort, uint16_t destPort, uint16_t transfer);
   event void setAppServer();
   event void setAppClient();
}
