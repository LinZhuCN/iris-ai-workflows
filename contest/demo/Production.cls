Class Demo.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Demo.Production" LogGeneralTraceEvents="false">
  <Description>Synthetic-only P2 business routes and asynchronous observation transport. No external destination.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="EnsLib.Testing.Service" ClassName="EnsLib.Testing.Service" PoolSize="1" Enabled="true"/>
  <Item Name="EnsLib.Testing.Process" ClassName="EnsLib.Testing.Process" PoolSize="1" Enabled="true"/>
  <Item Name="DemoRouter" ClassName="Demo.Router" PoolSize="1" Enabled="true"/>
  <Item Name="TreatmentSink" ClassName="Demo.Sink" PoolSize="1" Enabled="true"/>
  <Item Name="AnalyticsSink" ClassName="Demo.Sink" PoolSize="1" Enabled="true"/>
  <Item Name="FailureSink" ClassName="Demo.Sink" PoolSize="1" Enabled="true"/>
  <Item Name="ObservationDispatcher" ClassName="Demo.Dispatcher" PoolSize="1" Enabled="true">
    <Setting Target="Adapter" Name="CallInterval">2</Setting>
  </Item>
  <Item Name="ObservationSender" ClassName="Demo.Sender" PoolSize="1" Enabled="true"/>
</Production>
}
}
