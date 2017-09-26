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

module Node{
    uses interface Boot;
    
    uses interface Timer<TMilli> as periodicTimer; //Interface that was wired above.
    
    uses interface SplitControl as AMControl;
    uses interface Receive;
    uses interface List<int> as NeighborList;
    uses interface List<int> as CheckList;
    
    uses interface Hashmap<int> as Hash;
    
    uses interface SimpleSend as Sender;
    
    uses interface CommandHandler;
}

implementation{
    pack sendPackage;
    int sequence = 0;
    bool printTime = FALSE;
    bool first = TRUE;
    
    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void printNeighbors();
    void printCheckList();
    void deleteCheckList();
    void deleteNeighborList();
    void compareLists();
    void neighborDiscovery();

    event void Boot.booted(){
        call AMControl.start();
        dbg(GENERAL_CHANNEL, "Booted\n");

        call periodicTimer.startPeriodicAt(1,1500);
        dbg(NEIGHBOR_CHANNEL,"Timer started");
    }
   
    event void periodicTimer.fired()
    {
       neighborDiscovery();
    }
    
    
    
    event void AMControl.startDone(error_t err){
        if(err == SUCCESS){
            dbg(GENERAL_CHANNEL, "Radio On\n");
            //call periodicTimer.startPeriodic(100000);
        }else{
            //Retry until successful
            call AMControl.start();
        }
    }
    
    event void AMControl.stopDone(error_t err){
    }
    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        //dbg(GENERAL_CHANNEL, "Packet Received\n");
        
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
                    //makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
                    
                    makePack(&sendPackage, myMsg->src, myMsg->dest, 0, PROTOCOL_PING, myMsg->seq, &myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                }
            }
            else if (myMsg->protocol == PROTOCOL_PINGREPLY)
            {
                int size = call CheckList.size();
                int i = 0;
                
                //dbg(FLOODING_CHANNEL,"received pingreply\n");
                for (i = 0; i < size; i++)
                {
                    if (call CheckList.get(i) == myMsg->src){
                       dbg(NEIGHBOR_CHANNEL,"hello %d\n", msg);
                       return msg;
                    }
                        
                }
                
                //dbg(FLOODING_CHANNEL,"%d received from %d\n",TOS_NODE_ID,myMsg->src);
                call CheckList.pushfront(myMsg->src);
            }
            
            return msg;
        }
        dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }
    
    
    event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        
        makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        call Hash.insert(TOS_NODE_ID,sequence);
        //printNeighbors();
        sequence = sequence + 1;
    }
    
    event void CommandHandler.printNeighbors()
    {
        printCheckList();
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
         uint8_t wow[2];
        wow[0] = 'W';
        wow[1] = 'O';
        
        
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PINGREPLY, -1, wow, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        if (printTime)
        {
            printTime = FALSE;
            printCheckList();
        }
        else
        {
            printTime = TRUE;
            compareLists();
        }
    }

    void printCheckList()
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
    
    
    
    void compareLists()
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