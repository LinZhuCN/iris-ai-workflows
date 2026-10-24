Class Contest.BusinessToolSetV2 Extends %AI.ToolSet [ DependsOn = Contest.BusinessToolsV2 ]
{
XData Definition
{
<ToolSet>
  <Description>Read bound synthetic facts, discover normative evidence, verify exact CFR sections and select server-authored passage IDs. Three combined retrieval calls, no execution tools.</Description>
  <Include Class="Contest.BusinessToolsV2"/>
</ToolSet>
}
}
