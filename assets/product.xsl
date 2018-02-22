<xsl:template match="wix:File[contains(@Source,'\pwsh.exe')]">
  <xsl:copy-of select="." />
  <Shortcut Id='PowerShell_ProgramsMenuShortcut'
          Advertise="yes"
          Name='$(var.ProductSemanticVersionWithNameAndOptionalArchitecture)'
          Icon='PowerShellExe.ico'
          Description='$(var.ProductSemanticVersionWithNameAndOptionalArchitecture)'
          WorkingDirectory='$(var.ProductVersionWithName)'/>
</xsl:template>
