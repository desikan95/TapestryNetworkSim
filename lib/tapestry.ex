defmodule TapestrySupervisor do
  use Supervisor

  def start_link(numNodes) do
    {:ok, pid} = Supervisor.start_link(__MODULE__,numNodes,name: __MODULE__)
    IO.puts "The supervisor ID is "
    IO.inspect pid
    nodes = initializeChildNodes(pid)
    {:ok,newnode} = Supervisor.start_child(pid,Supervisor.child_spec(Tapestry,id: 200))
    samenewnode = Tapestry.networkJoin(nodes,numNodes,newnode)

    findMaxHops([samenewnode|nodes],5,pid)
  end

  def init(numNodes) do

    children = Enum.map(1..(numNodes-1),fn (x) -> Supervisor.child_spec(Tapestry,id: x) end)

    IO.puts "Children are"
    IO.inspect children

    Supervisor.init(children, strategy: :one_for_one)
  end

  def initializeChildNodes(pid) do
    result = Supervisor.which_children(pid)
    IO.inspect result

    nodes = Enum.map(result, fn (x) ->
                                {id,pid,_,_} = x
                                Tapestry.mapPIDNodeId(pid,id)
                                pid end)
    IO.inspect nodes

    list = Enum.reduce(nodes, [], fn x, acc-> {id,_list} = GenServer.call(x,{:print})
                                            acc ++ [id]
                                            end )

    IO.puts "The list is"
    IO.inspect list
  #  initializeNeighbourMap(nodes)

    IO.puts "Need to initialize neighbour map for all nodes as follows : "
    IO.inspect nodes
    Enum.each(nodes, fn (node) -> Tapestry.initializeNeighbours(node,nodes)   end)
    nodes
  end

  def initializeNeighbourMap(nodes) do


#    newnode = Tapestry.networkJoin(nodes,numNodes)
#    newnode2 = Tapestry.networkJoin([newnode|nodes],numNodes+1)
#    Tapestry.makeRequests([newnode|nodes],9)
  end

  def findMaxHops(nodes,requests,pid) do

    result = Supervisor.which_children(pid)

    allchildren = Enum.map(result, fn (x) ->
                                {_,pid,_,_} = x

                                pid end)

    Enum.each(allchildren,fn (node) ->
      {id,neighbours} = GenServer.call(node,{:print})
      IO.puts "\n\nNode #{id}"
      IO.puts "Neighbours"
      IO.inspect neighbours
    end)
    #Tapestry.makeRequests(allchildren,9)

    hop = Enum.map(allchildren, fn (node) ->
            maxhop = Tapestry.makeRequests(allchildren,node,requests)
            maxhop
          end)
          |> Enum.max

    IO.puts " Max of max hops is #{hop}"
  end


end


