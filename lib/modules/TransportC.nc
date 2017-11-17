#include "../../includes/socket.h"
#include "../../includes/am_types.h"

configuration TransportC
{
	provides interface Transport;
}

implementation
{
	// Main components.
	components TransportP;
	Transport = TransportP;
	
	// Data Structures.
	components new ListC(socketStruct, MAX_NUM_OF_SOCKETS) as SocketsInterface;
	TransportP.SocketList -> SocketsInterface;
	
	components new SimpleSendC(AM_PACK);
	TransportP.Sender -> SimpleSendC;
}
