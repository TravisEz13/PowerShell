<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:wix="http://schemas.microsoft.com/wix/2006/wi">
  <xsl:output method="xml" indent="yes" />
  
  <!-- copy all to output -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>

  <!-- add shortcut to pwsh.exe -->
  </xsl:template>  <xsl:template match="wix:File[contains(@Source,'\pwsh.exe')]">
    <xsl:copy-of select="." />
    <Shortcut Id='PowerShell_ProgramsMenuShortcut'
      Advertise="yes"
      Name='test'
      Icon='PowerShellExe.ico'
      Description='test'
      WorkingDirectory='$(env.ProductVersionWithName)'/>
  </xsl:template>
</xsl:stylesheet>
