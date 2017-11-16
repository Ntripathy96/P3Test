#include "../../includes/socket.h"

module TransportP
{
	// Main interfaces.
	provides interface Transport;
	uses interface SimpleSend as Sender;
	
	// Data Structures.
	uses interface List<socketStruct> as SocketList;
	
}

implementation
{
	
	command socket_t Transport.socket()
	{
		// Temp Socket variable.
		socketStruct tempSocket; 
		
		// Check if there is space available to get a socket.
		if(call SocketList.size() < MAX_NUM_OF_SOCKETS)
		{
			// Give the socket the File Descripter id of the last index in the list.
			tempSocket.fd = call SocketList.size();
			
			// Place the socket in the list.
			call SocketList.pushback(tempSocket);
			
			// Return the fd.
			return tempSocket.fd;
		}
		
		// If this point is reached, there is no space available.
		return NULL;
	} // End socket().
	
	command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
	{
		return FAIL;
	} // End bind.
	
	command error_t Transport.accept(socket_t fd)
	{
		return FAIL;
	} // End accept.
	
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
		return FAIL;
	} // End write.
	
	command uint16_t Transport.connect(socket_t fd, socket_addr_t *addr)
	{
		return 100;
	} // End connect.
	
	command error_t Transport.close(socket_t fd)
	{
		return FAIL;
	} // End close.
	
	command error_t Transport.listen(socket_t fd)
	{
		return FAIL;
	} // End listen.

} // End implementation.
