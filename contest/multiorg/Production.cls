Class Contest.Multi.Production Extends Ens.Production
{
XData ProductionDefinition
{
<Production Name="Contest.Multi.Production" LogGeneralTraceEvents="false">
  <Description>Synthetic FHIR distribution to three isolated institutions; advisory post-send audit.</Description>
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="FHIRSource" ClassName="Contest.Multi.Service" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoHospital</Setting></Item>
  <Item Name="Distribute" ClassName="Contest.Multi.Process" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoHospital</Setting></Item>
  <Item Name="QualitySQL" ClassName="Contest.Multi.Operation" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoQuality</Setting></Item>
  <Item Name="ResearchREST" ClassName="Contest.Multi.Operation" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoResearch</Setting></Item>
  <Item Name="ClinicHL7" ClassName="Contest.Multi.Operation" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoClinic</Setting></Item>
  <Item Name="AuditSource" ClassName="Contest.Multi.AuditService" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoHospital</Setting></Item>
  <Item Name="AdvisoryAudit" ClassName="Contest.Multi.AuditProcess" PoolSize="1" Enabled="true"><Setting Target="Host" Name="BusinessPartner">DemoHospital</Setting></Item>
</Production>
}
}
