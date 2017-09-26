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

 typedef nx_struct neighbor {
    nx_uint16_t Node;
    nx_uint8_t Life;
}neighbor;

module Node{
    uses interface Boot;
    
    uses interface Timer<TMilli> as Timer1; //Interface that was wired above.
    
    uses interface SplitControl as AMControl;
    uses interface Receive;
    uses interface List<neighbor*> as NeighborList;
    uses interface List<int> as CheckList;
    
    uses interface Hashmap<int> as Hash;
    
    uses interface SimpleSend as Sender;
    
    uses interface CommandHandler;
}

implementation{
    pack sendPackage;
    int seqNum = 0;
    bool printNodeNeighbors = FALSE;
    //bool first = TRUE;
    
    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void printNeighbors();
    void printNeighborList();
    void deleteCheckList();
    void deleteNeighborList();
    void compare();
    void neighborDiscovery();

    event void Boot.booted(){
        call AMControl.start();
        dbg(GENERAL_CHANNEL, "Booted\n");
    }
   
    event void Timer1.fired()
    {
       neighborDiscovery();
    }
    
    
    
    event void AMControl.startDone(error_t err){
        if(err == SUCCESS){
            dbg(GENERAL_CHANNEL, "Radio On\n");
            call Timer1.startPeriodic(100000);
        }else{
            //Retry until successful
            call AMControl.start();
        }
    }
    
    event void AMControl.stopDone(error_t err){
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        //dbg(GENERAL_CHANNEL, "Packet Received\n");
         
                int size = call CheckList.size();
                

        if(len==sizeof(pack)){
            pack* myMsg=(pack*) payload;
            //dbg(GENERAL_CHANNEL, "Packet received from %d\n",myMsg->src);
            
            //dbg(FLOODING_CHANNEL, "Packet being flooded to %d\n",myMsg->dest);
            
            if (!call Hash.contains(myMsg->src))
                call Hash.insert(myMsg->src,-1);
            
            if (call Hash.get(myMsg->src) < myMsg->seq && myMsg->protocol != PROTOCOL_PINGREPLY)
            {
                // This is what causes the flooding
                
                //dbg(FLOODING_CHANNEL,"Packet is new and hasn't been seen before by node %d\n",TOS_NODE_ID);
                
                call Hash.remove(myMsg->src);
                call Hash.insert(myMsg->src,myMsg->seq);
                
                if (myMsg->dest == TOS_NODE_ID)
                {
                    // This is when the flooding of a packet has finally led it to it's final destination
                    
                    dbg(FLOODING_CHANNEL, "Packet has finally flooded to correct location, from:to, %d:%d\n", myMsg->src,TOS_NODE_ID);
                    dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
                }
                else
                {
                    //makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
                    
                    makePack(&sendPackage, myMsg->src, myMsg->dest, 0, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                }
            }
            else if (myMsg->protocol == PROTOCOL_PINGREPLY)
            {
                
                
                neighbor *Neighbor, *neighbor_ptr;
                
                int i = 0;
                bool FOUND;
                //dbg(FLOODING_CHANNEL,"received pingreply\n");
                for (i = 0; i < size; i++)
                {
                    if (call CheckList.get(i) == myMsg->src){
                       //dbg(NEIGHBOR_CHANNEL,"hello %d\n", msg);
                       return msg;
                    }
                        
                }
                call CheckList.pushfront(myMsg->src);
                dbg(FLOODING_CHANNEL,"%d received from %d\n",TOS_NODE_ID,myMsg->src);
               
                
                FOUND = FALSE; //IF FOUND, we switch to TRUE
                
                Neighbor = &myMsg->src;
                Neighbor->Node = myMsg->src;
                //Neighbor->Life = 0;
                //call NeighborList.pushfront(Neighbor);
                dbg(FLOODING_CHANNEL,"Neighbor: %d and Life %d\n",Neighbor->Node,Neighbor->Life);

                   
                
            }
            
            return msg;
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }
    
    
    event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        
        makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        call Hash.insert(TOS_NODE_ID,seqNum);
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

    
    void neighborDiscovery(){
        uint16_t size = call NeighborList.size();
			uint16_t i = 0;
			uint16_t life = 0;
			neighbor* myNeighbor;
			neighbor* tempNeighbor;
    
        char* dummyMsg = "NULL\n";

       
		

        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PINGREPLY, -1, dummyMsg, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        if (printNodeNeighbors)
        {
            printNodeNeighbors = FALSE;
            printNeighborList();
        }
        else
        {
            printNodeNeighbors = TRUE;
            //compare();
        }
    }

    void printNeighborList()
    {
        int i = 0;
        
        dbg(NEIGHBOR_CHANNEL,"Neighbors for node %d\n",TOS_NODE_ID);
        
        for(i = 0; i < call CheckList.size(); i++)
        {
            dbg(NEIGHBOR_CHANNEL,"Node: %d\n",call CheckList.get(i));
        }
    }
    
    void deleteCheckList()
    {
        while(!call CheckList.isEmpty())
        {
            call CheckList.popfront();
        }
    }
    void deleteNeighborList()
    {
        while(!call NeighborList.isEmpty())
        {
            call NeighborList.popfront();
        }
    }
    
    
    
    void compare()
    {
        int i = 0;
        
        deleteNeighborList();
        
        for (i = 0; i < call CheckList.size(); i++)
        {
            call NeighborList.pushfront(call CheckList.get(i));
        }
        
        deleteCheckList();
    }
    
}