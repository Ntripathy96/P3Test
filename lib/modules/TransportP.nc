#include "../../includes/socket.h"

module TransportP
{
	// Main interfaces.
	provides interface Transport;
	uses interface SimpleSend as Sender;
	
	// Data Structures.
	uses interface List<socket_store_t> as SocketList;
	
}

implementation
{
	
	command socket_t Transport.socket()
	{
		// Temp Socket variable.
		socket_store_t socket;
		
		// Check if there is space available to get a socket.
		if(call SocketList.size() < MAX_NUM_OF_SOCKETS)
		{
			// Give the socket the File Descripter id of the last index in the list.
			socket.fd = call SocketList.size();
			
			// Place the socket in the list.
			call SocketList.pushback(socket);
			
			// Return the fd.
			return socket.fd;
		}
		
		// If this point is reached, there is no space available.
		return NULL;
	} // End socket().
	
	command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
	{
	
	} // End bind.
	
	command error_t Transport.accept(socket_t fd)
	{
	
	} // End accept.
	
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
	
	} // End write.
	
	command uint16_t Transport.connect(socket_t fd, socket_addr_t *addr)
	{
		
	} // End connect.
	
	command error_t Transport.close(socket_t fd)
	{
	
	} // End close.
	
	command error_t Transport.listen(socket_t fd)
	{
	
	} // End listen.

} // End implementation.
