/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new HashmapC(int,100) as HashC;
    components new ListC(int,100) as List;
    components new ListC(int,100) as List2;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
    
    Node -> MainC.Boot;
    
    Node.Receive -> GeneralReceive;
    
    Node.Hash -> HashC;
    Node.NeighborList -> List;
    Node.CheckList->List2;
    
    Node.periodicTimer -> myTimerC; //Wire the interface to the component
    
    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;
    
    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;
    
    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
}