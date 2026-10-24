Class Contest.BusinessToolSet Extends %AI.ToolSet [ DependsOn = Contest.BusinessTools ]
{
XData Definition
{
<ToolSet>
  <Description>Read bound synthetic business facts, then search pinned public normative evidence with at most three contextual queries. No execution tools.</Description>
  <Include Class="Contest.BusinessTools"/>
</ToolSet>
}
}
