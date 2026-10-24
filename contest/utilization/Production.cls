Class Contest.Utilization.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.Utilization.Production" LogGeneralTraceEvents="false">
  <Description>Bounded synthetic FHIR utilization to a same-instance SQL receiver. No model calls.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="FHIRSource" ClassName="Contest.Utilization.Service" PoolSize="1" Enabled="true"/>
  <Item Name="UtilizationProcess" ClassName="Contest.Utilization.Process" PoolSize="1" Enabled="true"/>
  <Item Name="AnalysisReceiver" ClassName="Contest.Utilization.Receiver" PoolSize="1" Enabled="true"/>
</Production>
}
}
