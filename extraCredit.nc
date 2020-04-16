/* I collaborated with Keerthana Madadi for the code and I collaborated/discussed design ideas implementation with jonathan S and Keerthana M. However, Keerthana and I are in one team and Jonathan is doing it himself.
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"

module Node{
   uses interface Boot;
   uses interface Timer<TMilli> as periodicTimer;
   uses interface Timer<TMilli> as periodicTimer1;
   uses interface Timer<TMilli> as TCP_Timer;
   uses interface Timer<TMilli> as TCP_Timeout;
   uses interface List<pack> as ListPackets;
   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface List<char> as NeighborList;
   uses interface CommandHandler;
   uses interface List<RouteNode> as RouteTable;
}

implementation{
   pack sendPackage;
   uint16_t seqNum = 0;
   socket_store_t sockets [MAX_NUM_OF_SOCKETS];
   socket_store_t s;
   uint8_t delay =0;
   uint8_t socket;
   uint16_t nextPacket = 0;
   uint8_t port_info [PACKET_MAX_PAYLOAD_SIZE];
   uint16_t congestionWindow = 0;
   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   bool checkExistsPacket(pack *Package);
   void addPacketList(pack Package);
   void discoverNeighbors();
   void printNeighbors();
   void createRoutingTable();
   void printRoute();
   void send_syn(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort);
   void send_rcvd(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort);
   void send_TCP(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort);
   uint16_t get_next_hop(uint16_t dest);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         call periodicTimer.startPeriodic(5000);
         //call periodicTimer1.startPeriodic(6000);
         /*dbg(GENERAL_CHANNEL, "Time %d\n",call periodicTimer.getNow());
         if(call periodicTimer.getNow() > 2000){
            dbg(GENERAL_CHANNEL, "in here\n",call periodicTimer.getNow());
            call periodicTimer1.startPeriodic(10000);
         }*/
         //call TCP_Timer.startPeriodic(100000);
         //initialize_tcp_list();
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}
   //Random firing for neighborDiscovery
   event void periodicTimer.fired(){
      discoverNeighbors();
      if(delay > 5){
         createRoutingTable();
      }
      delay++;
      //dbg(GENERAL_CHANNEL, "Time %d\n",call periodicTimer.getNow());
      /*if(call periodicTimer.getNow() > 10000){
         //dbg(GENERAL_CHANNEL, "in here\n",call periodicTimer.getNow());
         call periodicTimer1.startPeriodic(10000);
      }*/
   }
   //Random firing for RoutingTable
   event void periodicTimer1.fired(){
      createRoutingTable();
   }

   event void TCP_Timer.fired(){
      uint8_t i = 0; 
      uint8_t j = 0;
      //dbg(TRANSPORT_CHANNEL, "TCP_Timer fired function %d\n", TOS_NODE_ID);
      for(i = 0; i < MAX_NUM_OF_SOCKETS; i++){
         if(sockets[i].state == SYN_SENT){
            dbg(TRANSPORT_CHANNEL, "In SYN_SYN\n");
            ////printRoute();
            call TCP_Timer.startOneShot(sockets[i].RTT * 2);
            send_syn(sockets[i].src, sockets[i].dest.addr, sockets[i].dest.port);
         }
         else if(sockets[i].state == SYN_RCVD){
            //sockets[i].state = ESTABLISHED;
            dbg(TRANSPORT_CHANNEL, "In SYN_RCVD\n");
            call TCP_Timer.startOneShot(sockets[i].RTT * 2);
            send_rcvd(sockets[i].src, sockets[i].dest.addr, sockets[i].dest.port);
         }
         else if(sockets[i].state == ESTABLISHED){
            //client
            if (sockets[i].flag == TOS_NODE_ID && nextPacket <=250){
               //dbg(TRANSPORT_CHANNEL, "size: %d\n",sockets[i].effectiveWindow);
               sockets[i].nextExpected = nextPacket + sockets[i].effectiveWindow+1;
               //call TCP_Timeout.startOneShot(call TCP_Timer.getNow() + sockets[i].RTT * 2);
               for(j = 0; j <= sockets[i].effectiveWindow+1; j++){
                  if(sockets[i].effectiveWindow > 0){
                     call TCP_Timeout.startOneShot( sockets[i].RTT * 2);
                     send_TCP(sockets[i].src, sockets[i].dest.addr, sockets[i].dest.port);
                  }
               }
            }
         }
      }
   }

   event void TCP_Timeout.fired(){
      uint8_t i = 0; 
      uint8_t j = 0;
      for(i = 0; i < MAX_NUM_OF_SOCKETS; i++){
         if(sockets[i].state == ESTABLISHED){
            if (sockets[i].flag == TOS_NODE_ID && nextPacket <=250){
               dbg(TRANSPORT_CHANNEL, "Timeout called. Received up to %d packets for going from %d in port %d\n", sockets[i].lastAck, TOS_NODE_ID, sockets[i].src);
                  nextPacket = sockets[i].lastAck;
                  //if(sockets[i].effectiveWindow == 0){
                     sockets[i].effectiveWindow = congestionWindow/2;
                     if(sockets[i].effectiveWindow <= 0){
                        sockets[i].effectiveWindow = 1;
                     }
                     congestionWindow = sockets[i].effectiveWindow;
                     dbg(TRANSPORT_CHANNEL, "TIMEOUT Congestion Window %d\n", congestionWindow);
                  //}
                  //call TCP_Timer.startPeriodic(10000);
                  sockets[i].nextExpected = nextPacket + sockets[i].effectiveWindow+1;
               //call TCP_Timeout.startOneShot(call TCP_Timer.getNow() + sockets[i].RTT * 2);
               for(j = 0; j <= sockets[i].effectiveWindow+1; j++){
                  if(sockets[i].effectiveWindow > 0){
                     call TCP_Timeout.startOneShot( sockets[i].RTT * 2);
                     send_TCP(sockets[i].src, sockets[i].dest.addr, sockets[i].dest.port);
                  }
               }
            }

            
         }
      }
   }


   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: Reciever Node: %d\n", TOS_NODE_ID);
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         RouteNode *t = myMsg->payload;
         //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: source of packet: %d\n",myMsg->src);
         if(myMsg->TTL != 0 && checkExistsPacket(myMsg)==FALSE){
            if(myMsg->dest == AM_BROADCAST_ADDR){
               //This block is when the origin is asking who their neighbors are
               if(myMsg->protocol == PROTOCOL_PING){
                  //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: Sending packets to check for neighbors: \n");
                  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PINGREPLY, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  addPacketList(sendPackage);
                  call Sender.send(sendPackage, myMsg->src);
               }
               //This block deals with the response packet of the neighbors
               else if(myMsg->protocol == PROTOCOL_PINGREPLY){
                  uint16_t i = 0;
                  bool found;
                  found = FALSE;
                  //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: Recieved ping reply: \n");
                  //printNeighbors();
                  for(i=0; i < call NeighborList.size(); i++){
                     if(myMsg->src == call NeighborList.get(i)){
                        found = TRUE;
                     }
                  }
                  if(found ==FALSE){
                     //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: Found a new neighbor: %d\n",myMsg->src);
                     call NeighborList.pushback(myMsg->src);
                  }
                  /*if(call periodicTimer.getNow() > 2000 && call periodicTimer.isRunning() == FALSE){
                     //dbg(GENERAL_CHANNEL, "in here\n",call periodicTimer.getNow());
                     call periodicTimer1.startPeriodic(10000);
                  }*/
               }
               //This block deals with the link layer for routing 
               else if(myMsg->protocol == PROTOCOL_LINKEDLIST){
                  RouteNode *r = (RouteNode *)myMsg->payload;
                  RouteNode rNode;
                  uint16_t i = 0;
                  uint16_t j = 0;
                  uint16_t k = 0;
                  char *message= "message to request for neighbor routing packets";
                  bool status = FALSE;
                  //Iterating over RoutingTable to see if the routing entry exists
                  for(i = 0; i < call RouteTable.size(); i++){
                     RouteNode temp1 = call RouteTable.get(i);
                     RouteNode *temp = &temp1;
                     if(temp->dest == r->dest){
                        //Update Routing table if better path is found
                        if(r->cost < temp->cost){
                           dbg(ROUTING_CHANNEL, "Found a better path. Taking: %d\n",myMsg->src);
                           temp1.cost = r->cost;
                           temp1.nextHop = myMsg->src;
                           call RouteTable.pushback(temp1);
                           call RouteTable.pop(i);
                        }
                        status = TRUE;
                     }
                  }
                  //Discovered a new route for a new destination
                  if(status == FALSE && r->dest != TOS_NODE_ID){
                     RouteNode temp;
                     temp.dest = r->dest;
                     temp.nextHop = myMsg->src;
                     temp.cost = (r->cost);
                     call RouteTable.pushback(temp);
                  }
                  //Asking neighbors to send their routing table
                  for(j = i; j < call RouteTable.size();j++){
                     rNode = call RouteTable.get(j);
                     for(k = 0; k <=20; k++){
                        makePack(&sendPackage, TOS_NODE_ID, rNode.dest, MAX_TTL, PROTOCOL_LINKEDLIST, seqNum, (uint8_t *) message, PACKET_MAX_PAYLOAD_SIZE);
                        addPacketList(sendPackage);
                        seqNum = seqNum + 1;
                        if(rNode.nextHop <=20){
                           call Sender.send(sendPackage, rNode.nextHop);
                        }
                     }
                  }
               }
            }
            // Add here 
            else if(TOS_NODE_ID == myMsg->dest){
               RouteNode rNode;
               RouteNode *rNode1;
               uint16_t i = 0;
               uint16_t j = 0;
               if (myMsg->protocol == PROTOCOL_SYN){
                  uint16_t next;
                  uint8_t index;
                  index = myMsg->payload[1];
                  if(sockets[index].state == LISTEN){
                     dbg(TRANSPORT_CHANNEL, "Syn Packet Arrived from Node %d for Port %d\n", myMsg->src, index);
                     sockets[index].state = SYN_RCVD;
                     sockets[index].src = TOS_NODE_ID;
                     sockets[index].dest.addr = myMsg->src;
                     sockets[index].dest.port = myMsg->payload[0];
                     sockets[index].RTT = 15000;
                     call TCP_Timer.stop();
                     //dbg(TRANSPORT_CHANNEL, "Values assigned succesfully\n");
                     call TCP_Timer.startOneShot(sockets[i].RTT * 2);
                     //call TCP_Timer.startPeriodic(100000);
                     send_rcvd(sockets[index].src, sockets[index].dest.addr, sockets[index].dest.port);
                     /*port_info[0] = myMsg->payload[1];
                     port_info[1] = myMsg->payload[0];
                     port_info[3] = 3;
                     makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_SYN_ACK, seqNum, (uint8_t *)port_info, PACKET_MAX_PAYLOAD_SIZE);
                     next = get_next_hop(myMsg->src);
                     seqNum++;
                     dbg(TRANSPORT_CHANNEL, "Syn Ack Packet sent to Node %d for Port %d\n", myMsg->src, index);
                     call Sender.send(sendPackage, next);*/
                  }
                  else{
                     dbg(TRANSPORT_CHANNEL, "state: %s\n", sockets[index].state);
                     dbg(TRANSPORT_CHANNEL, "Unable to open port because Server port was not open\n");
                  }
                  
               }
               else if (myMsg->protocol == PROTOCOL_SYN_ACK){
                  uint8_t index;
                  index = myMsg->payload[1];
                  call TCP_Timer.stop();
                  sockets[index].state = ESTABLISHED;
                  dbg(TRANSPORT_CHANNEL, "Connection ESTABLISHED for node %d in port %d\n", TOS_NODE_ID, index);
                  call TCP_Timer.startPeriodic(10000);
               }
               else if (myMsg->protocol == PROTOCOL_FIN){
                  uint8_t index;
                  index = myMsg->payload[0];
                  if(sockets[index].state == ESTABLISHED){
                     sockets[index].state = LISTEN;
                     dbg(TRANSPORT_CHANNEL, "Terminating server communication for node %d in port %d and changing state to LISTEN\n",TOS_NODE_ID, index);
                  }
                  else{
                     dbg(TRANSPORT_CHANNEL, "Cannot change state to LISTEN because server port was not created\n");
                  }
                  
               }
               else if (myMsg->protocol == PROTOCOL_TCP){
                  uint16_t next;
                  if(myMsg->payload[3] > 5){
                     dbg(TRANSPORT_CHANNEL, "CONGESTION WINDOW: %d, greater than 5\n", myMsg->payload[3]);
                     nextPacket = nextPacket - congestionWindow;
                     call TCP_Timeout.startOneShot(0);

                  }
                  else{
                     if(sockets[myMsg->payload[1]].state == SYN_RCVD){
                        dbg(TRANSPORT_CHANNEL, "Changing receiver state to established\n");
                        sockets[myMsg->payload[1]].state = ESTABLISHED;
                     }
                     port_info[0] = myMsg->payload[1];
                     port_info[1] = myMsg->payload[0];
                     port_info[2] = myMsg->payload[2];
                     makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_ACK, seqNum, (uint8_t *)port_info, PACKET_MAX_PAYLOAD_SIZE);
                     next = get_next_hop(myMsg->src);
                     dbg(TRANSPORT_CHANNEL, "ACK Packet sent from Node %d, port %d to Node %d,Port %d with seqNum:%d\n", TOS_NODE_ID, myMsg->payload[1], myMsg->src, myMsg->payload[0], myMsg->payload[2]);
                     call Sender.send(sendPackage, next);
                  }
               }
               else if (myMsg->protocol == PROTOCOL_ACK){
                   uint8_t k = 0;
                   call TCP_Timeout.stop();
                  dbg(TRANSPORT_CHANNEL, "ACK received from node %d port %d to node %d port %d for seqNum %d \n", myMsg->src, myMsg->payload[0], TOS_NODE_ID, myMsg->payload[1],myMsg->payload[2]);
                  //sockets[myMsg->payload[1]].effectiveWindow = myMsg->payload[3];
                     sockets[myMsg->payload[1]].effectiveWindow++;
                     congestionWindow++;
                     dbg(TRANSPORT_CHANNEL, "effective Window: %d, congestion Window: %d\n", sockets[myMsg->payload[1]].effectiveWindow, congestionWindow); 
                     dbg(TRANSPORT_CHANNEL, "Able to send another %d packet(s) from the effective window\n", sockets[myMsg->payload[1]].effectiveWindow);
                  
                  if(myMsg->payload[2] - sockets[myMsg->payload[1]].lastAck == 1){
                     sockets[myMsg->payload[1]].lastAck = myMsg->payload[2];
                     dbg(TRANSPORT_CHANNEL, "Received upto %d packet(s) \n", sockets[myMsg->payload[1]].lastAck);
                     sockets[myMsg->payload[1]].nextExpected++;
                     if(congestionWindow > 0 && nextPacket <=250){
                        sockets[myMsg->payload[1]].effectiveWindow = congestionWindow;
                        for(k = 0; k <= congestionWindow; k++){
                           if(sockets[myMsg->payload[1]].effectiveWindow> 0){
                              call TCP_Timeout.startOneShot( sockets[myMsg->payload[1]].RTT * 2);
                              send_TCP(sockets[myMsg->payload[1]].src, sockets[myMsg->payload[1]].dest.addr, sockets[myMsg->payload[1]].dest.port);
                           }

                        }
                        //call TCP_Timeout.startOneShot( sockets[i].RTT * 2);
                        //send_TCP(myMsg->payload[1], myMsg->src, myMsg->payload[0]); 
                     }
                  }
               }

               //Sending routing table contents to the neighbor who asked for it.
               else if (myMsg->protocol == PROTOCOL_LINKEDLIST){
                  RouteNode rNode2;
                  for(i = 0; i < call RouteTable.size(); i++){
                     rNode = call RouteTable.get(i);
                     if(rNode.cost != 20){
                        rNode.cost = rNode.cost + 1;
                     }
                     rNode1 = &rNode;
                     makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, seqNum, (uint8_t *) rNode1, PACKET_MAX_PAYLOAD_SIZE);
                     addPacketList(sendPackage);
                     seqNum = seqNum + 1;
                     for(j = i; j < call RouteTable.size(); j++){
                        rNode2 = call RouteTable.get(j);
                        if((uint16_t)myMsg->src == (uint16_t) rNode2.dest){
                           break;
                        }
                     }
                     call Sender.send(sendPackage, rNode2.nextHop);
                  }
               }
               //Performs Routing Table check upon receiving the routing table contents from its neighbors
               else if(myMsg->protocol == PROTOCOL_PINGREPLY){
                  RouteNode *r = (RouteNode *) myMsg->payload;
                  uint16_t i = 0;
                  bool status = FALSE;
                  for(i = 0; i < call RouteTable.size(); i++){
                     RouteNode temp1 = call RouteTable.get(i);
                     RouteNode *temp = &temp1;
                     if(temp->dest == r->dest){
                        if(r->cost < temp->cost){
                           temp1.cost = r->cost;
                           temp1.nextHop = myMsg->src;
                           call RouteTable.pushback(temp1);
                           call RouteTable.pop(i);
                        }
                        status = TRUE;
                     }
                  }
                  if(status == FALSE && r->dest != TOS_NODE_ID){
                     RouteNode temp;
                     temp.dest = r->dest;
                     temp.nextHop = myMsg->src;
                     temp.cost = (r->cost);
                     call RouteTable.pushback(temp);
                  }
                  ////printRoute();
               }
               //Ping Packet has reached destination
               else if (myMsg->protocol == PROTOCOL_PING){
                  ////printRoute();
                  dbg(ROUTING_CHANNEL, "Packet has arrived! %s\n", myMsg->payload);
               } 
            }
            // Add here 2 
            else{
               //Rerouting for link layer packets
               if(myMsg->protocol == PROTOCOL_LINKEDLIST){
                  uint i = 0;
                  RouteNode r;
                  //dbg(ROUTING_CHANNEL, "REROUTING\n");
                  ////printRoute();
                  for (i = 0; i < call RouteTable.size(); i++){
                     r = call RouteTable.get(i);
                     if((uint16_t)myMsg->dest == (uint16_t)r.dest){
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_LINKEDLIST, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                        seqNum++;
                        addPacketList(sendPackage);
                        if(r.nextHop < 25){
                           dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, r.nextHop);
                           call Sender.send(sendPackage, r.nextHop);
                        }
                        break;
                     }
                  }
                  ////printRoute();
                  if(i == call RouteTable.size()){
                     dbg(GENERAL_CHANNEL, "No Path Found\n");
                  }
               }
               //Rerouting for ping layer packets
               else if(myMsg->protocol == PROTOCOL_PING){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PING, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  addPacketList(sendPackage);
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
               else if(myMsg->protocol == PROTOCOL_SYN){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_SYN, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  addPacketList(sendPackage);

                  //dbg(TRANSPORT_CHANNEL, "REROUTING for the ping event from\n");
                  //printRoute();
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
               else if (myMsg->protocol == PROTOCOL_FIN){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_FIN, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  addPacketList(sendPackage);
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
               else if(myMsg->protocol == PROTOCOL_SYN_ACK){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_SYN_ACK, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  //seqNum++;
                  addPacketList(sendPackage);
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
               else if(myMsg->protocol == PROTOCOL_TCP){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_TCP, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  //seqNum++;
                  addPacketList(sendPackage);
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
               else if(myMsg->protocol == PROTOCOL_ACK){
                  seqNum++;
                  makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_ACK, seqNum, (uint8_t *) myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                  //seqNum++;
                  addPacketList(sendPackage);
                  //if(get_next_hop(myMsg->dest) < 25){
                     dbg(ROUTING_CHANNEL, "REROUTING for the ping event from %d to %d\n",TOS_NODE_ID, get_next_hop(myMsg->dest));
                     call Sender.send(sendPackage, get_next_hop(myMsg->dest));
                  //}
               }
            }
         }
         else{
            //dbg(GENERAL_CHANNEL, "Dropping Packet because I have already seen it\n");
         }
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      uint i = 0;
      RouteNode r;
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      dbg(GENERAL_CHANNEL, "Packet source %d\n", TOS_NODE_ID);
      ////printRoute();
      for (i = 0; i < call RouteTable.size(); i++){
         r = call RouteTable.get(i);
         if((destination == (uint16_t) r.dest) && r.cost < 20){
            dbg(ROUTING_CHANNEL, "Found a route!!! %d\n", r.nextHop);
            makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
            seqNum++;
            addPacketList(sendPackage);
            call Sender.send(sendPackage, r.nextHop);
            break;
         }
      }
      if(i == call RouteTable.size()){
         dbg(GENERAL_CHANNEL, "No Path Found\n");
      }
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint8_t socket_in){
      sockets[socket_in].state = LISTEN;
      //call TCP_Timer.startPeriodic(10000);
   }

   event void CommandHandler.setTestClient(uint16_t source_socket, uint16_t target_addr, uint16_t target_socket, uint16_t data){
      sockets[source_socket].state = SYN_SENT;
      sockets[source_socket].flag = TOS_NODE_ID;
      sockets[source_socket].src = source_socket;
      sockets[source_socket].dest.addr = target_addr;
      sockets[source_socket].dest.port = target_socket;
      sockets[source_socket].RTT = 8000;
      dbg(GENERAL_CHANNEL, "RTT: %d\n", sockets[source_socket].RTT);
      sockets[source_socket].effectiveWindow = 1;
      congestionWindow = 1;
      dbg(TRANSPORT_CHANNEL, "Congestion Window: %d\n", congestionWindow);
      call TCP_Timer.startOneShot(sockets[source_socket].RTT * 2);
      //send_syn(source_socket,sockets[source_socket].dest.addr,sockets[source_socket].dest.port);
      //call TCP_Timer.startPeriodic(100000);
   }

   event void CommandHandler.setClientClose(uint8_t client_addr, uint8_t dest_addr, uint8_t destPort, uint8_t srcPort){
      uint16_t nexHop = get_next_hop(dest_addr);
      sockets[srcPort].state = CLOSED;
      port_info[0] = destPort;
      //dbg(GENERAL_CHANNEL, "want to open port: %d\n", port_info[1]);
      makePack(&sendPackage, TOS_NODE_ID, dest_addr, MAX_TTL, PROTOCOL_FIN, seqNum, (uint8_t *) port_info, PACKET_MAX_PAYLOAD_SIZE);
      ////printRoute();
      call Sender.send(sendPackage, nexHop);
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
   bool checkExistsPacket(pack *Package){
      uint16_t size = call ListPackets.size();
      uint16_t i = 0;
      pack p;
      for(i = 0; i < size; i++){
         p = call ListPackets.get(i);
         if(p.src == Package->src && p.dest == Package->dest && p.seq == Package->seq){
            return TRUE;
         }
      }
      return FALSE;
   }
   void addPacketList(pack Package){
      if(call ListPackets.isFull() == TRUE){
         call ListPackets.popfront();
      }
      call ListPackets.pushback(Package);
   }
   void discoverNeighbors(){
      char *message ="FindNeighbors\n";
      pack packet;
      seqNum++;
      makePack(&packet, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_PING, seqNum, (uint8_t*) message, PACKET_MAX_PAYLOAD_SIZE);
      addPacketList(packet);
      //dbg(NEIGHBOR_CHANNEL, "NEIGHBOR: sending ping from %d\n",TOS_NODE_ID);
      call Sender.send(packet, AM_BROADCAST_ADDR);
   }
   //test comment 
   //Comment from KEERTHANA
   void printNeighbors(){
      uint16_t i, size;
		size = call NeighborList.size();
		if(size == 0) {
			dbg(NEIGHBOR_CHANNEL, "No Neighbors found\n");
		} 
      else {
			dbg(NEIGHBOR_CHANNEL, "Printing Neighbors:");
			for(i = 0; i < size; i++) {
				char neighbors = call NeighborList.get(i);
				dbg(NEIGHBOR_CHANNEL, "Neighbor: %d\n", neighbors);
			}
		}
   }
   //This function initializes routing table for the current node.
   void createRoutingTable(){
      uint16_t i = 0;
      RouteNode rNode;
      RouteNode *rNode1;
      if(call RouteTable.size() == 0){
         rNode.dest = TOS_NODE_ID;
         rNode.nextHop = TOS_NODE_ID;
         rNode.cost = 0;
         call RouteTable.pushback(rNode);
         dbg(ROUTING_CHANNEL, "Creating table for: %d\n", TOS_NODE_ID);
         for(i = 0; i < call NeighborList.size(); i++){
            if(call NeighborList.get(i) != (char) TOS_NODE_ID){
               rNode.dest = call NeighborList.get(i);
               rNode.nextHop = call NeighborList.get(i);
               rNode.cost = 1;
               call RouteTable.pushback(rNode);
            }
         }
      }
      for(i = 0; i < call RouteTable.size(); i++){
         rNode = call RouteTable.get(i);
         rNode.cost = rNode.cost + 1;
         if(rNode.dest != TOS_NODE_ID){
            rNode1 = &rNode;
            makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKEDLIST, seqNum, (uint8_t *) rNode1, PACKET_MAX_PAYLOAD_SIZE);
            addPacketList(sendPackage);
            seqNum = seqNum + 1;
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
      }   
   }
   //This function prints out the route from the routing table
   void printRoute(){
      uint16_t i,size;
      RouteNode temp1;
		size = call RouteTable.size();
      dbg(TRANSPORT_CHANNEL, "Getting Route for: %d\n", TOS_NODE_ID);
		if(size == 0) {
			dbg(ROUTING_CHANNEL, "No Routing found\n");
		} 
      else {
         dbg(TRANSPORT_CHANNEL, "dest | nextHop | cost\n");
			for(i = 0; i < call RouteTable.size(); i++) {
				temp1 = call RouteTable.get(i);
            dbg(TRANSPORT_CHANNEL, "%d | %d | %d\n", temp1.dest, temp1.nextHop, temp1.cost);
			}
		}
   }

   //changes by keerthana here!!!!
   void send_syn(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort){
      uint16_t nexHop = get_next_hop(dest_addr);
      dbg(GENERAL_CHANNEL, "Target Node: %d\n", dest_addr);
      dbg(GENERAL_CHANNEL, "Nexthop: %d\n", nexHop);
      ////printRoute();
      port_info[0] = srcPort;
      port_info[1] = destPort;
      dbg(GENERAL_CHANNEL, "want to open port: %d\n", port_info[1]);
      makePack(&sendPackage, TOS_NODE_ID, dest_addr, MAX_TTL, PROTOCOL_SYN, seqNum, (uint8_t *) port_info, PACKET_MAX_PAYLOAD_SIZE);
      addPacketList(sendPackage);
      seqNum++;
      if(nexHop < 25){
         call Sender.send(sendPackage, nexHop);
      }
   }
   void send_rcvd(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort){
      uint16_t nexHop = get_next_hop(dest_addr);
      //dbg(GENERAL_CHANNEL, "Target Node: %d\n", dest_addr);
      port_info[0] = srcPort;
      port_info[1] = destPort;
      //printRoute();
      // /dbg(GENERAL_CHANNEL, "want to open port: %d\n", port_info[1]);
      makePack(&sendPackage, TOS_NODE_ID, dest_addr, MAX_TTL, PROTOCOL_SYN_ACK, seqNum, (uint8_t *) port_info, PACKET_MAX_PAYLOAD_SIZE);
      addPacketList(sendPackage);
      seqNum++;
      if(nexHop < 25){
         dbg(TRANSPORT_CHANNEL, "Syn Ack Packet sent to Node %d for Port %d with nextHop %d\n", dest_addr, destPort, nexHop);
         call Sender.send(sendPackage, nexHop);
      }
   }
   /*
      0: src_port; 1: dest_port; 2: seq#;
   */
   void send_TCP(uint8_t srcPort, uint8_t dest_addr, uint8_t destPort){

         uint16_t nexHop = get_next_hop(dest_addr);
         //dbg(TRANSPORT_CHANNEL, "TCP Target Node: %d\n", dest_addr);
         //dbg(TRANSPORT_CHANNEL, "Sending seqNum: %d\n", nextPacket);
         nextPacket++;
         port_info[0] = srcPort;
         port_info[1] = destPort;
         port_info[2] = nextPacket;
         port_info[3] = congestionWindow;
         socket = srcPort;
         //dbg(TRANSPORT_CHANNEL, "Frame %d\n", port_info[2]);
         makePack(&sendPackage, TOS_NODE_ID, dest_addr, MAX_TTL, PROTOCOL_TCP, seqNum, (uint8_t *) port_info, PACKET_MAX_PAYLOAD_SIZE);
         dbg(TRANSPORT_CHANNEL, "TCP Packet sent from Node %d, port %d to Node %d,Port %d with seqNum:%d\n", TOS_NODE_ID, port_info[0], dest_addr, port_info[1], nextPacket);
         //nextPacket++;
         //call TCP_Timeout.startOneShot(6000);
         //call TCP_Timeout.startOneShot(4 * sockets[srcPort].RTT);
         sockets[srcPort].effectiveWindow--;
         dbg(TRANSPORT_CHANNEL, "Updated Effective Window after sending packet to receiver: %d\n", sockets[srcPort].effectiveWindow);
         call Sender.send(sendPackage, nexHop);
      
      
   }

   uint16_t get_next_hop(uint16_t dest_addr){
      uint8_t i = 0;
      RouteNode r;
      for (i = 0; i < call RouteTable.size(); i++){
         r = call RouteTable.get(i);
         if((dest_addr == (uint16_t) r.dest) && r.cost < 255){
            dbg(ROUTING_CHANNEL, "next hop: %d\n", r.nextHop);
            return r.nextHop;
         }
      }
      return -1;
   }
}
