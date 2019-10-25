defmodule TapestryApp do
  use Application

  def start(_type,_args) do

    arguments = System.argv()
    {numNodes,_}=Integer.parse(Enum.at(arguments,0))
    {numRequests,_}=Integer.parse(Enum.at(arguments,1))

    
    {pid,hops} = TapestrySupervisor.start_link(numNodes,numRequests) |> TapestrySupervisor.findMaxHops()
    maxhops = Enum.map(hops, fn hop->
                val = hop |> Enum.max
                val
              end)
              |> Enum.max
    IO.puts "Max Hops : #{maxhops}"

    {:ok,pid}
  end
end
