#include "../../includes/socket.h"
#include "../../includes/am_types.h"

configuration TransportC
{
	provides interface Transport;
	
	// Data Structrures.
	uses interface List<socketStruct> as SocketsInterface;
}

implementation
{
	// Main components.
	components TransportP;
	Transport = TransportP;
	
	// Data Structures.
	TransportP.SocketList = SocketsInterface;
	
	components new SimpleSendC(AM_PACK);
	TransportP.Sender -> SimpleSendC;
}
