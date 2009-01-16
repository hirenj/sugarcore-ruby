#!/usr/bin/ruby

$:.push('./lib')

require 'logger'
require 'Sugar'
require 'Sugar/IO/CondensedIupac'


Sugar.log_level(0)

Monosaccharide.Load_Definitions('data/ic-dictionary.xml')

inseq = 'Man(b1-3)[Man(b1-3)[Man(b1-5)][Man(b1-4)]Man(b1-4)]GlcNAc'
sugar = Sugar.new()
sugar.extend( Sugar::IO::CondensedIupac::Builder )
sugar.extend(  Sugar::IO::CondensedIupac::Writer )
sugar.sequence = inseq
inseq2 = 'Man(b1-4)GlcNAc'
sugar2 = Sugar.new()
sugar2.extend( Sugar::IO::CondensedIupac::Builder )
sugar.extend(  Sugar::IO::CondensedIupac::Writer )
sugar2.sequence = inseq2
puts inseq
puts sugar.sequence
sugar.paths().each { |path|
	path.each { |res|
		puts res.name
	}
}
puts sugar.subtract(sugar2)

sugar3 = Sugar.new()
sugar3.extend( Sugar::IO::CondensedIupac::Builder )
sugar3.extend(  Sugar::IO::CondensedIupac::Writer )
sugar3.sequence = "Ser"