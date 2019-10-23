defmodule Tapestry do
  use GenServer
  @moduledoc """
  Documentation for Tapestry.
  """



  def buildNode(_x) do
    {:ok,pid} = GenServer.start_link(__MODULE__,[])
    pid
  end

  def init(_val)do
    state = {"",%{}}
    {:ok,state}
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

   def listOfIds(peers) do
    nodeids = Enum.reduce(peers, [], fn x, acc-> acc ++ [GenServer.call(x,{:fecthNodeId})]end)
    nodeids
   end

   def updateNodeState(peers) do
    listOfNodeIds = listOfIds(peers)
    Enum.map(peers,fn(peer) ->  GenServer.call(peer,{:updateStateWithRoutingTable,listOfNodeIds}) end)
   end

   def makeRequests(numNodes,_numRequests) do
    IO.puts("Number of nodes #{numNodes}")
    peers = createPeers(numNodes)
    #IO.puts("List of NodeIds : >>>>>")
    listOfNodeIds = listOfIds(peers)
    #IO.inspect(listOfNodeIds)
    updateNodeState(peers)
    Enum.map(peers,fn(peer)-> destinationNode = Enum.random(listOfNodeIds)
                              source = GenServer.call(peer,{:fecthNodeId})
                              IO.puts("Source Node: #{source}            Destination Node: #{destinationNode}")
                              noOfhops = routing(source,destinationNode,1,0,peers)
                              IO.puts("Number of hops: #{noOfhops}")
                              IO.puts("..........................................................................................")
                              end )

   end

   def handle_call({:mapToId,id},_from,state) do
    {_id,map}=state
    stringId = Integer.to_string(id)
     nodeid =  String.slice(:crypto.hash(:sha, stringId) |> Base.encode16, 0..3)
    state={nodeid,map}
    {:reply,nodeid,state}
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

   @spec nodeRoutingTable(any, integer) :: any
   def nodeRoutingTable(nodeId,globalList) do
    #globalList = listOfIds(num)
    #globalList = ["0123","2012","6137","6000","6100","6130","6131","6132","6133","6123","6900","0122","1234","1567","2345","3212","3025","A659","A770","D456","2135","2009","2112","2113","2114","2131","2130","213A"]

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
end
