#ifndef LSP_TABLE_H
#define LSP_TABLE_H

#define maxEntries 20

// lspEntry defines an entry in an LSP Table.
// Contains a destination node's associated cost and next hop.
typedef struct lspEntry
{
	uint8_t dest;
	uint8_t cost;
	uint8_t nextHop;	
}lspEntry;

// An LSP table, full of lspEntries
// Also contains a variable storing the number of entries currently in the struct.
typedef struct lspTable
{
	lspEntry lspEntries[maxEntries];
	uint8_t entries;
}lspTable;

void initializeTable(lspTable* table)
{
	// Iterator.
	int i;
	
	// Set the cost to all possible nodes to a sentinel value.
	for(i = 0; i < maxEntries; i++)
		table->lspEntries[i].cost = -1;
	
	// Set the number of values in the table to zero.
	table->entries = 0;
}

// Look for a specific destination tuple, and replace the cost and hop with the new lower one.
bool lspEntryReplace(lspTable* list, lspEntry newEntry, int cost)
{
	// Iterator.
	int i;
	
	// Find the specific tuple, and overwrite it.
	for(i = 0; i < list->entries; i++)
	{
		// Look for the matching destinations.
		if(newEntry.dest == list->lspEntries[i].dest)
		{
			// If the cost is lower than the current one, use the new tuple.
			if (cost < list->lspEntries[i].cost)
			{
				list->lspEntries[i].cost = cost;
				list->lspEntries[i].nextHop = newEntry.nextHop;
				return TRUE;
			}
			
			// Otherwise, keep the old one and return false.
			else
				return FALSE;
		}
	}
	
	// If this point is reached, the tuple is not currently in the table.
	return FALSE;
}

// Adds new entry into the LSP Table, much like a vector from the C++ STL.
bool lspTablePushBack(lspTable* cur, lspEntry newVal)
{	
	if(cur->entries < 20)
	{
		cur->lspEntries[cur->entries] = newVal;
		cur->entries++;
		return TRUE;
	}
	else 
		return FALSE;
}

// Checks whether or not the table is empty.
bool lspTableIsEmpty(lspTable* cur)
{
	if(cur->entries == 0)
		return TRUE;
	else
		return FALSE;
}

// Checks to see if a certain tuple is in the Table.
bool lspTableContains(lspTable* list, lspEntry newVal)
{
	uint8_t i;
	for(i = 0; i<list->entries; i++)
	{
		if(newVal.dest == list->lspEntries[i].dest) return TRUE;
	}
	return FALSE;
}

// Checks if a Destination node is in the table.
bool lspTableContainsDest(lspTable* list, int node)
{
	uint8_t i;
	for(i = 0; i<list->entries; i++)
	{
		if(node == list->lspEntries[i].dest)
			 return TRUE;
	}
	return FALSE;
}

// ***************** REMOVE THIS *********************
lspEntry lspTableRemove(lspTable* list, int node){
	uint8_t i;
	lspEntry temp;
	for(i = 0; i<=list->entries; i++){
		if(i == node){
			if(list->entries > 1){
				temp = list->lspEntries[i];
				list->lspEntries[i] = list->lspEntries[list->entries-1];		
				list->entries--;
				i--;
				return temp;
			}
			else{
				list->entries = 0;
				return list->lspEntries[0];
			}
		}
	}	
}

// Remobe the tuple with the lowest cost, and return it.
lspEntry lspEntryRemoveMinCost(lspTable* cur)
{
	int i;
	int minNode;
	lspEntry temp;
	lspEntry temp2;
	temp.cost = 255;
	for(i = 0; i < cur->entries; i++)
	{
		if(cur->lspEntries[i].cost < temp.cost)
		{
			temp = cur->lspEntries[i];
			minNode = i;
		}
	}
	temp2 = lspTableRemove(cur, minNode);
	return temp2;
}

// Given a destination, return its associated nextHop.
int lspTableLookUp(lspTable* list, int dest)
{
	int i;
	for(i = 0; i < list->entries; i++)
	{
		if(list->lspEntries[i].dest == dest)
			return list->lspEntries[i].nextHop;
	}
	return -1;
}

//Creates a Map of all the Nodes
typedef struct lspMap
{
	uint8_t cost[20];
}lspMap;

void lspMapInit(lspMap *list, int TOS_NODE_ID)
{
	int i;	
	for(i = 0; i < maxEntries; i++)
	{
		list[TOS_NODE_ID].cost[i] = -1;	
	}	
}

#endif /* LSP_TABLE_H */
