interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint8_t socket_in);
   event void setTestClient(uint16_t source_socket, uint16_t target_addr, uint16_t target_socket, uint16_t data);
   event void setAppServer();
   event void setAppClient();
   event void setClientClose(uint8_t client_addr, uint8_t dest_arr, uint8_t srcPort, uint8_t destPort);
}
