#!/usr/bin/env ruby
#
#  Created by Hiren Joshi on 2007-10-10.
#  Copyright (c) 2007. All rights reserved.

$:.push('lib')

require 'Sugar'
require 'Sugar/IO/CondensedIupac'
require 'Sugar/IO/GlycoCT'
require 'Sugar/IO/Glyde'
require 'MultiSugar'
require 'SugarException'
require 'Render/Renderable'
require 'Render/CondensedLayout'
require 'Render/CondensedScalableLayout'
require 'Render/GridLayout'
require 'Render/SvgRenderer'
require 'Render/HtmlTextRenderer'

Monosaccharide.Load_Definitions("data/dictionary.xml")
NamespacedMonosaccharide.Default_Namespace = :ecdb

NamespacedMonosaccharide.log_level(-1)
CondensedScalableLayout.logger = Logger.new(STDERR)
CondensedScalableLayout.log_level(-1)
SvgRenderer.logger = CondensedScalableLayout.logger



sugar = Sugar.new()
sugar.extend(Sugar::IO::CondensedIupac::Builder)
sugar.input_namespace = :ic
sugar.extend(Sugar::IO::CondensedIupac::Writer)
sugar.target_namespace = :ic
sugar.extend(Sugar::MultiSugar)

seq='Fuc(a1-2)[Gal(b1-4)GlcNAc(b1-6)][NeuAc(a2-3)][Gal(a1-3)][Fuc(a1-2)[Fuc(a1-3)[Gal(b1-4)]GlcNAc(b1-6)][Gal(a1-3)][GalNAc(a1-3)][Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)]Gal(b1-3)[Gal(b1-4)][Fuc(a1-4)]GlcNAc(b1-3)][GalNAc(a1-3)]Gal(b1-3)[Gal(b1-3)[Fuc(a1-4)][Fuc(a1-2)[GalNAc(a1-3)][Gal(a1-3)][Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)]Gal(b1-4)][Fuc(a1-3)]GlcNAc(b1-6)][NeuAc(a2-6)][Fuc(a1-2)[GalNAc(a1-3)]Gal(b1-3)GlcNAc(b1-3)][GalNAc(a1-3)]GalNAc'
#seq = 'Fuc(a1-2)[GlcNAc(b1-6)][NeuAc(a2-3)][Gal(b1-3)[GlcNAc(b1-3)[GlcNAc(b1-6)]Gal(b1-4)]GlcNAc(b1-3)][Gal(a1-3)]Gal(b1-3)GalNAc'
#sugar.sequence="Fuc(a1-4)[GlcNAc(b1-3)][Gal(b1-3)GlcNAc(b1-6)]Gal(b1-4)GlcNAc(b1-2)[Fuc(a1-4)[GlcNAc(b1-3)][Gal(b1-3)GlcNAc(b1-6)]Gal(b1-4)GlcNAc(b1-4)]Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)[Fuc(a1-3)]GlcNAc"
#sugar.sequence="Fuc(a1-2)[NeuAc(a2-6)][GlcNAc(b1-3)Gal(b1-3)]GalNAc"
sugar.sequence = seq

sugar.extend(Renderable::Sugar)

renderer = SvgRenderer.new()
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

sugar.root.children.select { |kid| kid[:residue].name(:ic) == 'Gal' && kid[:residue].anomer = 'b' }.each { |kid|
  chains = sugar.get_chains_from_residue(kid[:residue])
  chains.flatten.uniq.each { |res|
    res.scale_by_factor(1.5)
  }
}

#puts sugar.sequence_from_residue(the_gal[:residue])
# 
# puts sugar.get_chains_from_residue(the_gal[:residue]).size
# 
# exit

my_layout = CondensedScalableLayout.new()
my_layout.node_spacing = {:x => 100, :y => 100 }
my_layout.layout(sugar)
@result = renderer.render(sugar)

puts @result
0.times do 
sugar.sequence='Gal(b1-4)GlcNAc(b1-4)GlcNAc'
sugar.extend(Renderable::Sugar)

CondensedScalableLayout.new().layout(sugar)

renderer = SvgRenderer.new()
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

@result = renderer.render(sugar)
#puts @result
end