Class Contest.StructuredProduction Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.StructuredProduction" LogGeneralTraceEvents="false">
  <Description>Isolated synthetic multi-path evidence acceptance. No inference or external transport.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="StructuredSource" ClassName="Contest.StructuredService" PoolSize="1" Enabled="true"/>
  <Item Name="ProcessA" ClassName="Contest.StructuredProcess" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverA</Setting></Item>
  <Item Name="ProcessB" ClassName="Contest.StructuredProcess" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverB</Setting></Item>
  <Item Name="ProcessC" ClassName="Contest.StructuredProcess" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverC</Setting></Item>
  <Item Name="ReceiverA" ClassName="Contest.StructuredOperation" PoolSize="1" Enabled="true"/>
  <Item Name="ReceiverB" ClassName="Contest.StructuredOperation" PoolSize="1" Enabled="true"/>
  <Item Name="ReceiverC" ClassName="Contest.StructuredOperation" PoolSize="1" Enabled="true"/>
</Production>
}
}
