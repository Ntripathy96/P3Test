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
    components new ListC(neighbor,100) as List;
    components new ListC(pack,100) as List2;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as myTimerC;
    components new TimerMilliC() as lspTimer;
    components RandomC as Random;

    Node -> MainC.Boot;
    Node.Random -> Random;
    Node.lspTimer -> lspTimer;
    Node.Receive -> GeneralReceive;
    
    //Node.Hash -> HashC;
    Node.NeighborList -> List;
    Node.SeenLspPackList->List2;
    
    Node.Timer1 -> myTimerC;
    
    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;
    
    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;
    
    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
     //add component for seenPacketList
    components new ListC(pack, 64) as PacketListC;
    Node.SeenPackList -> PacketListC;
}
