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
//#include "includes/list.h"
#include "includes/lspTable.h"


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
    bool netChange = FALSE;
    //int MAX_NODES = 20;
    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void printNeighbors();
    void printNeighborList();
    
    void neighborDiscovery();
    bool checkPacket(pack Packet);

    //project 2 START 
    
    void lspNeighborDiscoveryPacket();
    lspMap lspMAP[20]; //change NAME, overall map of network stored at every node
    int lspSeqNum = 0;
    bool checkSeenLspPacks(pack Packet);
    lspTable confirmedList;
	lspTable tentativeList;
    float cost[20];
	int lastSequenceTracker[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

    void printlspMap(lspMap *list);
	
	void dijkstra();
	int forwardPacketTo(lspTable* list, int dest);
	void printCostList(lspMap *list, uint8_t nodeID);
	float EMA(float prevEMA, float now,float weight);
    //------Project 2-------//END

    event void Boot.booted(){
        call AMControl.start();
        dbg(GENERAL_CHANNEL, "Booted\n");
    }
   
    event void Timer1.fired()
    {
        
       if(!netChange){
           dbg(ROUTING_CHANNEL,"NEIGBOR: Timer1.Time %d\n", call Timer1.getNow());
            neighborDiscovery();
       }else{
           dbg(ROUTING_CHANNEL,"LSP Timer1.Time %d\n", call Timer1.getNow());
            lspNeighborDiscoveryPacket();
            netChange = FALSE;
       } 
    }
    event void lspTimer.fired(){
        //if(!call Timer1.isRunning()){
          //if(netChange) lspNeighborDiscoveryPacket(); //change name
           
        //}else
            //check if time gets too great
            //if(call Timer1.getNow() >= (2*1000)){
            dbg(ROUTING_CHANNEL,"lspTimer1.Time %d\n", call lspTimer.getNow());
            lspNeighborDiscoveryPacket();
            //call Timer1.stop();
        //}
        
        
        
    }
    
    
    event void AMControl.startDone(error_t err){
        if(err == SUCCESS){
            dbg(GENERAL_CHANNEL, "Radio On\n");
            call Timer1.startPeriodic(5333 + (uint16_t)((call Random.rand16())%200));
            //call Timer1.startPeriodic(100000);
            //call lspTimer.startPeriodic(5333 + (uint16_t)((call Random.rand16())%200));
            //call lspTimer.startPeriodic(100000);
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
                dbg(FLOODING_CHANNEL,"TTL=0: Dropping Packet\n");
            }
            
            else if (myMsg->protocol == PROTOCOL_PING) //flooding
            {
                // This is what causes the flooding
                
               // dbg(FLOODING_CHANNEL,"Packet Received from %d meant for %d... Rebroadcasting\n",myMsg->src, myMsg->dest);
                int forwardTo;
                
                
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
                        dbg(FLOODING_CHANNEL, "Sending Ping Reply to %d! \n\n", myMsg->src);
					dbg(ROUTING_CHANNEL,"Running dijkstra\n");
					dijkstra();
					dbg(ROUTING_CHANNEL,"END\n\n"); 
					forwardTo = forwardPacketTo(&confirmedList,myMsg->src);
                    
                    dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
                    makePack(&sendPackage, TOS_NODE_ID, myMsg->src, 20,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage, forwardTo);
                    
                    //dbg(FLOODING_CHANNEL, "SendPackage: %d\n", sendPackage.seq);
                    //dbg(FLOODING_CHANNEL, "seqNum: %d\n", seqNum);
                    }
                }
                else //not meant for this node forward to correct nextHop
                {   int forwardTo;
                    makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    if(checkPacket(sendPackage)){//return true meaning packet found in SeenPackList
                        dbg(FLOODING_CHANNEL,"ALREADY SEEN: Dropping Packet from src: %d to dest: %d with seq num:%d\n", myMsg->src,myMsg->dest,myMsg->seq);
                        //dbg(FLOODING_CHANNEL,"ALREADY SEEN: Dropping Packet from src: %d to dest: %d\n", myMsg->src,myMsg->dest);
                    }else{ //
                        //makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
                    dbg(FLOODING_CHANNEL,"Packet Recieved from %d meant for %d, Sequence Number %d...Rebroadcasting\n",myMsg->src, myMsg->dest, myMsg->seq);
                    //int forwardTo;
				       
				        dbg(ROUTING_CHANNEL,"Running dijkstra\n");
				            dijkstra();
				        dbg(ROUTING_CHANNEL,"END\n\n"); 
				        forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);
				        dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, myMsg->src);
				        if(forwardTo == 0) printCostList(&lspMAP, TOS_NODE_ID);
				        if(forwardTo == -1){
					        dbg(ROUTING_CHANNEL, "rechecking \n");
					        dijkstra();
					        forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);
					        if(forwardTo == -1)
						        dbg(ROUTING_CHANNEL, "Dropping for reals\n");
					        else{
						        dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
						        call Sender.send(sendPackage, forwardTo);
						        
					        }
				        }
				    else{
					        dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
					        call Sender.send(sendPackage, forwardTo);
					        
				    }
                    //dbg(FLOODING_CHANNEL,"Packet Recieved from %d meant for %d... Rebroadcasting\n",myMsg->src, myMsg->dest);
                    

                    
                    }
                    

                }
            }
            else if (myMsg->dest == AM_BROADCAST_ADDR) //neigbor discovery OR LSP
            {
                
                if(myMsg->protocol == PROTOCOL_LINKSTATE){
                    
                    int j, l;
                    
                    if(!checkSeenLspPacks(sendPackage)){ 
                        //initialize table for src 
                        lspMapInit(&lspMAP, myMsg->src);
                        dbg(ROUTING_CHANNEL,"LSP from %d, seqNum: %d\n", myMsg->src, myMsg->seq);
                            if(myMsg->src == TOS_NODE_ID){
                                dbg(ROUTING_CHANNEL,"Drop\n");
                            }else{
                                for(j = 0; j <20; j++){ //put neigbors and cost node knows
                                    lspMAP[myMsg->src].cost[j] = myMsg->payload[j];
                                    if(lspMAP[myMsg->src].cost[j] != 255 || lspMAP[myMsg->src].cost[j] != 0 ){
                                //dbg(ROUTING_CHANNEL, "%d Neighbor %d, cost: %d\n", myMsg->src, j,lspMAP[myMsg->src].cost[j] );
                            }

                        }
                        //if(TOS_NODE_ID == 19){
                            for(l = 1; l < 20; l++){
                                for(j = 1; j <20; j++){ //put neigbors and cost node knows
                                    
                                    if(lspMAP[l].cost[j] != 255 && lspMAP[l].cost[j] != 0){
                                        dbg(ROUTING_CHANNEL, "%d Neighbor %d, cost: %d\n",  l,j,lspMAP[l].cost[j] );
                                    }

                                 }
                            }
                        //}
                            

                        //send packet decreasing TTL 
                        dbg(ROUTING_CHANNEL,"Moving LSP from source %d forward, seqNum:%d TTL:%d\n" ,myMsg->src, myMsg->seq, myMsg->TTL-1);
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol,myMsg->seq, (uint8_t*) myMsg->payload, 20);
                        call Sender.send(sendPackage,AM_BROADCAST_ADDR);
                            }   
                        


                    }else{ //LSPpacket already seen
                            dbg(ROUTING_CHANNEL,"LSPPacket already recieved from %d\n", myMsg->src);
                    }
                }else if(myMsg->protocol == PROTOCOL_PINGREPLY){
                        neighbor Neighbor;
                                neighbor neighbor_ptr;
                
                                int k = 0;
                                bool FOUND;
                                //dbg(FLOODING_CHANNEL,"received pingreply from %d\n", myMsg->src);
                
                                //dbg(FLOODING_CHANNEL,"%d received from %d\n",TOS_NODE_ID,myMsg->src);
               
                
               
                
               
                

                                FOUND = FALSE; //IF FOUND, we switch to TRUE
                                size = call NeighborList.size();

                                //increase life of neighbors
                                for(k = 0; k < call NeighborList.size(); k++) {
				                    neighbor_ptr = call NeighborList.get(k);
				                    neighbor_ptr.Life++;
                                    if(neighbor_ptr.Node == myMsg->src){
                                        FOUND = TRUE;
                                        neighbor_ptr.Life = 0;
                                    }
			                    }

                        
                    
                                if(FOUND){
                                        dbg(NEIGHBOR_CHANNEL,"Neighbor %d found in list\n", myMsg->src);
                                        netChange = FALSE;
                                }else{
                                        Neighbor.Node = myMsg->src;
                                        Neighbor.Life = 0;
                                        call NeighborList.pushfront(Neighbor); //at index 0
                                        dbg(FLOODING_CHANNEL,"NEW Neighbor: %d and Life %d\n",Neighbor.Node,Neighbor.Life);
                                        netChange = TRUE; //network change!
                                        dbg(ROUTING_CHANNEL,"NETWORK CHANGE\n");
                                        
                                        
                                }
                    
                    
                    

                    
                                //Check if neighbors havent been called or seen in a while, if 5 pings occur and neighbor is not heard from, we drop it

			                    for(k = 0; k < call NeighborList.size(); k++) {
			        	                neighbor_ptr = call NeighborList.get(k);
				        
                        
				                        if(neighbor_ptr.Life > 5) {
					                    call NeighborList.remove(k);
					                    dbg(NEIGHBOR_CHANNEL, "Node %d life has expired dropping from NODE %d list\n", neighbor_ptr.Node, TOS_NODE_ID);
                                        dbg(ROUTING_CHANNEL, "CHANGE IN TOPOLOGY\n");
                                        netChange = TRUE;
					
					                    //i--;
					                    //size--;
				                        }
			                    }
                }else{
                        dbg(ROUTING_CHANNEL, "ERROR\n");
                }   
                    
                
            }else if(myMsg->protocol == PROTOCOL_PINGREPLY){ //ack message
                    int forwardTo;
                  if(myMsg->dest == TOS_NODE_ID){ //ACK reached source
                      makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                      //dbg(FLOODING_CHANNEL,"Node %d recieved ACK from %d\n", TOS_NODE_ID,myMsg->src);
                      if(!checkPacket(sendPackage)){
                          dbg(FLOODING_CHANNEL,"Node %d recieved ACK from %d\n", TOS_NODE_ID,myMsg->src);
                       //dbg(FLOODING_CHANNEL,"Dropping Packet from src: %d to dest: %d with seq num:%d\n", myMsg->src,myMsg->dest,myMsg->seq);
                        }
                  }else{
                      dbg(FLOODING_CHANNEL, "Sending Ping Reply to %d! \n\n", myMsg->src);
					dbg(ROUTING_CHANNEL,"Running dijkstra\n");
					dijkstra();
					dbg(ROUTING_CHANNEL,"END\n\n"); 
					forwardTo = forwardPacketTo(&confirmedList,myMsg->src);
                    dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
                        makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL - 1,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                        call Sender.send(sendPackage, forwardTo);
                  }

            }
            
            return msg;
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }
    
    
    event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
        int forwardTo;
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        
        makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        dbg(ROUTING_CHANNEL,"Running dijkstra\n");
					dijkstra();
					dbg(ROUTING_CHANNEL,"END\n\n\n\n\n"); 
					forwardTo = forwardPacketTo(&confirmedList,destination);
                    dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
        call Sender.send(sendPackage, forwardTo);
        
        
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
            //dbg(ROUTING_CHANNEL,"LSPCOSTLIST: Cost to Neighbor %d: %d\n", Neighbor.Node,lspCostList[Neighbor.Node]);
            //put into overall mapping
            lspMAP[TOS_NODE_ID].cost[Neighbor.Node] = 1;
            dbg(ROUTING_CHANNEL, "Printing neighbor: %d cost: %d\n",Neighbor.Node, lspMAP[TOS_NODE_ID].cost[Neighbor.Node]);
        }

       // send lspPacket to neighbors 
       if(!call NeighborList.isEmpty()){
           lspSeqNum++;
       dbg(ROUTING_CHANNEL, "Sending LSP: SeqNum: %d\n", lspSeqNum);
       makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR,20, PROTOCOL_LINKSTATE, lspSeqNum, (uint8_t *) lspCostList, 20);
       call Sender.send(sendPackage,AM_BROADCAST_ADDR);
       }else{
           dbg(ROUTING_CHANNEL,"No neighbors so cant create LSP\n");
       }
       
       

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
                        //dbg(ROUTING_CHANNEL,"LspPacket src %d vs LspPacketMatch src %d\n", Packet.src,PacketMatch.src);
                        //dbg(ROUTING_CHANNEL,"Packet destination %d vs PacketMatch dest %d\n", Packet->dest,PacketMatch->dest);
                        //dbg(ROUTING_CHANNEL,"LSPPacket seq %d vs LSPPacketMatch seq %d\n", Packet.seq,PacketMatch.seq);
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
    
    void dijkstra(){
		int i;	
		lspTuple lspTup, temp;
		lspTableinit(&tentativeList); lspTableinit(&confirmedList);
		dbg(ROUTING_CHANNEL,"start of dijkstra \n");
		lspTablePushBack(&tentativeList, temp = (lspTuple){TOS_NODE_ID,0,TOS_NODE_ID});
		dbg(ROUTING_CHANNEL,"PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
		while(!lspTableIsEmpty(&tentativeList)){
			if(!lspTableContains(&confirmedList,lspTup = lspTupleRemoveMinCost(&tentativeList))) //gets the minCost node from the tentative and removes it, then checks if it's in the confirmed list.
				if(lspTablePushBack(&confirmedList,lspTup))
					dbg(ROUTING_CHANNEL,"PushBack from confirmedList dest:%d cost:%d nextHop:%d \n", lspTup.dest,lspTup.nodeNcost, lspTup.nextHop);
			for(i = 1; i < 20; i++){
				temp = (lspTuple){i,lspMAP[lspTup.dest].cost[i]+lspTup.nodeNcost,(lspTup.nextHop == TOS_NODE_ID)?i:lspTup.nextHop};
				if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTupleReplace(&tentativeList,temp,temp.nodeNcost))
						dbg(ROUTING_CHANNEL,"Replace from tentativeList dest:%d cost:%d nextHop:%d\n", temp.dest, temp.nodeNcost, temp.nextHop);
				else if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTablePushBack(&tentativeList, temp))
						dbg(ROUTING_CHANNEL,"PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
			}
		}
		dbg(ROUTING_CHANNEL, "Printing the ROUTING_CHANNEL table! \n");
		for(i = 0; i < confirmedList.numValues; i++)
			dbg(ROUTING_CHANNEL, "dest:%d cost:%d nextHop:%d \n",confirmedList.lspTuples[i].dest,confirmedList.lspTuples[i].nodeNcost,confirmedList.lspTuples[i].nextHop);
		dbg(ROUTING_CHANNEL, "End of dijkstra! \n");
	}

	int forwardPacketTo(lspTable* list, int dest){	
		return lspTableLookUp(list,dest);
	}
	
	
	/**
	 * let S_1 = Y_1
	 * Exponential Moving Average
	 * S_t = alpha*Y_t + (1-alpha)*S_(t-1)
	 */	
	float EMA(float prevEMA, float now,float weight){
		float alpha = 0.5*weight;
		float averageEMA = alpha*now + (1-alpha)*prevEMA;
		return averageEMA;
	}


    void printlspMap(lspMap *list){
		int i,j;
		for(i = 0; i < 20; i++){
			for(j = 0; j < 20; j++){
				if(list[i].cost[j] != 0 && list[i].cost[j] != 255)
					dbg(ROUTING_CHANNEL, "src: %d  neighbor: %d cost: %d \n", i, j, list[i].cost[j]);
			}	
		}
		dbg(ROUTING_CHANNEL, "END \n\n");
	}
	
	void printCostList(lspMap *list, uint8_t nodeID) {
		uint8_t i;
		for(i = 0; i < 20; i++) {
			dbg(ROUTING_CHANNEL, "From %d To %d Costs %d", nodeID, i, list[nodeID].cost[i]);
		}
	}
    
}