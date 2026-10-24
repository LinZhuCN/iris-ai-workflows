Class Contest.Aggregation.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.Aggregation.Production" LogGeneralTraceEvents="false">
  <Description>Synthetic SQL to isolated FHIR R4 aggregation. No model calls.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="SQLSource" ClassName="Contest.Aggregation.Service" PoolSize="1" Enabled="true"/>
  <Item Name="AggregationProcess" ClassName="Contest.Aggregation.Process" PoolSize="1" Enabled="true"/>
  <Item Name="FHIRSender" ClassName="Contest.Aggregation.Operation" PoolSize="1" Enabled="true"/>
</Production>
}
}
