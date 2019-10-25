defmodule TapestryApp do
  use Application

  def start(_type,_args) do

    arguments = System.argv()
    {numNodes,_}=Integer.parse(Enum.at(arguments,0))
    {numRequests,_}=Integer.parse(Enum.at(arguments,1))

    IO.puts "Number of nodes and requests are #{numNodes} , #{numRequests}"

    pid = TapestrySupervisor.start_link(50)
    hops = TapestrySupervisor.findMaxHops(pid)
    IO.puts "Max HOPS : #{hops}"
  end
end
