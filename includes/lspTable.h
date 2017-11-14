#ifndef LSP_TABLE_H
#define LSP_TABLE_H

#define MAXNODES 20
#define MAXNODEVAL MAXNODES

// lspTuple defines an entry in an LSP Table.
// Contains a destination node's associated cost and next hop.
typedef struct lspTuple
{
	uint8_t dest;
	uint8_t nodeNcost;
	uint8_t nextHop;	
}lspTuple;

// An LSP table, full of lspTuples.
// Also contains a variable storing the number of entries currently in the struct.
typedef struct lspTable
{
	lspTuple lspTuples[MAXNODES];
	uint8_t numValues;
}lspTable;


bool lspTupleReplace(lspTable* list, lspTuple newTuple, int cost)
{
	int i;
	for(i = 0; i<list->numValues; i++)
	{
		if(cost < list->lspTuples[i].nodeNcost && newTuple.dest == list->lspTuples[i].dest)
		{
			list->lspTuples[i].dest = newTuple.dest;
			list->lspTuples[i].nodeNcost = cost;
			list->lspTuples[i].nextHop = newTuple.nextHop;
			return TRUE;
		}
	}
	return FALSE;
}

bool lspTablePushBack(lspTable* cur, lspTuple newVal)
{	
	if(cur->numValues != MAXNODEVAL)
	{
		cur->lspTuples[cur->numValues] = newVal;
		cur->numValues++;
		return TRUE;
	}
	else 
		return FALSE;
}

bool lspTableIsEmpty(lspTable* cur)
{
	if(cur->numValues == 0)
		return TRUE;
	else
		return FALSE;
}

bool lspTableContains(lspTable* list, lspTuple newVal)
{
	uint8_t i;
	for(i = 0; i<list->numValues; i++)
	{
		if(newVal.dest == list->lspTuples[i].dest) return TRUE;
	}
	return FALSE;
}

bool lspTableContainsDest(lspTable* list, int node)
{
	uint8_t i;
	for(i = 0; i<list->numValues; i++)
	{
		if(node == list->lspTuples[i].dest)
			 return TRUE;
	}
	return FALSE;
}

lspTuple lspTupleRemoveMinCost(lspTable* cur)
{
	int i;
	int minNode;
	lspTuple temp;
	lspTuple temp2;
	temp.nodeNcost = 255;
	for(i = 0; i < cur->numValues; i++)
	{
		if(cur->lspTuples[i].nodeNcost < temp.nodeNcost)
		{
			temp = cur->lspTuples[i];
			minNode = i;
		}
	}
	temp2 = lspTableRemove(cur, minNode);
	return temp2;
}

int lspTableLookUp(lspTable* list, int dest)
{
	int i;
	for(i = 0; i < list->numValues; i++)
	{
		if(list->lspTuples[i].dest == dest)
			return list->lspTuples[i].nextHop;
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
	for(i = 0; i < MAXNODES; i++)
	{
		list[TOS_NODE_ID].cost[i] = -1;	
	}	
}

#endif /* LSP_TABLE_H */
