#include "../../includes/socket.h"

configuration TransportC
{
	provides interface Transport;
	
	// Data Structrures.
	uses interface List<socketStruct> as SocketsInterface;
}

implementation
{
	// Main component wiring.
	components TransportP;
	Transport = TransportP;
	
	// Data Structure wiring.
	TransportP.SocketList = SocketsInterface;
}
