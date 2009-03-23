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
require 'Render/CollapsedStubs'

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

seq='Fuc(a1-2)[GlcNAc(b1-6)[GlcNAc(b1-3)]Gal(b1-4)GlcNAc(b1-6)][NeuAc(a2-3)][Gal(a1-3)][Fuc(a1-2)[Fuc(a1-3)[Gal(b1-4)]GlcNAc(b1-6)][Gal(a1-3)][GalNAc(a1-3)][Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)]Gal(b1-3)[Gal(b1-4)][Fuc(a1-4)]GlcNAc(b1-3)][GalNAc(a1-3)]Gal(b1-3)[Gal(b1-3)[Fuc(a1-4)][Fuc(a1-2)[GalNAc(a1-3)][Gal(a1-3)][Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)]Gal(b1-4)][Fuc(a1-3)]GlcNAc(b1-6)][NeuAc(a2-6)][Fuc(a1-2)[GalNAc(a1-3)]Gal(b1-3)GlcNAc(b1-3)][GalNAc(a1-3)]GalNAc'
#seq='GlcNAc(b1-3)[GlcNAc(b1-6)]Gal(b1-3)GalNAc'
#seq = 'Fuc(a1-2)[GlcNAc(b1-6)][NeuAc(a2-3)][Gal(b1-3)[GlcNAc(b1-3)[GlcNAc(b1-6)]Gal(b1-4)]GlcNAc(b1-3)][Gal(a1-3)]Gal(b1-3)GalNAc'
#seq="Fuc(a1-4)[GlcNAc(b1-3)][Gal(b1-3)GlcNAc(b1-6)]Gal(b1-4)GlcNAc(b1-2)[Fuc(a1-4)[GlcNAc(b1-3)][Gal(b1-3)GlcNAc(b1-6)]Gal(b1-4)GlcNAc(b1-4)]Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)[Fuc(a1-3)]GlcNAc"
#seq="Fuc(a1-2)[NeuAc(a2-6)][GlcNAc(b1-3)Gal(b1-3)]GalNAc"
#seq='Gal(b1-3)[GlcNAc(b1-3)Gal(b1-4)]GlcNAc(b1-2)[Gal(b1-3)[Gal(b1-4)]GlcNAc(b1-4)]Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)GlcNAc'
#seq='NeuAc(a2-6)[GalNAc(a1-3)]Gal(b1-3)[Fuc(a1-4)]GlcNAc(b1-3)[Fuc(a1-3)[Fuc(a1-2)[NeuAc(a2-3)][Gal(a1-3)]Gal(b1-4)GlcNAc(b1-3)Gal(b1-4)]GlcNAc(b1-6)]Gal(b1-3)[Fuc(a1-6)]GlcNAc'
#seq='NeuAc(a2-3)Gal(b1-4)[GalNAc(b1-4)]GlcNAc(b1-3)Gal(b1-4)GlcNAc(b1-2)[NeuAc(a2-3)Gal(b1-4)GlcNAc(b1-4)]Man(a1-3)[NeuAc(a2-6)Gal(b1-4)GlcNAc(b1-2)[NeuAc(a2-3)Gal(b1-4)GlcNAc(b1-6)]Man(a1-6)]Man(b1-4)GlcNAc(b1-4)GlcNAc'
#seq='NeuAc(a2-3)Gal(b1-4)[GalNAc(b1-4)]GlcNAc(b1-3)Gal(b1-4)GlcNAc'
sugar.sequence = seq

Logger.new(STDERR).info(sugar.branch_points.size)

#exit

sugar.extend(Renderable::Sugar)

renderer = SvgRenderer.new()
renderer.extend(CollapsedStubs)
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

my_proto = renderer.prototype_for_residue(sugar.root)
sugar.root.prototype = Document.new(my_proto.to_s).root
new_proto = sugar.root.prototype

all_gals = sugar.residue_composition.select { |r| r.name(:ic) == 'Gal' && r.parent && r.parent.name(:ic) == 'GlcNAc' }
type_i = all_gals.select { |r| r.paired_residue_position == 3 }
type_ii = all_gals.select { |r| r.paired_residue_position == 4 }
all_glcnacs = sugar.leaves.select { |r| r.name(:ic) == 'GlcNAc' && r.parent && r.parent.name(:ic) == 'Gal' }
#type_ii_glcnac = (all_glcnacs.select { |r| r.parent.paired_residue_position == 4 }) + (type_ii.collect { |r| r.parent }.select { |r| r.paired_residue_position != 6 && r.parent.name(:ic) == 'Gal' })
#type_i_glcnac = (all_glcnacs.select { |r| r.parent.paired_residue_position == 3 }) + (type_i.collect { |r| r.parent }.select { |r| r.paired_residue_position != 6 })
#branching = sugar.residue_composition.select { |r| r.name(:ic) == 'GlcNAc' && r.parent && r.parent.name(:ic) == 'Gal' && r.paired_residue_position == 6 }

sugar.callbacks << lambda { |sug_root,renderer|
  renderer.chain_background_width = 20
  renderer.chain_background_padding = 65
#  renderer.render_valid_decorations(sugar,valid_residues.uniq)
#  renderer.render_invalid_decorations(sugar,invalid_residues.uniq)
#  renderer.render_simplified_chains(sugar,[type_i+type_i_glcnac],'sugar_chain sugar_chain_type_i','#ff0000')
#  renderer.render_simplified_chains(sugar,[type_ii+type_ii_glcnac],'sugar_chain sugar_chain_type_ii','#00ff00')
#  renderer.render_simplified_chains(sugar,[branching],'sugar_chain sugar_chain_branching','#0000ff')
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

CondensedScalableLayout2.new().layout(sugar)

renderer = SvgRenderer.new()
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

@result = renderer.render(sugar)
#puts @result
end