Team Memebers
1. Desikan Sundararajan - 5615-9991
2. Madhura Basavaraju - 6794-1287

Running the program - mix run proj3.exs numNodes numRequests

Implementation

Initialization:
Each node in the network is a genserver actor. The state comprises of three values -> its unique identifier(SHA-1 hash truncated to 8 digits), routing table, the map that calculates the
number of hops to each destination node. We determine the destination nodes randomly, one for each request.

Routing Table:
The routing table is populated as specified in the paper. Where each level is populated with the nodes that share upto (level-1) prefixes.
In case of conflict and there are multiple choices available from the list of nodes for a particular entry, the node that is closest among all possible nodes is chosen.
The closeness of a particular node is determined on the basis of the difference in their hex values.

Routing:
Given the destination node, a node first checks if its own identifier matches the destination's identifier. The function returns with the total number of hops as zero if is this is the case.
Else the node traverses its (hop+1)th level and chooses the ith entry (i being the digit at the (current_level)th position of the destination node's identifier) as a intermediate node.  
The routing function is called recursively with an increment in the hop number and the newly chosen intermediate node.
An exception to making an increment in the hop count is when the intermediate node chosen from a node's routing table turns out to be the node itself. In the case that the node moves onto the
next level to choose the intermediate node that follows keeping the hop count as the same.


Dynamic insertion of node:
Dynamic network join is implemented. The joining new node, fetches the closest node( based on hex values difference) from the network, called the root node.
This root node performs a recursive multicast operation, contacting all nodes in its own routing map that are greater than or equal to level n (where n is the number of prefix matches).
Each of the nodes in root node's map till the last level, become the list of initial "need to know neighbours". These need to know neighbours then contact all those node in their map in
levels >=(n+1) and so on. This way, we get the final list of need-to-know nodes.

For each of the need to know neighbours, the new node is entered into its own routing table, if the new node is closer to it than the current entry in its
routing table. The new node also updates its own routing table picking the nearest nodes from the need to know neighbours for each level.


The largest network being handled is 2000 nodes and 50 requests
