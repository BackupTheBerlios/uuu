<?xml version="1.0" ?>

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text"/>

  <xsl:template match="/uuudoc">
    <xsl:apply-templates select="proc"/>
  </xsl:template>

  <xsl:template match="proc">
    <xsl:text>%define </xsl:text>
    <xsl:value-of select="@name"/>
    <xsl:text>__ret_count </xsl:text>
    <xsl:value-of select="count( ret )"/>
    <xsl:text>
</xsl:text>
  </xsl:template>

</xsl:stylesheet>
