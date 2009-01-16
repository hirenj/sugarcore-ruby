<?xml version="1.0"?>
<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:dict="http://penguins.mooh.org/research/glycan-dict-0.1" xmlns:dkfz="http://glycosciences.de" xmlns:ic="http://www.iupac.org/condensed" xmlns:disp="http://penguins.mooh.org/research/glycan-display-0.1" xmlns:svg="http://www.w3.org/2000/svg" >
<xsl:output method="xml" indent="yes" />
<!--
Set the outputtype to dkfz or ic to switch between the two different namespaces
-->
<xsl:param name="outputtype" select="'dkfz'"/>


<xsl:template match="/">
	<xsl:apply-templates select="*" />
</xsl:template>
<xsl:template match="dict:unit">
	<unit xmlns="http://penguins.mooh.org/research/glycan-dict-0.1">
		<xsl:apply-templates select="attribute::*" />
		<xsl:copy-of select="child::*"/>
	</unit>
</xsl:template>

<xsl:template match="@ic:name">
	<xsl:if test="$outputtype = 'ic'">
		<xsl:attribute name="name" namespace="http://www.iupac.org/condensed"><xsl:value-of select="."/></xsl:attribute>
	</xsl:if>
</xsl:template>

<xsl:template match="@dkfz:name">
	<xsl:if test="$outputtype = 'dkfz'">
		<xsl:attribute name="name" namespace="http://glycosciences.de"><xsl:value-of select="."/></xsl:attribute>
	</xsl:if>
</xsl:template>

<xsl:template match="dict:glycanDict">
	<dict:glycanDict xmlns="http://penguins.mooh.org/research/glycan-dict-0.1">
		<xsl:apply-templates select="*"/>
	</dict:glycanDict>
</xsl:template>

</xsl:transform>
