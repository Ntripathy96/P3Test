#include "../../includes/socket.h"

module TransportP
{
	provides interface Transport;
}

implementation
{
	socket_t socket;
	socket_addr_t socketStruct;
	
	command socket_t Transport.socket()
	{
	
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