defmodule Tapestry do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__,[])
  end

  def init(_val)do
    state = {"",%{}}
    {:ok,state}
   end

  def buildNode(_x) do
    {:ok,pid} = GenServer.start_link(__MODULE__,[])
    pid
  end



  @spec mapPIDNodeId(atom | pid | {atom, any} | {:via, atom, any}, any) :: any
  def mapPIDNodeId(pid , id) do
    GenServer.call(pid,{:mapToId,id})
  end



   def createPeers(numNodes) do
    nodes= Enum.map(1..numNodes, fn (x) ->
                                pid = buildNode(x)
                                mapPIDNodeId(pid,x)
                                pid end)
    nodes
   end

   def initializeNeighbours(node,nodes) do

      sourceNode = GenServer.call(node,{:getHash})
      IO.puts "\n\nNode is : "
      IO.inspect sourceNode

      nodeHashes = Enum.map(nodes, fn x -> GenServer.call(x,{:getHash}) end)
      IO.puts "Node hashes are "
      IO.inspect nodeHashes

      routingTable = nodeRoutingTable(sourceNode,nodeHashes)

      IO.puts "Neighbour map for source node is "
      IO.inspect routingTable
      GenServer.cast(node,{:saveRoutingTable,routingTable})

      IO.puts "Saved"
      #networkJoin(nodes)
   end

   def networkJoin(nodes,nodenumber,pid) do
  #   {:ok,pid} = GenServer.start_link(__MODULE__,[])
     IO.puts "New node initialized "
     IO.inspect pid

     mapPIDNodeId(pid,nodenumber)

     hash = GenServer.call(pid,{:getHash})
     IO.inspect hash
     root = Enum.random(nodes)
     IO.puts "The root node for the new node is"
     roothash = GenServer.call(root,{:getHash})
     IO.inspect roothash


     p = findLevel(hash,roothash,0)
     IO.puts "Need to check from levels #{p} "

     needtoknowInitial = GenServer.call(root,{:getNodesAtLevels,p})
     hashnodemap = Enum.reduce(nodes, %{}, fn (node,map) -> hashval = GenServer.call(node,{:getHash})
                                                            Map.put(map,hashval,node)
                                                            end)

     needtoknow = Enum.reduce(p..4, needtoknowInitial, fn (p,acc) ->
                                                                      result = Enum.map(acc, fn hash ->  node = Map.get(hashnodemap, hash)
                                                                                                         cond do
                                                                                                            (node==:nil) -> []
                                                                                                            true -> GenServer.call(node,{:getNodesAtLevels,p})
                                                                                                         end
                                                                               end)
                                                                                |> List.flatten
                                                                                |> Enum.reject( &is_nil/1)
                                                                                |> Enum.uniq
                                                                      acc ++ result
                                                    end )
                      |> Enum.uniq

     IO.puts "\nList of possible neighbour nodes (all need to know) are : "
     IO.inspect needtoknow

     Enum.each(needtoknow, fn (node) ->
       newnodehash = GenServer.call(pid, {:getHash})
       GenServer.cast( Map.get(hashnodemap,node), {:addNewNode,newnodehash})
     end)

     routingTable = nodeRoutingTable(hash,[hash|needtoknow])

     IO.puts "Neighbour map for the new node is "
     IO.inspect routingTable
     GenServer.cast(pid,{:saveRoutingTable,routingTable})
     pid
   end

   def findLevel(str1,str2,i) do
     cond do
        (i == String.length(str1) ) -> i+1
        (String.at(str1,i)!= String.at(str2,i)) -> i+1
        (String.at(str1,i) == String.at(str2,i)) -> findLevel(str1,str2,i+1)
        true -> i+1
     end
   end


   def nodeRoutingTable(nodeId,nodes) do

    globalList = nodes
    routingMap = Enum.reduce(1..4,%{}, fn level, acc -> cond do
                                                  level == 1 ->
                                                       levelNodes = Enum.reduce(0..15,[], fn entryNo,acc -> list = Enum.reduce(globalList, [], fn node,acc  ->
                                                                                                                                         cond do
                                                                                                                                          String.at(node,0) == Integer.to_string(entryNo,16) ->
                                                                                                                                          #IO.puts("Condition true")
                                                                                                                                          acc ++ [node]
                                                                                                                                           true -> acc
                                                                                                                                            end
                                                                                                                                          end)
                                                                                                            #IO.inspect(list)
                                                                                                            id = String.to_integer(nodeId,16)
                                                                                                            aptLink = cond do
                                                                                                                Enum.empty?(list) -> []
                                                                                                                true -> Enum.min_by(list,fn potentialLink -> abs (id - String.to_integer(potentialLink,16))end)
                                                                                                                   end
                                                                                                            #IO.inspect aptLink
                                                                                                             acc ++ [aptLink]
                                                                                            end)
                                                      Map.put(acc,level,levelNodes)
                                                    true ->
                                                                     levelNodes = Enum.reduce(0..15,[], fn entryNo,acc -> list = Enum.reduce(globalList, [], fn node,acc  ->
                                                                                                                                                                        cond do
                                                                                                                                                                          String.at(node,level-1) == Integer.to_string(entryNo,16) and String.slice(node,0..level-2) == String.slice(nodeId,0..level-2) ->
                                                                                                                                                                          #IO.puts("Condition true")
                                                                                                                                                                          acc ++ [node]
                                                                                                                                                                           true -> acc
                                                                                                                                                                        end
                                                                                                                                                            end)
                                                                                                                          #IO.inspect(list)
                                                                                                                          id = String.to_integer(nodeId,16)
                                                                                                                          aptLink = cond do
                                                                                                                          Enum.empty?(list) -> []
                                                                                                                          true -> Enum.min_by(list,fn potentialLink -> abs (id - String.to_integer(potentialLink,16))end)
                                                                                                                          end
                                                                                                                          #IO.inspect aptLink
                                                                                                                         acc ++ [aptLink]
                                                                                                          end)
                                                                          Map.put(acc,level,levelNodes)


                                                end
                                              end)
                                              routingMap
   end

   def listOfIds(peers) do
    nodeids = Enum.reduce(peers, [], fn x, acc-> acc ++ [GenServer.call(x,{:fecthNodeId})]end)
    nodeids
   end

   def updateNodeState(peers) do
    listOfNodeIds = listOfIds(peers)
    Enum.map(peers,fn(peer) ->  GenServer.call(peer,{:updateStateWithRoutingTable,listOfNodeIds}) end)
   end

   def makeRequests(nodes,node,numRequests) do

  #  IO.puts("Number of nodes #{nodes}")
  #  peers = createPeers(numNodes)
    #IO.puts("List of NodeIds : >>>>>")
    listOfNodeIds = listOfIds(nodes)
    source = GenServer.call(node,{:fecthNodeId})
