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

   def handle_call({:print},_from,state) do
    {:reply,state,state}
   end

   @spec nodeRoutingTable(any, integer) :: any
   def nodeRoutingTable(nodeId,num) do
    #globalList = listOfIds(num)
    globalList = ["0123","0122","1234","1567","2345","3212","3025","A659","A770","D456","2135","2009","2112","2113","2114","2131","2130","213A"]

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
