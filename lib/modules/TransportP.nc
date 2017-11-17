#include "../../includes/socket.h"
#include "../../Node.nc"

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
		// Temp Socket struct.
		socketStruct tempSocket; 
		
		// Check if there is space available to get a socket.
		if(call SocketList.size() < MAX_NUM_OF_SOCKETS)
		{
			// Give the socket the File Descripter id of the last index in the list.
			tempSocket.fd = call SocketList.size();
			
			// Place the socket in the list.
			call SocketList.pushback(tempSocket);
			
			dbg(TRANSPORT_CHANNEL, "Socket %d allocated.\n", tempSocket.fd);
			
			// Return the fd.
			return tempSocket.fd;
		}
		
		dbg(TRANSPORT_CHANNEL, "No space available, cannot allocate socket.\n");
		
		// If this point is reached, there is no space available.
		return NULL;
		
	} // End socket().
	
	command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
	{
		// Temp Socket struct.
		socketStruct tempSocket;
		
		// Temp Socket address struct.
		socket_addr_t tempSocketAddr;
		
		// Iterator.
		int i;
		
		// Go through the list, and find the appropriate Socket fd.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			if (fd == tempSocket.fd)
			{
				// Take out the appropriate Socket from the list.
				tempSocket = call SocketList.remove(i);
				
				// Modify the Socket.
				tempSocket.socketState.dest = *addr;
				
				// Put it back in.
				call SocketList.pushback(tempSocket);
				
				dbg(TRANSPORT_CHANNEL, "Socket %d bound.\n", fd);
				
				return SUCCESS;
			}
		}
		
		// If this point is reached, it was unable to bind the socket.
		return FAIL;

	} // End bind.
	
	command socket_t Transport.accept(socket_t fd)
	{
		// Temp Socket struct.
		socketStruct tempSocket;
		
		// Iterator.
		int i;
		
		// Go through the list, and find the appropriate Socket fd.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			// Must also check if the Socket is listening.
			if(fd == tempSocket.fd && tempSocket.socketState.state == LISTEN)
			{
				dbg(TRANSPORT_CHANNEL, "Socket %d is available and listening, accepting connection.\n", fd);
			
				// Found the Socket, return a copy of its fd.
				return tempSocket.fd;
			}
		}
		
		dbg(TRANSPORT_CHANNEL, "Socket %d was either unavailable or not listening, cannot connect.\n", fd);
		
		// If this point is reached, it was unable to accept the connection.
		return NULL;
		
		
	} // End accept.
	
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{

	} // End write.
	
	command error_t Transport.receive(pack* package)
	{
	
	} // End receive.
	
	command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
	
	} // End read.
	
	command error_t Transport.connect(socket_t fd, socket_addr_t *addr)
	{
		// The SYN packet that must be sent out.
		//pack SYN;
		int i;
		//Error test.
		i = confirmedList.entries;
		
	} // End connect.
	
	command error_t Transport.close(socket_t fd)
	{

	} // End close.
	
	command error_t Transport.release(socket_t fd)
	{
	
	} // End release.
	
	command error_t Transport.listen(socket_t fd)
	{

	} // End listen.

} // End implementation.
