<?xml version="1.0" ?>

<!-- $Header -->

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes"
    doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"/>

  <xsl:template match="/uuudoc">
    <html>
      <head>
	<title>Uuudoc</title>
	<style type="text/css">
	/*<![CDATA[*/
	  body {
	    background: #333;
	    color: black;
	    padding: 4em;
	    line-height: 1.4em;
	  }
	  div.proc {
	    background: #eee;
	    padding: 0.5em;
	    margin: 0 0 2em;
	  }
	  h1 {
	    margin: 0 0 1em;
	    font-size: 1.5em;
	    font-weight: bold;
	  }
	  h2 {
	    font-size: 1.15em;
	    font-weight: bold;
	  }
	  td, th {
	    padding-left: 0.7em;
	    padding-right: 0.7em;
	  }
	  td {
	    background: #ccc;
	  }
	/*]]>*/
	</style>
      </head>
      <body>
	<xsl:apply-templates select="proc">
	  <xsl:sort select="@name"/>
	</xsl:apply-templates>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="proc">
    <div class="proc">
      <h1>Procedure <xsl:value-of select="@name"/></h1>
      <xsl:if test="@brief">
	<p><xsl:value-of select="@brief"/></p>
      </xsl:if>
      <xsl:apply-templates select="text()|para"/>

      <h2>parameters</h2>
      <table>
	<tr><th>brief</th><th>reg</th><th>type</th><th>description</th></tr>
	<xsl:apply-templates select="p"/>
      </table>

      <h2>return states</h2>
      <table>
	<xsl:apply-templates select="ret"/>
      </table>
    </div>
  </xsl:template>

  <xsl:template match="para">
    <p><xsl:apply-templates/></p>
  </xsl:template>

  <xsl:template match="ret">
    <tr>
      <td><xsl:value-of select="@brief"/></td>
      <td><xsl:apply-templates/></td>
    </tr>
  </xsl:template>

  <xsl:template match="p">
    <tr>
      <td><xsl:value-of select="@brief"/></td>
      <td><xsl:value-of select="@reg"/></td>
      <td><xsl:value-of select="@type"/></td>
      <td><xsl:apply-templates/></td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
