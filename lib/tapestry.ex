defmodule TapestrySupervisor do
  use Supervisor

  def start_link(numNodes) do
    {:ok, pid} = Supervisor.start_link(__MODULE__,numNodes,name: __MODULE__)
    IO.puts "The supervisor ID is "
    IO.inspect pid
    nodes = initializeChildNodes(pid)
    {:ok,newnode} = Supervisor.start_child(pid,Supervisor.child_spec(Tapestry,id: numNodes))
    samenewnode = Tapestry.networkJoin(nodes,numNodes,newnode)

    #beginRouting(8,pid)
    pid
  end

  def init(numNodes) do

    children = Enum.map(1..(numNodes-1),fn (x) -> Supervisor.child_spec(Tapestry,id: x) end)

    IO.puts "Children are"
    IO.inspect children

    Supervisor.init(children, strategy: :one_for_one)
  end

  def initializeChildNodes(pid) do
    result = Supervisor.which_children(pid)
#    IO.inspect result

    nodes = Enum.map(result, fn (x) ->
                                {id,pid,_,_} = x
                                Tapestry.mapPIDNodeId(pid,id)
                                pid end)
    IO.inspect nodes


        Tapestry.updateNodeState(nodes)



#    Enum.each(nodes, fn (node) -> Tapestry.initializeNeighbours(node,nodes)   end)
    nodes
  end

  def initializeNeighbourMap(nodes) do


