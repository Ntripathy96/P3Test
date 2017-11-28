#ifndef LSP_TABLE_H
#define LSP_TABLE_H

#define maxEntries 20

// lspEntry defines an entry in an LSP Table.
// Contains a destination node's associated cost and next hop.
typedef struct lspEntry
{
	// The destination node of this entry.
	uint8_t dest;
	
	// The cost to get to said destination.
	uint8_t cost;
	
	// The next hop for said destination.
	uint8_t nextHop;
	
}lspEntry;

// An LSP table, full of lspEntries
// Also contains a "pointer" storing the number of entries currently in the struct.
typedef struct lspTable
{
	// The actual Table of lspEntries.
	lspEntry lspEntries[maxEntries];
	
	// A "pointer" as well as a counter. Marks the last index in the table, and how many entries are in it.
	uint8_t entries;
	
}lspTable;

// Takes in a Table, and intializes all values to a sentinel value. Also sets the entries "pointer" to zero.
void initializeTable(lspTable* Table)
{
	// Iterator.
	int i;
	
	// Set the number of values in the table to zero.
	Table->entries = 0;
	
	// Set the cost to all possible nodes to a sentinel value.
	for(i = 0; i < maxEntries; i++)
		Table->lspEntries[i].cost = -1;
}

// Checks whether or not the table is empty.
bool tableIsEmpty(lspTable* Table)
{
	// If the entries "pointer" is non-zero, then there are entries in the table.
	// Therefore, the table is not empty.
	if(Table->entries > 0)
		return FALSE;
	
	// If it is zero, then there are no entries and the table is empty.
	else
		return TRUE;
}

// Adds new entry into the LSP Table, much like a vector from the C++ STL.
bool tablePushback(lspTable* Table, lspEntry newEntry)
{	
	// If there are "maxEntries" or more entries in the Table, a new entry cannot be added.
	if(Table->entries >= maxEntries)
		return FALSE;
	
	else
	{
		// Place the entry at the tail of the Table by using the entries "pointer".
		Table->lspEntries[Table->entries] = newEntry;
		
		// Move the entries "pointer".
		Table->entries++;
		return TRUE;
	}
}

// Look for a specific destination tuple, and replace the cost and hop with the new lower one.
bool replaceEntry(lspTable* Table, lspEntry newEntry, int cost)
{
	// Iterator.
	int i;
	
	// Find the specific entry, and overwrite it.
	for(i = 0; i < Table->entries; i++)
	{
		// Look for the matching destinations.
		if(newEntry.dest == Table->lspEntries[i].dest)
		{
			// If the cost is lower than the current one, use the new entry.
			if (cost < Table->lspEntries[i].cost)
			{
				Table->lspEntries[i] = newEntry;
				return TRUE;
			}
			
			// Otherwise, keep the old one and return false.
			else
				return FALSE;
		}
	}
	
	// If this point is reached, the entry is not currently in the table.
	return FALSE;
}

// Checks to see if a certain entry is in the Table.
bool tableContains(lspTable* Table, lspEntry Entry)
{
	// Iterator.
	int i;
	
	// Move through the table.
	for(i = 0; i < Table->entries; i++)
	{
		// If the destination node of the new Entry matches one of the Entries in the table,
		// Then the destination node is already in the table.
		if(Entry.dest == Table->lspEntries[i].dest)
			return TRUE;
	}
	
	// Otherwise, this is a new destination node.
	return FALSE;
}

// Given a destination, return its associated nextHop.
int getNextHop(lspTable* Table, int dest)
{
	// Iterator.
	int i;
	
	// Search through the Table and find the respective destination node.
	for(i = 0; i < Table->entries; i++)
	{
		if(dest == Table->lspEntries[i].dest)
		{
			// Return the next Hop for this destination node.
			return Table->lspEntries[i].nextHop;
		}
	}
	
	// If this point is reached, the destination node was not found in the table. 
	// Return a sentinel value.
	return -1;
}

// ***************** REMOVE THIS *********************
/*
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
}*/

// Gets the entry with the lowest cost from the table, removes it, and then returns it.
lspEntry getMinCost(lspTable* Table)
{
	// Iterator.
	int i;
	
	// Index of the min cost node.
	int minNode;
	
	// Temporary lspEntry.
	lspEntry temp;
	//lspEntry temp2;
	
	// Set the temporary entry's cost to a sentinel value.
	temp.cost = 1000;
	
	// Find the node with the min cost.
	for(i = 0; i < Table->entries; i++)
	{
		if(temp.cost > Table->lspEntries[i].cost)
		{
			temp = Table->lspEntries[i];
			minNode = i;
		}
	}
	
	if(Table->entries > 1)
	{
		temp = Table->lspEntries[minNode];
		Table->lspEntries[minNode] = Table->lspEntries[Table->entries - 1];		
		Table->entries--;
		return temp;
	}
	else
	{
		Table->entries = 0;
		return Table->lspEntries[0];
	}
	
	//temp2 = lspTableRemove(Table, minNode);
	//return temp;
}

#endif /* LSP_TABLE_H */
