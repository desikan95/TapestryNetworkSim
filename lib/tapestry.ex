defmodule TapestrySupervisor do
  use Supervisor

  def start_link(numNodes) do
    {:ok, pid} = Supervisor.start_link(__MODULE__,numNodes,name: __MODULE__)
    IO.puts "The supervisor ID is "
    IO.inspect pid
    initializeChildNodes(pid)
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
    initializeNeighbourMap(nodes)
  end

  def initializeNeighbourMap(nodes) do
    IO.puts "Need to initialize neighbour map for all nodes as follows : "
    IO.inspect nodes
    Enum.each(nodes, fn (node) -> Tapestry.initializeNeighbours(node,nodes)   end)

    Tapestry.networkJoin(nodes)
  end

  def init(numNodes) do

    children = Enum.map(1..numNodes,fn (x) -> Supervisor.child_spec(Tapestry,id: x) end)

    IO.puts "Children are"
    IO.inspect children

    Supervisor.init(children, strategy: :one_for_one)
  end
end


defmodule Tapestry do
  use GenServer

  def start_link(_) do

    GenServer.start_link(__MODULE__,[])

  end

  def buildNode(_x) do
    {:ok,pid} = GenServer.start_link(__MODULE__,[])
    pid
  end

  def init(_val)do
    state = {0,%{}}
    {:ok,state}
   end

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

   def networkJoin(nodes) do
     {:ok,pid} = GenServer.start_link(__MODULE__,[])
     IO.puts "New node initialized "
     IO.inspect pid

     mapPIDNodeId(pid,100)

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
   end

   def findLevel(str1,str2,i) do
     cond do
        (i == String.length(str1) ) -> i+1
        (String.at(str1,i)!= String.at(str2,i)) -> i+1
        (String.at(str1,i) == String.at(str2,i)) -> findLevel(str1,str2,i+1)
        true -> i+1
     end
   end

#   @spec nodeRoutingTable(any, integer) :: any
   def nodeRoutingTable(nodeId,nodes) do
    #globalList = listOfIds(num)
    #globalList = ["0123","0122","1234","1567","2345","3212","3025","A659","A770","D456","2135","2009","2112","2113","2114","2131","2130","213A"]
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



   def listOfIds(num) do
    peers = createPeers(num)
    nodeids = Enum.reduce(peers, [], fn x, acc-> {id,_list} = GenServer.call(x,{:print})
                                            acc ++ [id]
                                            end )
    nodeids
   end

   def handle_call({:mapToId,id},_from,state) do
    {_id,list}=state
    stringId = Integer.to_string(id)
     nodeid =  String.slice(:crypto.hash(:sha, stringId) |> Base.encode16, 0..3)
    state={nodeid,list}
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

   def handle_cast({:saveRoutingTable,routingTable},state) do
     {id,_}=state
     {:noreply,{id,routingTable}}
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

                                        if (abs(new_val-ownhash_val) > abs(curr_val-ownhash_val)) do
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

   def createRoutingTable(nodeId) do
    id = Integer.to_string(nodeId)
    length = String.length(id)
    map= %{}
    final_map = Enum.reduce 1..length, map, fn i, acc -> Map.put(acc,i,[]) end
    neighbour_list = Enum.map(Map.keys(final_map), fn(level)->
                                                                #IO.inspect level
                                                                list  = Enum.map(0..9,
                                                                  fn(entry) -> levelnodes = Enum.reduce(0..length-1,"",
                                                                                            fn i,acc ->
                                                                                                      cond do

                                                                                                      i<level ->
                                                                                                                    str =  acc <> String.at(id, i)
                                                                                                                    str
                                                                                                      i == level ->
                                                                                                                    str = acc <> Integer.to_string(entry)
                                                                                                                    str
                                                                                                      i>level ->
                                                                                                                    str = acc <> "0"
                                                                                                                    str
                                                                                                      end
                                                                                             end )

                                                                                 #levelmap = Enum.reduce levelnodes, Map.fetch!(final_map,level), fn node,acc -> Map.get_and_update!(final_map,level, acc ++ node) end
                                                                                 #levelmap = Map.put(final_map,level,levelnodes)
                                                                                 #IO.inspect levelmap
                                                                             #IO.inspect (acc ++ string)
                                                                    end)

                                                                #bool = is_list(list)
                                                                IO.puts level
                                                                crap = Enum.reduce(list,[],fn item,acc-> acc ++ item end)
                                                                IO.puts crap
                                                                #Enum.each(list, fn(item)-> IO.puts(item)end)
                                                                #IO.puts(bool)
                                                end)
                                                #IO.inspect neighbour_list
   end
end
