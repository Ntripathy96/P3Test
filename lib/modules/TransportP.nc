#include "../../includes/socket.h"
#include "../../includes/lspTable.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

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

	// A get command to access SocketList. Returns the Socket associated with the provided fd. 
	// If no such socket exists, returns NULL.
	command socketStruct Transport.getSocket(socket_t fd)
	{
		// Temp Socket Struct.
		socketStruct tempSocket;
		
		// Iterator.
		int i;
		
		// Find the Socket.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			// If this is true, the appropriate Socket has been found.
			if (fd == tempSocket.fd)
				return tempSocket;
		}
		
		// If this point is reached, it was unable to find the Socket. Return a socketStruct that will identify this.
		tempSocket.fd = -1;
		return tempSocket;
	}
	
	// A set command for SocketList. Erases old Socket associated with the provided fd in place of the updated one.
	// Caution must be used when using this. Designed to be used in tandem with the get command.
	command error_t Transport.setSocket(socket_t fd, socketStruct update)
	{
		// Temp Socket Struct.
		socketStruct tempSocket;
		
		// Iterator.
		int i;
		
		// Find the Socket.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			// If this is true, the appropriate Socket has been found.
			if (fd == tempSocket.fd)
			{
				// Remove the old Socket.
				tempSocket = call SocketList.remove(i);
				
				// Place in the updated Socket.
				call SocketList.pushback(update);
				
				return SUCCESS;
			}
		}
		
		return FAIL;
	}
	
	command socket_t Transport.socket()
	{
		// Temp Socket struct.
		socketStruct tempSocket; 
		
		// Check if there is space available to get a socket.
		if(call SocketList.size() < MAX_NUM_OF_SOCKETS)
		{
			// Give the socket the File Descripter id of the last index in the list.
			tempSocket.fd = call SocketList.size();
			
			// Initialize the Socket State.
			tempSocket.socketState.lastWritten = 0;
			tempSocket.socketState.effectiveWindow = SOCKET_BUFFER_SIZE;
			
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
				tempSocket.socketState.src = addr->port;
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
	
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen, lspTable* Table)
	{
		// Temp Socket struct.
		socketStruct tempSocket;
		
		// Iterators.
		int i, j, k;
		
		// Space left on the buffer.
		int spaceRemaining;
		
		// DATA packet to be written to.
		pack DATA;
		
		// Next hop for the destination.
		uint16_t nextHop;
		
		// Go through the list, and find the appropriate Socket fd.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			if (fd == tempSocket.fd)
			{
				// Take out the appropriate Socket from the list.
				tempSocket = call SocketList.remove(i);
				
				// Start at the last written portion of the buffer.
				k = tempSocket.socketState.lastWritten + 1;
				
				// Calculate how much space is left on the buffer.
				spaceRemaining = SOCKET_BUFFER_SIZE - k;
				
				dbg(TRANSPORT_CHANNEL, "Node %d writing onto socket.\n", TOS_NODE_ID);

				// Now it can write to the buffer.
				for(j = 0; j < bufflen; j++)
				{
					tempSocket.socketState.sendBuff[k] = buff[j];
					k++;
					spaceRemaining--;
					
					if(spaceRemaining == 0)
						break;
				}

				tempSocket.socketState.lastWritten = k;
				tempSocket.socketState.flag = 4;

				dbg(TRANSPORT_CHANNEL, "Data was written onto Socket %d\n", fd);
				
				// Initialize the written message.
				DATA.src = TOS_NODE_ID;
				DATA.dest = tempSocket.socketState.dest.addr;
				DATA.protocol = PROTOCOL_TCP;
				DATA.TTL = MAX_TTL;
				memcpy(DATA.payload, &tempSocket, (uint8_t) sizeof(tempSocket));
				
				// Get the next hop associated with the destination.
				for(j = 0; j < Table->entries; j++)
				{
					if(Table->lspEntries[i].dest == DATA.dest)
						nextHop = Table->lspEntries[i].nextHop;
				}
				
				// Send out the written message.
				call Sender.send(DATA, nextHop);
				
				// Put the socket back in.
				call SocketList.pushback(tempSocket);
				
				// It was able to write down j amount of data onto the buffer.
				return j;
			}
		}
		
		// Could not write down anything on the buffer.
		return 0;
		
	} // End write.
	
	command error_t Transport.receive(pack* package)
	{
		// If the received packet is a TCP packet, it can be handled.
		if(package->protocol == PROTOCOL_TCP)
			return SUCCESS;
			
		// Otherwise it cannot be handled.	
		else
			return FAIL;
	} // End receive.
	
	command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
		// Temp Socket struct.
		socketStruct tempSocket;
		
		// Iterators.
		int i, j, k;
		
		// Buffer space for receiver.
		int spaceRemaining;
		
		// Go through the list, and find the appropriate Socket fd.
		for(i = 0; i < call SocketList.size(); i++)
		{
			tempSocket = call SocketList.get(i);
			
			if (fd == tempSocket.fd)
			{
				// Take out the appropriate Socket from the list.
				tempSocket = call SocketList.remove(i);
				

				// Now it can write to the buffer.
				// Must start at the end of the last written portion of the buffer.
				k = tempSocket.socketState.lastRead + 1;
				
				// Calculate how much space is left on the buffer.
				spaceRemaining = SOCKET_BUFFER_SIZE - k;
				
				for(j = 0; j < bufflen; j++)
				{
				
					tempSocket.socketState.sendBuff[k] = buff[j];
					k++;
					
					spaceRemaining--;
					
					// If there is no space left, must stop reading.
					if(spaceRemaining == 0)
						break;
				}
					
				tempSocket.socketState.lastRead = k;
					
				dbg(TRANSPORT_CHANNEL, "Data was read onto Socket %d", fd);
				
				// Put the socket back in.
				call SocketList.pushback(tempSocket);
				
				
				// It was able to write down j amount of data onto the buffer.
				return j;
			}
		}
		
		// Could not write down anything on the buffer.
		return 0;
	} // End read.
	
	command error_t Transport.connect(socket_t fd, socket_addr_t *addr, lspTable* Table)
	{
		// The SYN packet that must be sent out.
		pack SYN;
		
		// Iterators.
		int i, j;
		
		// Next hop variable.
		uint16_t nextHop;
		
		//Temp Socket struct.
		socketStruct tempSocket;
		
		dbg(TRANSPORT_CHANNEL, "Creating SYN packet intended for node %d, port %d.\n", addr->addr, addr->port);
		
		// Finish making the SYN packet.
		SYN.src = TOS_NODE_ID;
		SYN.dest = addr->addr;
		SYN.seq = 1;
		SYN.TTL = MAX_TTL;
		SYN.protocol = PROTOCOL_TCP;
		
		// Find the next hop for the destination node and send it there.
		for(i = 0; i < Table->entries; i++)
		{
			if(Table->lspEntries[i].dest == SYN.dest)
			{
				nextHop = Table->lspEntries[i].nextHop;
				
				// Modify the Socket State.
				for(j = 0; j < call SocketList.size(); j++)
				{
					tempSocket = call SocketList.get(j);
					
					if(fd == tempSocket.fd)
					{
						tempSocket = call SocketList.remove(j);
						
						tempSocket.socketState.state = SYN_SENT;
						tempSocket.socketState.flag = 1;
						
						tempSocket.socketState.dest = *addr;
						
						memcpy(SYN.payload, &tempSocket, (uint8_t) sizeof(tempSocket));
						
						call SocketList.pushback(tempSocket);
						
						dbg(TRANSPORT_CHANNEL, "SYN packet being sent to nextHop %d, intended for Node %d.\n",nextHop, addr->addr);
						
						//                                                                                                                
						
						// Send it to the next hop.
						call Sender.send(SYN, nextHop);
						
						break;
					}
				}
				
				return SUCCESS;
			}
		}
		
		return FAIL;
		
	} // End connect.
	
	command error_t Transport.close(socket_t fd)
	{
		// Temp Socket Structure.
		socketStruct tempSocket;
		
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
				
				// Close the Socket.
				tempSocket.socketState.state == CLOSED;
				
				// Put it back in.
				call SocketList.pushback(tempSocket);
				
				dbg(TRANSPORT_CHANNEL, "Socket %d is now closed.\n", fd);
				
				return SUCCESS;
			}
		}
		
		// If this point is reached, it was unable to close the socket.
		return FAIL;
	} // End close.
	
	command error_t Transport.release(socket_t fd)
	{
		// This functin will not be used.
		return FAIL;
	} // End release.
	
	command error_t Transport.listen(socket_t fd)
	{
  		socketStruct tempSocket;
		
		int i;
 
 		for(i = 0; i < call SocketList.size(); i++)
 		{
			tempSocket = call SocketList.get(i);
 			
			if(tempSocket.fd == fd)
 			{ 
					tempSocket = call SocketList.remove(i);
					
					tempSocket.socketState.state == LISTEN;
					
 					dbg(TRANSPORT_CHANNEL, "Socket %d set to listen.\n", fd);
 					
					call SocketList.pushback(tempSocket); 
					
					return SUCCESS;
 			}
 		}
		return FAIL;
	} // End listen.

} // End implementation.
