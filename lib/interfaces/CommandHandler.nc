interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer();
   event void CommandHandler.setTestClient(uint16_t destination, uint16_t SRCP, uint16_t DP, uint16_t trans){
   event void setAppServer();
   event void setAppClient();
}
