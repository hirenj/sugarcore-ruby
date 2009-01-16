#!/usr/bin/env ruby
#
#  Created by Hiren Joshi on 2007-10-10.
#  Copyright (c) 2007. All rights reserved.

$:.push('lib')

require 'Sugar'
require 'Sugar/IO/CondensedIupac'
require 'Sugar/IO/GlycoCT'
require 'Sugar/IO/Glyde'
require 'SugarException'
require 'Render/Renderable'
require 'Render/CondensedLayout'
require 'Render/GridLayout'
require 'Render/SvgRenderer'
require 'Render/HtmlTextRenderer'

Monosaccharide.Load_Definitions("data/dictionary.xml")
NamespacedMonosaccharide.Default_Namespace = :ecdb

sugar = Sugar.new()
sugar.extend(Sugar::IO::CondensedIupac::Builder)
sugar.input_namespace = :ic
sugar.extend(Sugar::IO::GlycoCT::Writer)
sugar.sequence="Man(a1-3)[Man(a1-6)]Man(b1-4)GlcNAc(b1-4)[Fuc(a1-6)]GlcNAc"
sugar.extend(Renderable::Sugar)
CondensedLayout.new().layout(sugar)

renderer = SvgRenderer.new()
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

@result = renderer.render(sugar)
puts @result
0.times do 
sugar.sequence='Gal(b1-4)GlcNAc(b1-4)GlcNAc'
sugar.extend(Renderable::Sugar)

CondensedLayout.new().layout(sugar)

renderer = SvgRenderer.new()
renderer.sugar = sugar
renderer.scheme = 'boston'
renderer.initialise_prototypes()

@result = renderer.render(sugar)
#puts @result
end