#   IO.inspect(listOfNodeIds)
    updateNodeState(nodes)

    hops = Enum.map(1..numRequests,fn(peer)-> destinationNode = Enum.random(listOfNodeIds)
                          #    source = GenServer.call(peer,{:fecthNodeId})
                              IO.puts("Source Node: #{source}            Destination Node: #{destinationNode}")
                              noOfhops = routing(source,destinationNode,1,0,nodes)
                              IO.puts("Number of hops: #{noOfhops}")
                              IO.puts("..........................................................................................")
                              noOfhops
                              end )
           |> Enum.max
     IO.puts "Max Number of hops for #{source} are #{hops}"

     hops
   end

   def handle_call({:mapToId,id},_from,state) do
    {_id,map}=state
    stringId = Integer.to_string(id)
     nodeid =  String.slice(:crypto.hash(:sha, stringId) |> Base.encode16, 0..3)
    state={nodeid,map}
    {:reply,nodeid,state}
   end

   def handle_call({:getNodesAtLevels,level},_from,state) do
    {_id,routingMap}=state
    result = level..4
             |> Enum.map(fn x -> Map.get(routingMap,x) end)
             |> List.flatten
             |> Enum.reject(fn x -> x==[] end)
             |> Enum.uniq
    {:reply,result,state}
   end

   def handle_call({:print},_from,state) do
    {:reply,state,state}
   end

   def handle_call({:getHash},_from,state) do
     {id, _} = state
     {:reply,id,state}
   end

   def handle_call({:updateStateWithRoutingTable,globalList},_from,state) do
    {id,_map}=state
    routingmap = nodeRoutingTable(id,globalList)
    state={id,routingmap}
    {:reply,routingmap,state}
   end

   def handle_call({:fecthNodeId},_from,state)do
    {id,_map}=state
    {:reply,id,state}
   end

  def handle_cast({:saveRoutingTable,routingTable},state) do
    {id,_}=state
    {:noreply,{id,routingTable}}
  end

   def handle_call({:fetchNodeRoutingMap},_from,state)do
    {_id,map} = state
    {:reply,map,state}
   end

   def routing(currentNode,destinationNode,currentLevel,hopNo,peers) do
    #IO.puts("Node : #{currentNode}")
    cond do
      currentNode ==  destinationNode ->
      hopNo
      true ->
          [pid]= Enum.reject(peers, fn(peer)->

                                            id = GenServer.call(peer,{:fecthNodeId})
                                            currentNode != id end)

          routingMap = GenServer.call(pid,{:fetchNodeRoutingMap})
          IO.puts("Routing Map of Node >>>>>")
          IO.inspect(routingMap)
        entryNo = String.at(destinationNode,currentLevel-1)
        entry= String.to_integer(entryNo,16)
        IO.puts(entry)
        {:ok,levelnodes} = Map.fetch(routingMap, currentLevel)
        nextNode = Enum.at(levelnodes,entry)
        IO.puts("Fetching node #{nextNode} from Level #{currentLevel}")
        cond do
          is_list(nextNode) and Enum.empty?(nextNode) -> IO.puts("No such fucking node !")
          nextNode == currentNode -> routing(nextNode,destinationNode,currentLevel+1,hopNo,peers)
          true -> routing(nextNode,destinationNode,currentLevel+1,hopNo+1,peers)
        end
    end
  end

   def handle_cast({:addNewNode,newnodehash},state) do
  #  newnodehash = GenServer.call(pid, {:getHash})
    {hash,neighbourMap} = state
    level = findLevel(hash,newnodehash,0)
    list = Map.get(neighbourMap,level)

    {index,_} = String.at(newnodehash,level-1)
                |> Integer.parse(16)


    curr_val_node = Enum.at(list,index)
    neighbourMap = cond do
                             (curr_val_node == []) ->   newlist = insertAt(list,index,newnodehash)
                                                        Map.replace!(neighbourMap,level,newlist)

                             true ->    {curr_val,_} = Enum.at(list, index) |> Integer.parse(16)
                                        {new_val,_} = Integer.parse(newnodehash,16)
                                        {ownhash_val,_} = Integer.parse(hash,16)

                                        if (abs(new_val-ownhash_val) < abs(curr_val-ownhash_val)) do
                                                      newlist = insertAt(list,index,newnodehash)
                                                      Map.replace!(neighbourMap,level,newlist)

                                        end
                end
    IO.puts "Updated neighbour map for #{hash} is"
    IO.inspect neighbourMap

    {:noreply,{hash,neighbourMap}}
   end

   def insertAt(list,index,newnode) do
     {front,last} = Enum.split(list,index)
     [_|new_last] = last
     front ++ [newnode|new_last]
   end

    def handle_call({:fetchNodeRoutingMap},_from,state)do
     {_id,map} = state
     {:reply,map,state}
    end

    def routing(nodeId,destinationNode,hopNo,peers) do
           IO.puts("Node : #{nodeId}")
           cond do
             nodeId ==  destinationNode ->
             hopNo
             true ->
                 [pid]= Enum.reject(peers, fn(peer)->
                                                   id = GenServer.call(peer,{:fecthNodeId})
                                                   id  != nodeId end)

                 routingMap = GenServer.call(pid,{:fetchNodeRoutingMap})
                 IO.puts("Routing Map of Node >>>>>")
                 IO.inspect(routingMap)
               entryNo = String.at(destinationNode,hopNo)
               #IO.puts(entryNo)
               entry= String.to_integer(entryNo,16)
               #IO.inspect(Map.fetch(routingMap, hopNo+1))
               {:ok,levelnodes} = Map.fetch(routingMap, hopNo+1)
               #IO.inspect levelnodes
               node = Enum.at(levelnodes,entry)
               IO.puts("Fetching node #{node} from Level #{hopNo+1}")
               #IO.inspect(node)
               cond do
                 is_list(node) and Enum.empty?(node) -> IO.puts("No such fucking node !")
                 true -> routing(node,destinationNode,hopNo+1,peers)
               end
          end
    end


end
