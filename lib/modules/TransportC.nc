#include "../../includes/socket.h"

configuration TransportC
{
	provides interface Transport;
	
	// Data Structrures.
	uses interface List<socket_store_t> as SocketsInterface;
}

implementation
{
	components TransportP;
	Transport = TransportP;
}
