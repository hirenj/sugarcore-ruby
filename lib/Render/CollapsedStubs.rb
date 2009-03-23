require 'rubygems'
require 'color'

module CollapsedStubs

  def render_sugar(sugar)
    setup_stubs(sugar)
    super(sugar)
  end
  
  def setup_stubs(sugar)
    setup_hit_desaturation(sugar)
    setup_fucosylation(sugar)
    setup_sulfation(sugar)
    setup_sialylation(sugar)
    setup_abo_epitopes(sugar)
    setup_sda_epitopes(sugar)
  end

  def setup_hit_desaturation(sugar)
    max_hits = sugar.residue_composition.collect { |res| res.respond_to?(:hits) ? res.hits : 1 }.max
    sugar.residue_composition.each { |res|      
      default_proto = self.prototype_for_residue(res)
      res.prototype = Document.new(default_proto.to_s).root
      res_saturation = res.respond_to?(:hits) ? res.hits.to_f : 1.0
      res_saturation /= max_hits
      saturation_min = ['NeuAc','Fuc'].include?(res.name(:ic)) ? 0.8 : 0.3
      res_saturation *= (1 - saturation_min)
      res_saturation += saturation_min
      a_fill = nil
      res.prototype.root.each { |proto_el|
        next unless proto_el.is_a?(REXML::Element)
        convert_fill(proto_el)
        curr_fill = proto_el.attribute('fill')
        next unless curr_fill
        hsl = Color::RGB.from_html(curr_fill.value).to_hsl
        hsl.s = res_saturation
        brightness = hsl.l
        brightness += (1 - brightness)*(1-res_saturation)
        hsl.l = brightness
        proto_el.add_attribute('fill',hsl.html)
        a_fill ||= hsl.html
      }
      res.prototype.root.add_attribute('fill',a_fill)
    }
  end

  def convert_fill(element)
    style_dec = element.attribute('style').value
    element.add_attribute('style',style_dec.gsub(/fill\s*:\s*#(......)\s*;*/,''))
    new_fill = $1
    element.add_attribute('fill',new_fill) if new_fill
  end

  def setup_sda_epitopes(sugar)
    sda_overlay = Element.new('svg:g')
    sugar.overlays << sda_overlay
    sugar.residue_composition.select { |r| ['GalNAc'].include?(r.name(:ic)) && r.anomer == 'b' && r.paired_residue_position == 4 && r.parent.name(:ic) == 'Gal' }.each { |r|
      gal_parent = r.parent
      r.callbacks.push(callback_hide_element)
      r.linkage_at_position.callbacks.push(callback_hide_element)
      r.linkage_at_position.label_callbacks.push(callback_hide_element)
      gal_parent.callbacks.push(
        lambda { |element|
          cx = -1*gal_parent.centre[:x] + 10
          cy = -1*gal_parent.centre[:y] + 10
          text = Element.new('svg:text')
          text.text = 'Sdα'
          text.add_attributes({ 'x' => cx, 
                                          'y' => cy, 
                                          'font-size'=>"20",
                                          'font-family' => 'Helvetica,Arial,Sans',
                                          'text-anchor' => 'middle',
                                          'textLength' => ((gal_parent.width / 2)-10),
                                          'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                                          })
          sda_overlay.add_element(text)
        }
      )
    }
  end

  def setup_abo_epitopes(sugar)
    abo_overlay = Element.new('svg:g')
    sugar.overlays << abo_overlay
    sugar.residue_composition.select { |r| ['Gal','GalNAc'].include?(r.name(:ic)) && r.anomer == 'a' && r.paired_residue_position == 3}.each { |r|
      gal_parent = r.parent
      r.callbacks.push(callback_hide_element)
      r.linkage_at_position.callbacks.push(callback_hide_element)
      r.linkage_at_position.label_callbacks.push(callback_hide_element)
      gal_parent.callbacks.push(
        lambda { |element|
          cx = -1*gal_parent.centre[:x] - 5
          cy = -1*gal_parent.centre[:y] - 5
          if r.name(:ic) == 'GalNAc'
            cy += 40
          end
          text = Element.new('svg:text')
          text.text = (r.name(:ic) == 'Gal') ? 'A' : 'B'
          text.add_attributes({ 'x' => cx, 
                                          'y' => cy, 
                                          'font-size'=>"30",
                                          'font-family' => 'Helvetica,Arial,Sans',
                                          'text-anchor' => 'middle',
                                          'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                                          })
          abo_overlay.add_element(text)
        }
      )
    }
  end

  def setup_fucosylation(sugar)
    halo_element = Element.new('svg:g')
    sugar.overlays << halo_element
    sugar.residue_composition.select { |r| r.name(:ic) == 'Fuc' }.each { |fuc|
      next if fuc.parent == sugar.root
      fuc.callbacks.push(callback_hide_element)
      fuc.linkage_at_position.callbacks.push(callback_hide_element)
      fuc.linkage_at_position.label_callbacks.push(callback_hide_element)
      colour = fuc.prototype.root.attribute('fill').value || '#ff0000'
      hits = fuc.respond_to?(:hits) ? 0.1+((fuc.hits.to_f / fuc.parent.hits.to_f)*0.9) : 0.5
      start_angle = 0
      arc_angle = Math::PI / 3
      if fuc.paired_residue_position == 2
        start_angle = Math::PI*5/6
      end
      if fuc.paired_residue_position == 4
        start_angle = -1*Math::PI/6  
      end
      if fuc.paired_residue_position == 6
        start_angle = -1*Math::PI/6  
      end
      if fuc.paired_residue_position == 3
        start_angle = Math::PI*0.25
        arc_angle = Math::PI*0.5
      end      
#      fuc.callbacks.push(callback_make_halo(halo_element,fuc.parent,'none',-1,1.0,start_angle,arc_angle,colour))
      fuc.callbacks.push(callback_make_halo(halo_element,fuc.parent,colour,-1,hits,start_angle,arc_angle))
    }
  end


  def setup_sialylation(sugar)
    halo_element = Element.new('svg:g')
    sugar.overlays << halo_element
    neuacs = sugar.residue_composition.select { |r| r.name(:ic) == 'NeuAc' }
    neuacs.each { |neuac|
      neuac.callbacks.push(callback_hide_element)
      neuac.linkage_at_position.callbacks.push(callback_hide_element)
      neuac.linkage_at_position.label_callbacks.push(callback_hide_element)
      colour = neuac.prototype.root.attribute('fill').value || '#ff00ff'
      hits = neuac.respond_to?(:hits) ? 0.0+((neuac.hits.to_f / neuac.parent.hits.to_f)*1.0) : 0.5
      start_angle = 0
      arc_angle = Math::PI / 3
      if neuac.paired_residue_position == 3
        start_angle = Math::PI
      end
      if neuac.paired_residue_position == 6
        start_angle = -1*Math::PI/3
      end
      neuac.callbacks.push(callback_make_halo(halo_element,neuac.parent,'#ffffff',1,0.5,start_angle,arc_angle,'#999999'))
      neuac.callbacks.push(callback_make_halo(halo_element,neuac.parent,colour,1,hits*0.5,start_angle,arc_angle))
    }
  end  

  def setup_sulfation(sugar)
    halo_element = Element.new('svg:g')
    sugar.overlays << halo_element
    neuacs = sugar.residue_composition.select { |r| r.name(:ic) == 'HSO3' }
    neuacs.each { |neuac|
      neuac.callbacks.push(callback_hide_element)
      neuac.linkage_at_position.callbacks.push(callback_hide_element)
      neuac.linkage_at_position.label_callbacks.push(callback_hide_element)
      colour = neuac.prototype.root.attribute('fill').value || '#0000ff'
      hits = neuac.respond_to?(:hits) ? 0.3+((neuac.hits.to_f / neuac.parent.hits.to_f)*0.6) : 0.5
      arc_angle = Math::PI / 3
      start_angle = Math::PI*1/3
      neuac.callbacks.push(callback_make_halo(halo_element,neuac.parent,'#ffffff',1,0.5,start_angle,arc_angle,colour))
      neuac.callbacks.push(callback_make_halo(halo_element,neuac.parent,colour,1,0.5*hits,start_angle,arc_angle))
    }
  end  

    
  def callback_make_halo(parent_element,rendered_object,colour,inner_radius,radius,start_angle,arc_angle,border=nil)

    Proc.new { |element|
      cx = -1*rendered_object.centre[:x]
      cy = -1*rendered_object.centre[:y]

      actual_radius = Math.sqrt(2*((rendered_object.dimensions[:width]*0.5)**2))

      minor_radius = actual_radius+inner_radius
      major_radius = minor_radius+radius*actual_radius

      if inner_radius < 0
        major_radius = minor_radius
        minor_radius = major_radius - radius*major_radius
        debug("On #{rendered_object.dimensions[:width]} with hits #{radius} Major and minor radius #{major_radius} #{minor_radius} #{Math.sqrt(2*((rendered_object.dimensions[:width]*0.5)**2))}")
      end


      major_arc_start_x = cx - major_radius * Math.sin(start_angle)
      major_arc_start_y = cy - major_radius * Math.cos(start_angle)

      major_arc_end_x = cx - major_radius * Math.sin(start_angle+arc_angle)
      major_arc_end_y = cy - major_radius * Math.cos(start_angle+arc_angle)

      minor_arc_start_x = cx - minor_radius * Math.sin(start_angle+arc_angle)
      minor_arc_start_y = cy - minor_radius * Math.cos(start_angle+arc_angle)

      minor_arc_end_x = cx - minor_radius * Math.sin(start_angle)
      minor_arc_end_y = cy - minor_radius * Math.cos(start_angle)

      d = "M#{major_arc_start_x},#{major_arc_start_y} A#{major_radius},#{major_radius} 0 0,0 #{major_arc_end_x},#{major_arc_end_y} L#{minor_arc_start_x},#{minor_arc_start_y} A#{minor_radius},#{minor_radius} 0 0,1 #{minor_arc_end_x},#{minor_arc_end_y} Z"

      halo = Element.new('svg:path')
      halo.add_attributes({'d' => d,
                           'fill' => colour,
                           'opacity' => '0.8',
                           })

      if border != nil
        halo.add_attributes({ 'stroke' => border, 'stroke-width' => '2' })
      end
                          
      parent_element.add_element(halo)
    }
  end

end