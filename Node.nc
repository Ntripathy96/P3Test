/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/lspTable.h"
#include "includes/socket.h"

// Neighbor structure for Neighbor Discovery.
typedef nx_struct neighbor 
{
	nx_uint16_t Node;
	nx_uint8_t Life;
}neighbor;

// Sequence number of this node.
int seqNum = 1;

module Node
{
	// Main interfaces.
	uses interface Boot;
	uses interface SplitControl as AMControl;
	uses interface Receive;
	uses interface SimpleSend as Sender;
	uses interface CommandHandler;

	// Timers.
	uses interface Timer<TMilli> as Timer1;
	uses interface Timer<TMilli> as lspTimer;
	uses interface Random as Random;

	// Data Structures.
	uses interface List<neighbor> as NeighborList;
	uses interface List<pack> as SeenPackList;
	uses interface List<pack> as SeenLspPackList;
	
	// Transport Interface.
	uses interface Transport;
}

implementation
{
	pack sendPackage;

	// Checks for printing.
	bool printNodeNeighbors = FALSE;
	bool netChange = FALSE;


	// Prototypes
	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

	// Project 1 functions: Neighbor Discovery.
	void printNeighbors();
	void printNeighborList();
	void neighborDiscovery();
	bool checkPacket(pack Packet);

	// Project 2 functions: Link State.
	void lspNeighborDiscoveryPacket();
	lspMap lspMAP[20];
	int lspSeqNum = 0;
	bool checkSeenLspPacks(pack Packet);
	lspTable confirmedList;
	lspTable tentativeList;
	float cost[20];
	int lastSequenceTracker[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	void printlspMap(lspMap *list);
	void dijkstra();
	int forwardPacketTo(lspTable* list, int dest);
	void printCostList(lspMap *list, uint8_t nodeID);
	float EMA(float prevEMA, float now,float weight);

	event void Boot.booted()
	{
		call AMControl.start();
		dbg(GENERAL_CHANNEL, "Booted\n");
	}

	event void Timer1.fired()
	{
		neighborDiscovery();
	}

	event void lspTimer.fired()
	{
			lspNeighborDiscoveryPacket(); 
	}


	event void AMControl.startDone(error_t err)
	{
		if(err == SUCCESS)
		{
			dbg(GENERAL_CHANNEL, "Radio On\n");
			call Timer1.startPeriodic(100000 + (uint16_t)((call Random.rand16())%200));
			call lspTimer.startPeriodic(100000 + (uint16_t)((call Random.rand16())%200));
		}
		else
		{
			//Retry until successful
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err){}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		//dbg(GENERAL_CHANNEL, "Packet Received\n");

		// Temporary Variable for use of the size of the list of Neighbors.
		uint16_t size = call NeighborList.size();

		if(len==sizeof(pack))
		{
			pack* myMsg=(pack*) payload;


			// If the message has a TTL of 0, do nothing with it.
			if(myMsg->TTL == 0) {}
			
			// Transport packet. If intended for this node, handle it.
			else if(myMsg->protocol == PROTOCOL_TCP && myMsg->dest == TOS_NODE_ID)
			{
				
			}

			// Flooding or Forwarding. Also catches Transport packets not intended for this node.
			else if (myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_TCP)
			{
				int forwardTo;

				// Messaged received succesfully, reply with an ACK.
				if (myMsg->dest == TOS_NODE_ID)
				{
					makePack(&sendPackage, myMsg->src, myMsg->dest, MAX_TTL,PROTOCOL_PING,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

					// Message already received, drop it.
					if(checkPacket(sendPackage)){}

					else // Else 1.
					{
						dbg(FLOODING_CHANNEL, "Packet has Arrived to destination! Sending ACK.");
						dijkstra();
						forwardTo = forwardPacketTo(&confirmedList,myMsg->src);
						makePack(&sendPackage, TOS_NODE_ID, myMsg->src, 20,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
						call Sender.send(sendPackage, forwardTo);

					} // End Else 1.
				} // End if (myMsg->dest == TOS_NODE_ID)

				// Message isn't meant for this node, therefore forward it.
				else // Else 2.
				{   
					int forwardTo;
					makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PING, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

					if(checkPacket(sendPackage)){}

					else // Else 3.
					{
						dijkstra();
						forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);

						if(forwardTo == 0) 
							printCostList(&lspMAP, TOS_NODE_ID);

						if(forwardTo == -1)
						{
							dbg(ROUTING_CHANNEL, "rechecking \n");
							dijkstra();
							forwardTo = forwardPacketTo(&confirmedList,myMsg->dest);

							if(forwardTo == -1){}

							else // Else 4.
							{
								dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
								call Sender.send(sendPackage, forwardTo);

							} // End Else 4.
						} // End if(forwardTo == -1)

						else // Else 5.
						{
							dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
							call Sender.send(sendPackage, forwardTo); 

						} // End Else 5.
					}// End Else 3.
				} // End Else 2.
			} // End else if (myMsg->protocol == PROTOCOL_PING)

			// Neighbor Discovery or Link State.
			else if (myMsg->dest == AM_BROADCAST_ADDR) 
			{
				if(myMsg->protocol == PROTOCOL_LINKSTATE)
				{
					int j, l;

					// If this packet hasn't been seen yet.
					if(!checkSeenLspPacks(sendPackage))
					{ 
						lspMapInit(&lspMAP, myMsg->src);

						if(myMsg->src == TOS_NODE_ID){}

						else // Else 6.
						{
							for(j = 0; j <20; j++)
							{
								lspMAP[myMsg->src].cost[j] = myMsg->payload[j];
								if(lspMAP[myMsg->src].cost[j] != 255 || lspMAP[myMsg->src].cost[j] != 0 ){}
							} // End j loop.

							for(l = 1; l < 20; l++)
							{
								for(j = 1; j <20; j++)
								{ 
									if(lspMAP[l].cost[j] != 255 && lspMAP[l].cost[j] != 0)
										dbg(ROUTING_CHANNEL, "%d Neighbor %d, cost: %d\n",  l,j,lspMAP[l].cost[j] );

								} // End j loop.
							 } // End l loop.

							makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol,myMsg->seq, (uint8_t*) myMsg->payload, 20);
							call Sender.send(sendPackage,AM_BROADCAST_ADDR);
						} // End Else 6.     
					} // End if(!checkSeenLspPacks(sendPackage)).		
				} //End if(myMsg->protocol == PROTOCOL_LINKSTATE).

				else if(myMsg->protocol == PROTOCOL_PINGREPLY)
				{
					neighbor Neighbor;
					neighbor neighbor_ptr;

					int k = 0;
					bool FOUND;
					FOUND = FALSE;
					size = call NeighborList.size();

					for(k = 0; k < call NeighborList.size(); k++) 
					{
						neighbor_ptr = call NeighborList.get(k);
						neighbor_ptr.Life++;
						if(neighbor_ptr.Node == myMsg->src)
						{
							FOUND = TRUE;
							neighbor_ptr.Life = 0;
						}
					} // End k loop.

					if(FOUND)
					{
						dbg(NEIGHBOR_CHANNEL,"Neighbor %d found in list\n", myMsg->src);
						netChange = FALSE;
					}
					else // Else 7.
					{
						Neighbor.Node = myMsg->src;
						Neighbor.Life = 0;
						call NeighborList.pushfront(Neighbor); //at index 0
						netChange = TRUE; //network change!
					} // End Else 7.

					for(k = 0; k < call NeighborList.size(); k++) 
					{
						neighbor_ptr = call NeighborList.get(k);

						if(neighbor_ptr.Life > 5) 
						{
							call NeighborList.remove(k);
							dbg(NEIGHBOR_CHANNEL, "Node %d life has expired dropping from NODE %d list\n", neighbor_ptr.Node, TOS_NODE_ID);
							dbg(ROUTING_CHANNEL, "CHANGE IN TOPOLOGY\n");
							netChange = TRUE;
						}
					} // End k loop.
				} // End else if(myMsg->protocol == PROTOCOL_PINGREPLY).

				else
					dbg(ROUTING_CHANNEL, "ERROR\n");   


			} // End else if (myMsg->dest == AM_BROADCAST_ADDR).

			else if(myMsg->protocol == PROTOCOL_PINGREPLY)
			{
				int forwardTo;

				if(myMsg->dest == TOS_NODE_ID)
				{ //ACK reached source
					makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
					if(!checkPacket(sendPackage))
						dbg(FLOODING_CHANNEL,"Node %d recieved ACK from %d\n", TOS_NODE_ID,myMsg->src);        
				}
				else // Else 8.
				{
					dbg(FLOODING_CHANNEL, "Sending Ping Reply to %d! \n\n", myMsg->src);
					dijkstra();
					forwardTo = forwardPacketTo(&confirmedList,myMsg->src);
					dbg(ROUTING_CHANNEL,"Forwarding to %d and src is %d \n", forwardTo, TOS_NODE_ID);
					makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL - 1,PROTOCOL_PINGREPLY,myMsg->seq,myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
					call Sender.send(sendPackage, forwardTo);
				} // End Else 8.

			} // End else if(myMsg->protocol == PROTOCOL_PINGREPLY).

			return msg;

		} // End if(len==sizeof(pack)).

		dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
		return msg;

	} // End event.


	event void CommandHandler.ping(uint16_t destination, uint8_t *payload)
	{
		int forwardTo;
		
		dbg(GENERAL_CHANNEL, "PING EVENT \n");
		makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_PING, seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
		
		dijkstra();
		forwardTo = forwardPacketTo(&confirmedList,destination);
		
		call Sender.send(sendPackage, forwardTo);
		seqNum++;
	}

	event void CommandHandler.printNeighbors()
	{
		printNeighborList();
	}

	event void CommandHandler.printRouteTable(){}

	event void CommandHandler.printLinkState(){}

	event void CommandHandler.printDistanceVector(){}

	event void CommandHandler.setTestServer(uint16_t port)
	{
		socket_addr_t address;
		socket_t fd = call Transport.socket();
		address.addr = TOS_NODE_ID;
		address.port = port;
		if(call Transport.bind(fd, &address) == SUCCESS && call Transport.listen(fd) == SUCCESS)
			dbg(TRANSPORT_CHANNEL, "Now Listen.\n");
	}
        
	event void CommandHandler.setTestClient(uint16_t destination, uint16_t DP, uint16_t SRCP)
	{
		pack SYN; 
		socketStruct tempSocket;
		socket_addr_t address; 
		socket_addr_t serverAdd; 
		socket_t fd = call Transport.socket(); 
		address.addr = TOS_NODE_ID;
		address.port = SRCP;
		serverAdd.addr = destination;
		serverAdd.port = DP;

		if (call Transport.bind(fd, &address) == SUCCESS)
			call Transport.connect(fd, &serverAdd, &confirmedList);
	}
	
	event void CommandHandler.setAppServer(){}

	event void CommandHandler.setAppClient(){}

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
	}

	bool checkPacket(pack Packet)
	{
		pack PacketMatch;
		if(call SeenPackList.isEmpty())
		{
			call SeenPackList.pushfront(Packet);
			return FALSE;
		}
		else
		{
			int i;
			int size = call SeenPackList.size();
			for(i = 0; i < size; i++)
			{
				PacketMatch = call SeenPackList.get(i);
				if( (PacketMatch.src == Packet.src) && (PacketMatch.dest == Packet.dest) && (PacketMatch.seq == Packet.seq) && (PacketMatch.protocol== Packet.protocol))
						return TRUE;
			}

		}
		call SeenPackList.pushfront(Packet);
		return FALSE;
	}

	void neighborDiscovery()
	{
		char* dummyMsg = "Hello\n";

		makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PINGREPLY, -1, dummyMsg, PACKET_MAX_PAYLOAD_SIZE);
		call Sender.send(sendPackage, AM_BROADCAST_ADDR);

		if (printNodeNeighbors)
		{
			printNodeNeighbors = FALSE;
			printNeighborList();
		}
		else
			printNodeNeighbors = TRUE;
	}

	void printNeighborList()
	{
		int i;
		neighbor neighPtr;
		if(call NeighborList.size() == 0 )
			dbg(NEIGHBOR_CHANNEL,"No neighbors for node %d\n", TOS_NODE_ID);
			
		else
		{
			dbg(NEIGHBOR_CHANNEL,"Neighbors for node %d\n",TOS_NODE_ID);
			for(i = 0; i < call NeighborList.size(); i++)
			{
				neighPtr = call NeighborList.get(i);
				dbg(NEIGHBOR_CHANNEL,"NeighborNode: %d\n", neighPtr.Node);
			}
		}

	}


	void lspNeighborDiscoveryPacket()
	{
		int i;
		uint8_t lspCostList[20] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
		lspMapInit(&lspMAP, TOS_NODE_ID);
		for(i  =0; i < call NeighborList.size(); i++)
		{
			neighbor Neighbor = call NeighborList.get(i);
			lspCostList[Neighbor.Node] = 1;
			lspMAP[TOS_NODE_ID].cost[Neighbor.Node] = 1;
		}
		
	   	if(!call NeighborList.isEmpty())
		{
			lspSeqNum++;
		   	dbg(ROUTING_CHANNEL, "Sending LSP: SeqNum: %d\n", lspSeqNum);
			makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR,20, PROTOCOL_LINKSTATE, lspSeqNum, (uint8_t *) lspCostList, 20);
			call Sender.send(sendPackage,AM_BROADCAST_ADDR);
	   	}
	}


	bool checkSeenLspPacks(pack Packet)
	{
		pack PacketMatch;
		if(call SeenLspPackList.isEmpty())
		{
			call SeenLspPackList.pushfront(Packet);
			return FALSE;
		}
		else
		{
			int i;
			int size = call SeenLspPackList.size();
			for(i = 0; i < size; i++)
			{
				PacketMatch = call SeenLspPackList.get(i);//check for lsp from a certain node
				if( (PacketMatch.src == Packet.src) && (PacketMatch.protocol == Packet.protocol))
				{ 
					if(PacketMatch.seq == Packet.seq) 
						return TRUE;
					if(PacketMatch.seq < Packet.seq)
					{   
						call SeenLspPackList.remove(i);
						call SeenLspPackList.pushback(Packet);
						return FALSE;
					}
					return TRUE; //packet is found in list and has already been seen by node.
				}
			}
		}
		call SeenLspPackList.pushfront(Packet);
		return FALSE;
	}

	void dijkstra()
	{
		int i;	
		lspTuple lspTup, temp;
		
		initializeTable(&tentativeList); 
		initializeTable(&confirmedList);

		lspTablePushBack(&tentativeList, temp = (lspTuple){TOS_NODE_ID,0,TOS_NODE_ID});
		
		while(!lspTableIsEmpty(&tentativeList))
		{
			if(!lspTableContains(&confirmedList,lspTup = lspTupleRemoveMinCost(&tentativeList))) //gets the minCost node from the tentative and removes it, then checks if it's in the confirmed list.
				if(lspTablePushBack(&confirmedList,lspTup))
					dbg(ROUTING_CHANNEL,"PushBack from confirmedList dest:%d cost:%d nextHop:%d \n", lspTup.dest,lspTup.nodeNcost, lspTup.nextHop);
			
			for(i = 1; i < 20; i++)
			{
				temp = (lspTuple){i,lspMAP[lspTup.dest].cost[i]+lspTup.nodeNcost,(lspTup.nextHop == TOS_NODE_ID)?i:lspTup.nextHop};
				if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTupleReplace(&tentativeList,temp,temp.nodeNcost))
						dbg(ROUTING_CHANNEL,"Replace from tentativeList dest:%d cost:%d nextHop:%d\n", temp.dest, temp.nodeNcost, temp.nextHop);
				else if(!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTablePushBack(&tentativeList, temp))
						dbg(ROUTING_CHANNEL,"PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
			}
		}
		
		dbg(ROUTING_CHANNEL, "Printing the ROUTING_CHANNEL table! \n");
		for(i = 0; i < confirmedList.entries; i++)
			dbg(ROUTING_CHANNEL, "dest:%d cost:%d nextHop:%d \n",confirmedList.lspTuples[i].dest,confirmedList.lspTuples[i].nodeNcost,confirmedList.lspTuples[i].nextHop);
	}

	int forwardPacketTo(lspTable* list, int dest)
	{	
		return lspTableLookUp(list,dest);
	}


	/**
	 * let S_1 = Y_1
	 * Exponential Moving Average
	 * S_t = alpha*Y_t + (1-alpha)*S_(t-1)
	 */	
	float EMA(float prevEMA, float now,float weight)
	{
		float alpha = 0.5*weight;
		float averageEMA = alpha*now + (1-alpha)*prevEMA;
		return averageEMA;
	}


	void printlspMap(lspMap *list){
		int i,j;
		for(i = 0; i < 20; i++){
			for(j = 0; j < 20; j++){
				if(list[i].cost[j] != 0 && list[i].cost[j] != 255)
					dbg(ROUTING_CHANNEL, "src: %d  neighbor: %d cost: %d \n", i, j, list[i].cost[j]);
			}	
		}
		dbg(ROUTING_CHANNEL, "END \n\n");
	}

	void printCostList(lspMap *list, uint8_t nodeID) {
		uint8_t i;
		for(i = 0; i < 20; i++) {
			dbg(ROUTING_CHANNEL, "From %d To %d Costs %d", nodeID, i, list[nodeID].cost[i]);
		}
	}

}
