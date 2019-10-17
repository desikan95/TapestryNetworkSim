defmodule Tapestry do
  use GenServer
  @moduledoc """
  Documentation for Tapestry.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Tapestry.hello()
      :world

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
    globalList = ["0123","0122","1234","1567","2345"]
    #neighbourMap = Enum.map(1..4,fn(level) -> cond do
     #                                          level == 1 ->
      #                                         levelmap = %{}
       #                                         map = Enum.map(0..10,fn(entry)-> list = Enum.reduce(globalIdList,[],fn id,acc->
        #                                                                                                                    cond do -> String.at(id,0) == entry
         #                                                                                                                               acc ++ [id]
           #                                                                                                                 end
          #                                                                                                                  acc
            #                                                                                                        end)
             #                                                        end)
              #                                end
               #                    end)
    #end
    levelList = Enum.reduce(0..10,[], fn entry,acc -> list = Enum.reduce(globalList, [], fn node,acc  -> IO.inspect(node)
                                                                                                        IO.inspect(String.at(node,0))
                                                                                                        cond do
                                                                                                        String.at(node,0) == entry ->
                                                                                                        acc ++ [node]
                                                                                                        true -> acc
                                                                                                        end
                                                                                          end)
                                                      id = String.to_integer(nodeId,16)
                                                      min = id
                                                      aptLink= nodeId
                                                      apt_entry = Enum.map(list,fn(potentialLink)-> difference = id - String.to_integer(potentialLink,16)
                                                                                                                    cond do
                                                                                                                      difference < min ->
                                                                                                                      min = difference
                                                                                                                      aptLink = potentialLink
                                                                                                                    end
                                                                                                                    aptLink
                                                                                  end )
                                        acc ++ [apt_entry]
                                        end)
                  levelList
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