#    newnode = Tapestry.networkJoin(nodes,numNodes)
#    newnode2 = Tapestry.networkJoin([newnode|nodes],numNodes+1)
#    Tapestry.makeRequests([newnode|nodes],9)
  end

  def beginRouting(requests,pid) do


    result = Supervisor.which_children(pid)

    allchildren = Enum.map(result, fn (x) ->
                                {_,pid,_,_} = x
                                pid end)

    IO.inspect allchildren



  #  allchildrenids = Enum.map(allchildren,fn (node) ->
  #    {id,neighbours,_} = GenServer.call(node,{:print})
  #    IO.puts "\n\nNode #{id}"
  #    IO.puts "Neighbours"
  #    IO.inspect neighbours
  #    id
  #  end)
    #Tapestry.makeRequests(allchildren,9)
    listOfNodeIds = Tapestry.listOfIds(allchildren)
  #  source = GenServer.call(node,{:fecthNodeId})

    Tapestry.updateNodeState(allchildren)





    pidmapper = Enum.reduce(allchildren,%{},fn node,map -> {id,_,_} = GenServer.call(node,{:print})
                                                      Map.put(map,id,node)
                end)



    IO.puts "Number of requests are #{requests}"
  #  Enum.each(1..requests, fn request ->

  #    destinationhash = Enum.random(listOfNodeIds)
  #    IO.puts "Request number #{request} , Destionation hash is #{destinationhash}"
  #    Enum.each(allchildren, fn(node) ->
  #      Tapestry.oldmakeRequests(destinationhash,node,pidmapper)
  #    end)
  #  end)

    Enum.each(allchildren, fn node ->
      spawn( fn ->
      Tapestry.makeRequests(node,pidmapper,requests,listOfNodeIds)

    end)
    end)



  #  maxhops =       Enum.map(allchildren,fn node ->
  #                    {id,_,hopstodestination} = GenServer.call(node,{:print})
  #                    IO.puts "For #{id}"
  #                    IO.inspect hopstodestination
  #                    maxhops = hopstodestination |> Map.values |> Enum.max
  #                    maxhops
  #                  end)
  #                  |> Enum.max

  #  IO.puts "Max hops : #{maxhops}"

  #WORKING CODEEEEEEEEEEEEEEEE



    requests
    #findMaxHops(pid)
  end

  def handle_info(:completingtask,state) do
    IO.puts "CONTINUING TASK"
    {:noreply,state}
  end


  def findMaxHops(pid) do
    result = Supervisor.which_children(pid)
    nodes = Enum.map(result, fn (x) ->
                                {_,pid,_,_} = x
                                pid end)

    maxhops =   Enum.map(nodes, fn (node)->
                  {id,_,hop} = GenServer.call(node,{:print})
                  IO.puts " for #{id}"
                  IO.inspect hop
                  hops = hop |> Map.values |> Enum.reject(fn x -> x==:ok end) |> Enum.reject(fn x-> x==[] end)
                  IO.inspect hops
                  #IO.puts "List of max hop values are #{hops}"
                  hops
                end)
                |> Enum.reject(fn x-> x==[] end)

    #  IO.puts "All max values are #{maxhops}"
      maxhops
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
      nodeHashes = Enum.map(nodes, fn x -> GenServer.call(x,{:getHash}) end)

      routingTable = nodeRoutingTable(sourceNode,nodeHashes)
      GenServer.call(node,{:saveRoutingTable,routingTable})

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
#     IO.puts "Need to check from levels #{p} "

     needtoknowInitial = GenServer.call(root,{:getNodesAtLevels,p})
     hashnodemap = Enum.reduce(nodes, %{}, fn (node,map) -> hashval = GenServer.call(node,{:getHash})
                                                            Map.put(map,hashval,node)
                                                            end)

     needtoknow = Enum.reduce(p..6, needtoknowInitial, fn (p,acc) ->
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
    routingMap = Enum.reduce(1..6,%{}, fn level, acc -> cond do
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

   def oldmakeRequests(destinationhash,node,pidmapper) do
     GenServer.cast(node,{:routing,node,destinationhash,0,pidmapper})
   end

#   def makeRequests(nodes,node) do
    def makeRequests(node,pidmapper,numRequests,listofNodeIds) do
  #  IO.puts("Number of nodes #{nodes}")
  #  peers = createPeers(numNodes)
    #IO.puts("List of NodeIds : >>>>>")
#    listOfNodeIds = listOfIds(nodes)
  #  source = GenServer.call(node,{:fecthNodeId})

#    updateNodeState(nodes)

#    pidmapper = Enum.reduce(nodes,%{},fn node,map -> {id,_,_} = GenServer.call(node,{:print})
#                                                      Map.put(map,id,node)
#                end)

    Enum.each(1..numRequests, fn x ->

      spawn(fn ->
                                      destinationhash = Enum.random(listofNodeIds)

                                GenServer.cast(node,{:routing,node,destinationhash,0,pidmapper})


                                   end)
    end)

    #hops = Enum.map(1..numRequests,fn(peer)-> destinationNode = Enum.random(listOfNodeIds)
                          #    source = GenServer.call(peer,{:fecthNodeId})
                          #    IO.puts("Source Node: #{source}            Destination Node: #{destinationNode}")
                          #    noOfhops = routing(source,destinationNode,1,0,nodes)

                          #    GenServer.cast(node,{:routing,node,destinationNode,0,nodes})


                          #    IO.puts("Number of hops: #{noOfhops}")
                          #    IO.puts("..........................................................................................")
                            #  noOfhops

    #                          end )
    #       |> Enum.max
  #   IO.puts "Max Number of hops for #{source} are #{hops}"

     # hops
   end

   def handle_call({:makeRequests,node,pidmapper,numRequests,listofNodeIds},_from,state) do

     Enum.each(1..numRequests, fn x ->
                                       destinationhash = Enum.random(listofNodeIds)

                                      GenServer.cast(node,{:routing,node,destinationhash,0,pidmapper})
     end)


     {_,_,hopmap} = state
     {:reply,hopmap,state}
   end

   def handle_call({:mapToId,id},_from,state) do
    {_id,map,hopstodestination}=state
    stringId = Integer.to_string(id)
     nodeid =  String.slice(:crypto.hash(:sha, stringId) |> Base.encode16, 0..5)
    state={nodeid,map,hopstodestination}
    {:reply,nodeid,state}
   end

   def handle_call({:getNodesAtLevels,level},_from,state) do
    {_id,routingMap,_}=state
    result = level..6
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
          is_list(nextNode) and Enum.empty?(nextNode) -> IO.puts("No such fucking node !")
          nextNode == ownhash -> GenServer.cast(sourcePID,{:sendresult,hopNo+1,destinationhash})
          true -> GenServer.cast(Map.get(pidmapper,nextNode),{:routing,sourcePID,destinationhash,hopNo+1,pidmapper})
        end

    end
    {:noreply,state}
  end

  def handle_cast({:sendresult,hop,destinationhash},state) do
    {id,routingmap,hopstodestination} = state
    hopstodestination = Map.put(hopstodestination,destinationhash,hop)
  #  IO.puts "Hops from #{id} to #{destinationhash} : #{hop} "
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
