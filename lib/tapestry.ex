defmodule TapestrySupervisor do
  use Supervisor

  def start_link(numNodes,numRequests) do
    {:ok, pid} = Supervisor.start_link(__MODULE__,numNodes,name: __MODULE__)
    nodes = initializeChildNodes(pid)
    {:ok,newnode} = Supervisor.start_child(pid,Supervisor.child_spec(Tapestry,id: numNodes))
    Tapestry.networkJoin(nodes,numNodes,newnode)

    beginRouting(numRequests,pid)
    :timer.sleep(2000)
    pid
  end

  def init(numNodes) do

    children = Enum.map(1..(numNodes-1),fn (x) -> Supervisor.child_spec(Tapestry,id: x) end)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def initializeChildNodes(pid) do
    result = Supervisor.which_children(pid)
    nodes = Enum.map(result, fn (x) ->
                                {id,pid,_,_} = x
                                Tapestry.mapPIDNodeId(pid,id)
                                pid end)

    Tapestry.updateNodeState(nodes)
    nodes
  end

  def beginRouting(requests,pid) do
    result = Supervisor.which_children(pid)
    allchildren = Enum.map(result, fn (x) ->
                                {_,pid,_,_} = x
                                pid end)

    listOfNodeIds = Tapestry.listOfIds(allchildren)
    Tapestry.updateNodeState(allchildren)
    pidmapper = Enum.reduce(allchildren,%{},fn node,map -> {id,_,_} = GenServer.call(node,{:print})
                                                      Map.put(map,id,node)
                end)

    Enum.each(allchildren, fn node ->
      spawn( fn ->
      Tapestry.makeRequests(node,pidmapper,requests,listOfNodeIds)
      end)
    end)

    requests
  end

  def findMaxHops(pid) do
    result = Supervisor.which_children(pid)
    nodes = Enum.map(result, fn (x) ->
                                {_,pid,_,_} = x
                                pid end)

    maxhops =   Enum.map(nodes, fn (node)->
                  {_,_,hop} = GenServer.call(node,{:print})
                  hops = hop |> Map.values |> Enum.reject(fn x -> x==:ok end) |> Enum.reject(fn x-> x==[] end)
                  hops
                end)
                |> Enum.reject(fn x-> x==[] end)
      {pid,maxhops}
  end



end



defmodule Tapestry do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__,[])
  end

  def init(_val)do
    state = {"",%{},%{}}
    {:ok,state}
   end

  def mapPIDNodeId(pid , id) do
    GenServer.call(pid,{:mapToId,id})
  end


   def initializeNeighbours(node,nodes) do

      sourceNode = GenServer.call(node,{:getHash})
      nodeHashes = Enum.map(nodes, fn x -> GenServer.call(x,{:getHash}) end)

      routingTable = nodeRoutingTable(sourceNode,nodeHashes)
      GenServer.call(node,{:saveRoutingTable,routingTable})

   end

   def networkJoin(nodes,nodenumber,pid) do


     mapPIDNodeId(pid,nodenumber)

     hash = GenServer.call(pid,{:getHash})

     root = Enum.min_by(nodes,fn potentialLink ->
                newhash = GenServer.call(potentialLink,{:getHash})
                abs (String.to_integer(hash,16) - String.to_integer(newhash,16))
            end)

     roothash = GenServer.call(root,{:getHash})

     p = findLevel(hash,roothash,0)

     needtoknowInitial = GenServer.call(root,{:getNodesAtLevels,p})
     hashnodemap = Enum.reduce(nodes, %{}, fn (node,map) -> hashval = GenServer.call(node,{:getHash})
                                                            Map.put(map,hashval,node)
                                                            end)

     needtoknow = Enum.reduce(p..8, needtoknowInitial, fn (p,acc) ->
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


     Enum.each(needtoknow, fn (node) ->
       newnodehash = GenServer.call(pid, {:getHash})
       GenServer.cast( Map.get(hashnodemap,node), {:addNewNode,newnodehash})
     end)

     routingTable = nodeRoutingTable(hash,[hash|needtoknow])
     GenServer.call(pid,{:saveRoutingTable,routingTable})
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
    routingMap = Enum.reduce(1..8,%{}, fn level, acc -> cond do
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

  def makeRequests(node,pidmapper,numRequests,listofNodeIds) do

            Enum.each(1..numRequests, fn x ->

              spawn(fn ->
                                        destinationhash = Enum.random(listofNodeIds)
                                        GenServer.cast(node,{:routing,node,destinationhash,0,pidmapper})
                   end)
              end)

  end

   def handle_call({:mapToId,id},_from,state) do
    {_id,map,hopstodestination}=state
    stringId = Integer.to_string(id)
     nodeid =  String.slice(:crypto.hash(:sha, stringId) |> Base.encode16, 0..7)
    state={nodeid,map,hopstodestination}
    {:reply,nodeid,state}
   end

   def handle_call({:getNodesAtLevels,level},_from,state) do
    {_id,routingMap,_}=state
    result = level..8
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
     {id, _,_} = state
     {:reply,id,state}
   end

   def handle_call({:updateStateWithRoutingTable,globalList},_from,state) do
    {id,_map,hopstodestination}=state
    routingmap = nodeRoutingTable(id,globalList)
    state={id,routingmap,hopstodestination}
    {:reply,routingmap,state}
   end

   def handle_call({:fecthNodeId},_from,state)do
    {id,_map,_}=state
    {:reply,id,state}
   end

    def handle_call({:saveRoutingTable,routingTable},_from,state) do
      {id,_,hopstodestination} = state
      {:reply,routingTable,{id,routingTable,hopstodestination}}
    end

   def handle_call({:fetchNodeRoutingMap},_from,state)do
    {_id,map,_} = state
    {:reply,map,state}
   end

  def handle_cast({:routing,sourcePID,destinationhash,hopNo,pidmapper},state) do
    {ownhash,routingMap,_} = state



    cond do
      ownhash ==  destinationhash -> GenServer.cast(sourcePID,{:sendresult,hopNo,destinationhash})
      true ->

        currentLevel = findLevel(ownhash,destinationhash,0)
        entryNo = String.at(destinationhash,currentLevel-1)
        entry= String.to_integer(entryNo,16)
        levelnodes = Map.get(routingMap,currentLevel)
        nextNode = Enum.at(levelnodes,entry)

        cond do
          is_list(nextNode) and Enum.empty?(nextNode) -> IO.puts("No such node !")
          nextNode == ownhash -> GenServer.cast(sourcePID,{:sendresult,hopNo+1,destinationhash})
          true -> GenServer.cast(Map.get(pidmapper,nextNode),{:routing,sourcePID,destinationhash,hopNo+1,pidmapper})
        end

    end
    {:noreply,state}
  end

  def handle_cast({:sendresult,hop,destinationhash},state) do
    {id,routingmap,hopstodestination} = state
    hopstodestination = Map.put(hopstodestination,destinationhash,hop)
    {:noreply,{id,routingmap,hopstodestination}}
  end


   def handle_cast({:addNewNode,newnodehash},state) do

    {hash,neighbourMap,hopstodestination} = state
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


    {:noreply,{hash,neighbourMap,hopstodestination}}
   end

   def insertAt(list,index,newnode) do
     {front,last} = Enum.split(list,index)
     [_|new_last] = last
     front ++ [newnode|new_last]
   end

    def handle_call({:fetchNodeRoutingMap},_from,state)do
     {_id,map,_} = state
     {:reply,map,state}
    end


end
