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

configuration NodeC{}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components ActiveMessageC;
    components new SimpleSendC(AM_PACK);
    components CommandHandlerC;
    
    
    Node -> MainC.Boot;
    Node.Receive -> GeneralReceive;
    Node.AMControl -> ActiveMessageC;
    Node.Sender -> SimpleSendC;
    Node.CommandHandler -> CommandHandlerC;
    
    
    // Data Structure Component Aliases.
    components new ListC(neighbor,100) as NeighborListComp;
    components new ListC(pack,100) as SeenLSPPackListComp;
    components new ListC(pack, 64) as PacketListC;
    
    // Timer Component Aliases.
    components new TimerMilliC() as myTimerC;
    components new TimerMilliC() as lspTimer;
    components RandomC as Random;
    
    // Data Structure Component Wiring.
    Node.NeighborList -> NeighborListComp;
    Node.SeenLspPackList->SeenLSPPackListComp;
    Node.SeenPackList -> PacketListC;
    
    // Timer Component Wiring.
    Node.Random -> Random;
    Node.lspTimer -> lspTimer;
    Node.Timer1 -> myTimerC;
        
}
