/*
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


typedef nx_struct lspMap{ //holds a complete map of entire graph for each node
    nx_uint8_t cost[21];
}lspMap;
typedef nx_struct neighbor {
    nx_uint16_t Node;
    nx_uint8_t Life;
}neighbor;
    int seqNum = 1;
    //bool printNodeNeighbors = FALSE;

module Node{
    uses interface Boot;
    
    uses interface Timer<TMilli> as Timer1; //Interface that was wired above.
    uses interface Timer<TMilli> as lspTimer; //link state timer 
    uses interface Random as Random;
    uses interface SplitControl as AMControl;
    uses interface Receive;
    uses interface List<neighbor> as NeighborList;
    uses interface List<pack> as SeenPackList;
    uses interface List<pack> as SeenLspPackList;
    
    //uses interface Hashmap<int> as NeighborList;
    
    
    uses interface SimpleSend as Sender;
    
    uses interface CommandHandler;
}

implementation{
    pack sendPackage;
    //int seqNum = 0;
    bool printNodeNeighbors = FALSE;
    
    //int MAX_NODES = 20;
    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void printNeighbors();
    void printNeighborList();
    
    void neighborDiscovery();
    bool checkPacket(pack Packet);

    //project 2
    void lspMapInit(lspMap *list, int id);
    void lspNeighborDiscoveryPacket();
    lspMap lspMAP[20]; //change NAME, overall map of network stored at every node
    int lspSeqNum = 0;
    bool checkSeenLspPacks(pack Packet);


    event void Boot.booted(){
        call AMControl.start();
        dbg(GENERAL_CHANNEL, "Booted\n");
    }
   
    event void Timer1.fired()
    {
       neighborDiscovery();
    }
    event void lspTimer.fired(){
        lspNeighborDiscoveryPacket(); //change name
    }
    
    
    event void AMControl.startDone(error_t err){
        if(err == SUCCESS){
            dbg(GENERAL_CHANNEL, "Radio On\n");
            call Timer1.startPeriodic((uint16_t)((call Random.rand16())%200));
            call lspTimer.startPeriodic((uint16_t)((call Random.rand16())%200));
        }else{
            //Retry until successful
            call AMControl.start();
        }
    }
    
    event void AMControl.stopDone(error_t err){
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        //dbg(GENERAL_CHANNEL, "Packet Received\n");
         
                
                uint16_t size = call NeighborList.size();
                

        if(len==sizeof(pack)){
            pack* myMsg=(pack*) payload;
            //dbg(GENERAL_CHANNEL, "Packet received from %d\n",myMsg->src);
            
            //dbg(FLOODING_CHANNEL, "Packet being flooded to %d\n",myMsg->dest);
            
            

            if(myMsg->TTL == 0){ //check life of packet
                //dbg(FLOODING_CHANNEL,"TTL=0: Dropping Packet\n");
            }
            
            else if (myMsg->protocol == PROTOCOL_PING) //flooding
            {
                // This is what causes the flooding
                
               // dbg(FLOODING_CHANNEL,"Packet Received from %d meant for %d... Rebroadcasting\n",myMsg->src, myMsg->dest);
                
                
                
                if (myMsg->dest == TOS_NODE_ID) //resend with protocol pingreply for ACK
                {
                    makePack(&sendPackage, myMsg->src, myMsg->dest, MAX_TTL,PROTOCOL_PING,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    // This is when the flooding of a packet has finally led it to it's final destination
                    if(checkPacket(sendPackage)){
                       //dbg(FLOODING_CHANNEL,"Dropping Packet from src: %d to dest: %d with seq num:%d\n", myMsg->src,myMsg->dest,myMsg->seq);
                    }else{
                    //dbg(FLOODING_CHANNEL, "Packet has Arrived to destination! %d -> %d\n ", myMsg->src,myMsg->dest);
                    dbg(FLOODING_CHANNEL, "Packet has Arrived to destination! %d -> %d seq num: %d\n ", myMsg->src,myMsg->dest, myMsg->seq);
                    dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);

                    
                    
                    makePack(&sendPackage, TOS_NODE_ID, myMsg->src, 20,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                    
                    //dbg(FLOODING_CHANNEL, "SendPackage: %d\n", sendPackage.seq);
                    //dbg(FLOODING_CHANNEL, "seqNum: %d\n", seqNum);
                    }
                }
                else //not meant for this node
                {
                    makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    if(checkPacket(sendPackage)){//return true meaning packet found in SeenPackList
                        dbg(FLOODING_CHANNEL,"ALREADY SEEN: Dropping Packet from src: %d to dest: %d with seq num:%d\n", myMsg->src,myMsg->dest,myMsg->seq);
                        //dbg(FLOODING_CHANNEL,"ALREADY SEEN: Dropping Packet from src: %d to dest: %d\n", myMsg->src,myMsg->dest);
                    }else{
                        //makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
                    dbg(FLOODING_CHANNEL,"Packet Recieved from %d meant for %d, Sequence Number %d...Rebroadcasting\n",myMsg->src, myMsg->dest, myMsg->seq);
                    //dbg(FLOODING_CHANNEL,"Packet Recieved from %d meant for %d... Rebroadcasting\n",myMsg->src, myMsg->dest);
                    

                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                    }
                    

                }
            }
            else if (myMsg->dest == AM_BROADCAST_ADDR) //neigbor discovery OR LSP
            {
                
                switch(myMsg->protocol){
                    
                    case PROTOCOL_LINKSTATE:
                    
                    if(!checkSeenLspPacks(sendPackage)){ 
                        //initialize table for src 
                        lspMapInit(&lspMAP, myMsg->src);
                        dbg(ROUTING_CHANNEL,"LSP from %d, seqNum: %d\n", myMsg->src, myMsg->seq);
                            int i;
                        for(i = 0; i <20; i++){ //put neigbors and cost node knows
                        lspMAP[myMsg->src].cost[i] = myMsg->payload[i];
                            if(lspMAP[myMsg->src].cost[i] != -1 ){
                                dbg(ROUTING_CHANNEL, "%d Neighbor %d, cost: %d\n", myMsg->src, i,lspMAP[myMsg->src].cost[i] );
                            }

                        }

                        //send packet decreasing TTL 
                        dbg(ROUTING_CHANNEL,"Moving LSP from source %d forward, seqNum:%d TTL:%d\n" ,myMsg->src, myMsg->seq, myMsg->TTL-1);
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol,myMsg->seq, (uint8_t*) myMsg->payload, 20);
                        call Sender.send(sendPackage,AM_BROADCAST_ADDR);


                    }else{ //LSPpacket already seen
                            dbg(ROUTING_CHANNEL,"LSPPacket already recieved from %d\n", myMsg->src);
                    }



                    break;
                    case PROTOCOL_PINGREPLY:

                                neighbor Neighbor;
                                neighbor neighbor_ptr;
                
                                int i = 0;
                                bool FOUND;
                                //dbg(FLOODING_CHANNEL,"received pingreply from %d\n", myMsg->src);
                
                                //dbg(FLOODING_CHANNEL,"%d received from %d\n",TOS_NODE_ID,myMsg->src);
               
                
               
                
               
                

                                FOUND = FALSE; //IF FOUND, we switch to TRUE
                                size = call NeighborList.size();
                    
                                //increase life of neighbors
                                for(i = 0; i < call NeighborList.size(); i++) {
				                    neighbor_ptr = call NeighborList.get(i);
				                    neighbor_ptr.Life++;
                                    if(neighbor_ptr.Node == myMsg->src){
                                        FOUND = TRUE;
                                        neighbor_ptr.Life = 0;
                                    }
			                    }

                        
                    
                                if(FOUND){
                                        dbg(NEIGHBOR_CHANNEL,"Neighbor %d found in list\n", myMsg->src);
                                }else{
                                        Neighbor.Node = myMsg->src;
                                        Neighbor.Life = 0;
                                        call NeighborList.pushfront(Neighbor); //at index 0
                                        dbg(FLOODING_CHANNEL,"NEW Neighbor: %d and Life %d\n",Neighbor.Node,Neighbor.Life);
                                        
                                }
                    
                    
                    

                    
                                //Check if neighbors havent been called or seen in a while, if 5 pings occur and neighbor is not heard from, we drop it

			                    for(i = 0; i < call NeighborList.size(); i++) {
			        	                neighbor_ptr = call NeighborList.get(i);
				        
                        
				                        if(neighbor_ptr.Life > 5) {
					                    call NeighborList.remove(i);
					                    dbg(NEIGHBOR_CHANNEL, "Node %d life has expired dropping from NODE %d list\n", neighbor_ptr.Node, TOS_NODE_ID);
					
					                    //i--;
					                    //size--;
				                        }
			                    }


                    break;
                    default:
                        dbg(ROUTING_CHANNEL, "ERROR\n");
                    break;
                }
            }else if(myMsg->protocol == PROTOCOL_PINGREPLY){ //ack message
                  if(myMsg->dest == TOS_NODE_ID){ //ACK reached source
                      makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                      //dbg(FLOODING_CHANNEL,"Node %d recieved ACK from %d\n", TOS_NODE_ID,myMsg->src);
                      if(!checkPacket(sendPackage)){
                          dbg(FLOODING_CHANNEL,"Node %d recieved ACK from %d\n", TOS_NODE_ID,myMsg->src);
                       //dbg(FLOODING_CHANNEL,"Dropping Packet from src: %d to dest: %d with seq num:%d\n", myMsg->src,myMsg->dest,myMsg->seq);
                    }
                  }else{
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL - 1,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                  }

            }
            
            return msg;
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }
    
    
    event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        //sendPackage.seq = seqNum;
        makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        //call Hash.insert(TOS_NODE_ID,seqNum);
        //dbg(FLOODING_CHANNEL, "seqNumAfter: %d\n", seqNum);
        seqNum++;
    }
    
    event void CommandHandler.printNeighbors()
    {
        printNeighborList();
    }
    
    event void CommandHandler.printRouteTable(){}
    
    event void CommandHandler.printLinkState(){}
    
    event void CommandHandler.printDistanceVector(){}
    
    event void CommandHandler.setTestServer(){}
    
    event void CommandHandler.setTestClient(){}
    
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

    bool checkPacket(pack Packet){
            pack PacketMatch;
            //pack* package_PTR = &Packet;
            //pack Packet = Packet;
            if(call SeenPackList.isEmpty()){
            
                call SeenPackList.pushfront(Packet);
                return FALSE;
            }else{
                int i;
                int size = call SeenPackList.size();
                for(i = 0; i < size; i++){
                    PacketMatch = call SeenPackList.get(i);
                    if( (PacketMatch.src == Packet.src) && (PacketMatch.dest == Packet.dest) && (PacketMatch.seq == Packet.seq) && (PacketMatch.protocol== Packet.protocol)){
                        //dbg(FLOODING_CHANNEL,"Packet src %d vs PacketMatch src %d\n", Packet->src,PacketMatch->src);
                        //dbg(FLOODING_CHANNEL,"Packet destination %d vs PacketMatch dest %d\n", Packet->dest,PacketMatch->dest);
                        //dbg(FLOODING_CHANNEL,"Packet seq %d vs PacketMatch seq %d\n", Packet->seq,PacketMatch->seq);
                        //call SeenPackList.remove(i);
                        return TRUE; //packet is found in list and has already been seen by node.

                    }

                }
    
                
            }
            //other wise packet not found and we need to push it into seen pack list
                call SeenPackList.pushfront(Packet);
                return FALSE;
    }
    
    void neighborDiscovery(){
        
    
        char* dummyMsg = "NULL\n";

       dbg(NEIGHBOR_CHANNEL, "Neighbor Discovery: checking node %d list for its neighbors\n", TOS_NODE_ID);
		
			
		
		

        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PINGREPLY, -1, dummyMsg, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        if (printNodeNeighbors)
        {
            printNodeNeighbors = FALSE;
            printNeighborList();
        }
        else
        {
            printNodeNeighbors = TRUE;
            
        }
    }

    void printNeighborList()
    {
        int i;
        neighbor neighPtr;
        if(call NeighborList.size() == 0 ){
            dbg(NEIGHBOR_CHANNEL,"No neighbors for node %d\n", TOS_NODE_ID);

        }else{
            dbg(NEIGHBOR_CHANNEL,"Neighbors for node %d\n",TOS_NODE_ID);
             
        for(i = 0; i < call NeighborList.size(); i++)
        {
            neighPtr = call NeighborList.get(i);
            dbg(NEIGHBOR_CHANNEL,"NeighborNode: %d\n", neighPtr.Node);
        }
        }
        
    }
    void lspMapInit(lspMap* list, int id){
        int i;
        for(i = 0; i < 20; i++){
            list[id].cost[i] = -1; //initialize to "infinity" 
        }
    }
    
    void lspNeighborDiscoveryPacket(){
        int i;
        //initialize cost of every node to TOS_NODE_ID to "infinity"
        uint8_t lspCostList[20] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1}; //CHANGE NAME
        //initialize table for this node
        lspMapInit(&lspMAP, TOS_NODE_ID);
        
        //get neighbors to Node
        for(i  =0; i < call NeighborList.size(); i++){
            neighbor Neighbor = call NeighborList.get(i);
            lspCostList[Neighbor.Node] = 1;
            dbg(ROUTING_CHANNEL,"Cost to Neighbor %d: %d\n", Neighbor.Node,lspCostList[Neighbor.Node]);
            //put into overall mapping
            lspMAP[TOS_NODE_ID].cost[Neighbor.Node] = 1;
            //dbg(ROUTING_CHANNEL, "Printing neighbor: %d cost: %d\n",Neighbor.Node, lspMAP[TOS_NODE_ID].cost[Neighbor.Node]);
        }

       // send lspPacket to neighbors 
       makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR,MAX_TTL, PROTOCOL_LINKSTATE, lspSeqNum++, (uint8_t *) lspCostList, 20);
       call Sender.send(sendPackage,AM_BROADCAST_ADDR);
       dbg(ROUTING_CHANNEL, "Sending LSP: SeqNum: %d\n", lspSeqNum);

    }
    
    
    bool checkSeenLspPacks(pack Packet){
        pack PacketMatch;
            //pack* package_PTR = &Packet;
            //pack Packet = Packet;
            if(call SeenLspPackList.isEmpty()){
            
                call SeenLspPackList.pushfront(Packet);
                return FALSE;
            }else{
                int i;
                int size = call SeenLspPackList.size();
                for(i = 0; i < size; i++){
                    PacketMatch = call SeenLspPackList.get(i);//check for lsp from a certain node
                    if( (PacketMatch.src == Packet.src) && (PacketMatch.protocol == Packet.protocol)){
                        dbg(ROUTING_CHANNEL,"LspPacket src %d vs LspPacketMatch src %d\n", Packet.src,PacketMatch.src);
                        //dbg(ROUTING_CHANNEL,"Packet destination %d vs PacketMatch dest %d\n", Packet->dest,PacketMatch->dest);
                        dbg(ROUTING_CHANNEL,"LSPPacket seq %d vs LSPPacketMatch seq %d\n", Packet.seq,PacketMatch.seq);
                        //call SeenPackList.remove(i);
                        //check if current lsp seqnum is greater or less 
                        if(PacketMatch.seq == Packet.seq) return TRUE;//already in list
                        if(PacketMatch.seq < Packet.seq){//we got a new and updated lsp add to list     
                            call SeenLspPackList.remove(i);
                            call SeenLspPackList.pushback(Packet);
                            return FALSE;
                        }
                        return TRUE; //packet is found in list and has already been seen by node.

                    }

                }
    
                
            }
            //other wise packet not found and we need to push it into seen pack list
                call SeenLspPackList.pushfront(Packet);
                return FALSE;
    }
    
   
    
}