Class Contest.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.Production" LogGeneralTraceEvents="false">
  <Description>Isolated AI Hub message triage with deterministic execution policy.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="EnsLib.Testing.Service" ClassName="EnsLib.Testing.Service" PoolSize="1" Enabled="true"/>
  <Item Name="EnsLib.Testing.Process" ClassName="EnsLib.Testing.Process" PoolSize="1" Enabled="true"/>
  <Item Name="TriageProcess" ClassName="Contest.Process" PoolSize="1" Enabled="true"/>
  <Item Name="TriageSink" ClassName="Contest.Sink" PoolSize="1" Enabled="true"/>
</Production>
}
}
