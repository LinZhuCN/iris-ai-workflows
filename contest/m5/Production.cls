Class Contest.M5.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.M5.Production" LogGeneralTraceEvents="false">
  <Description>Isolated synthetic quality-intake observation; not an enforcement gate or a legal compliance test.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="M5Source" ClassName="Contest.M5.Service" PoolSize="1" Enabled="true"/>
  <Item Name="ProcessA" ClassName="Contest.M5.Process" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverA</Setting></Item>
  <Item Name="ProcessB" ClassName="Contest.M5.Process" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverB</Setting></Item>
  <Item Name="ProcessC" ClassName="Contest.M5.Process" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverC</Setting></Item>
  <Item Name="ProcessD" ClassName="Contest.M5.Process" PoolSize="1" Enabled="true"><Setting Target="Host" Name="Target">ReceiverD</Setting></Item>
  <Item Name="ReceiverA" ClassName="Contest.M5.Operation" PoolSize="1" Enabled="true"/>
  <Item Name="ReceiverB" ClassName="Contest.M5.Operation" PoolSize="1" Enabled="true"/>
  <Item Name="ReceiverC" ClassName="Contest.M5.Operation" PoolSize="1" Enabled="true"/>
  <Item Name="ReceiverD" ClassName="Contest.M5.Operation" PoolSize="1" Enabled="true"/>
</Production>
}
}
