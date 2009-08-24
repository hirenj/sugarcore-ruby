require 'DebugLog'
require 'Render/AbstractRenderer'

require 'rubygems'
require 'facets'

class Object
  def my_instance_eval(*args, &block)
    block.bind(self)[*args]
  end
end

class SvgRenderer
  include DebugLog
  include AbstractRenderer
  
  DISPLAY_ELEMENT_NS = "http://penguins.mooh.org/research/glycan-display-0.1"
  SVG_ELEMENT_NS = "http://www.w3.org/2000/svg"
  XLINK_NS = "http://www.w3.org/1999/xlink"


  CALLBACK_HIDE_ELEMENT = Proc.new { |element|
    element.add_attribute('display','none')
  }


  
  # attr_reader :min_y,:max_x,:max_y
  attr_accessor :font_size
  
  def use_prototypes?
    @use_prototypes
  end
    
  def dont_use_prototypes
    debug("Switching off prototypes")
    @use_prototypes = false
  end

  def prototype_for_residue(residue)    
    return prototypes ? prototypes[residue.name(:id)] : nil
  end

  def get_text_icon(res,anchors)
  end
  
  def initialise_prototypes
    throw Exception.new("Sugar is not renderable") unless sugar.kind_of? Renderable
    nil_mono = Monosaccharide.Factory(sugar.root.class,'ecdb:nil')
    nil_mono.extend(Renderable::Residue)
    [nil_mono, sugar.residue_composition].flatten.each { |res|

      res_id = res.name(:id)

      anchors = Hash.new()

      if ! /text:(\w+)/.match(scheme)
        prototypes[res_id] = XPath.first(res.raw_data_node, "disp:icon[@scheme='#{scheme}']/svg:svg", { 'disp' => DISPLAY_ELEMENT_NS, 'svg' => SVG_ELEMENT_NS })
      end
      if /text:(\w+)/.match(scheme) || prototypes[res_id == nil]
        # prototypes[res_id] = prototypes[nil_mono.name(:id)]
        group = Element.new('svg:svg')
        group.add_attributes({ 'viewBox' => '0 0 100 100', 'width' => '100', 'height' => '100' })
        my_name = res.name($~[1].to_sym)        
        group.add_element('svg:text', { 'x' => '0', 
                                        'y' => '0', 
                                        'font-family' => 'Helvetica, Arial, Sans-Serif',
                                        'font-size'=> my_name.size < 5 ? '28' : '24',
                                        'text-anchor' => 'middle',
                                        'transform' => 'translate(45,60)',
                                        'style'=>'fill:#0000ff;stroke:#000000;stroke-width:0;'
                                        }
                          ).text=my_name

        anchors[0] = { :x => 100, :y => 50 }
        anchors[1] = { :x => 0, :y => 50 }
        anchors[2] = { :x => 100, :y => 50 }
        anchors[3] = { :x => 100, :y => 50 }
        anchors[4] = { :x => 100, :y => 50 }
        anchors[5] = { :x => 100, :y => 50 }
        anchors[6] = { :x => 100, :y => 50 }

        XPath.each(res.raw_data_node, "./disp:icon[@scheme='text']/disp:anchor", { 'disp' => DISPLAY_ELEMENT_NS }) { |anchor|
          anchors[anchor.attribute("linkage").value().to_i] = { :x => 100 - anchor.attribute("x").value().to_i,
                                                                :y => 100 - anchor.attribute("y").value().to_i }
        }
        prototypes[res_id] = group
      end
      
      prototypes[res_id].add_namespace('svg',SVG_ELEMENT_NS)
      
      prototypes[res_id].add_attribute('width', '100')
      prototypes[res_id].add_attribute('height', '100')
      prototypes[res_id].add_attribute('viewBox', '0 0 100 100')

      XPath.each(res.raw_data_node, "./disp:icon[@scheme='#{scheme}']/disp:anchor", { 'disp' => DISPLAY_ELEMENT_NS }) { |anchor|
        anchors[anchor.attribute("linkage").value().to_i] = { :x => 100 - anchor.attribute("x").value().to_i,
                                                              :y => 100 - anchor.attribute("y").value().to_i }
      }
      if anchors.empty?
        anchors = nil_mono.offsets
      end
      res.offsets = anchors
      unless res.dimensions[:width] != 0 && res.dimensions[:height] != 0
        res.dimensions = { :width => 100, :height => 100 }
      end
    }
  end
  
  def render(sugar)
    return render_sugar(sugar)
  end

  
  def render_sugar(sugar)
  	doc = Document.new
  	doc.add_element(Element.new('svg:svg'))
  	doc.root.add_attribute('version', '1.1')
  	doc.root.add_attribute('width', '100%')
  	doc.root.add_attribute('height', '100%')
  	if (width != nil && height != nil)
    	doc.root.add_attribute('width', width.to_s)
    	doc.root.add_attribute('height', height.to_s)  	  
	  end
  	doc.root.add_namespace('svg', SVG_ELEMENT_NS)
  	doc.root.add_namespace('xlink', XLINK_NS)
    
    return doc unless sugar

  	doc.root.add_attribute('id', sugar.name)
    
    definitions = doc.root.add_element('svg:defs')

  	drawing = doc.root.add_element('svg:g')

  	underlays = drawing.add_element('svg:g')
  	linkages = drawing.add_element('svg:g')
  	residues = drawing.add_element('svg:g')
  	labels = drawing.add_element('svg:g')
  	overlays = drawing.add_element('svg:g')

    
    sugar.callbacks.each { |callback|
  	  callback.call(doc.root,self)
  	}
    
  	icons = Array.new()

    sugar.residue_composition.each { |res|

      icons << render_residue(res)

      res.children.each { |child|
        linkages.add_element(render_link(child[:link]))
        labels.add_element(render_substitution(res,child[:link]))
      }
      
      labels.add_element(render_anomer(res))
    }
    
    icons.sort_by { |icon|
      icon.get_elements('svg:text').length > 0 ? 1 : 0
    }.each { |ic|
      residues.add_element ic
    }
    
    if ( self.use_prototypes? )    
      prototypes.each { |key,val|
        proto_copy = Document.new(val.to_s).root
        proto_copy.add_attribute('id', "#{sugar.name}-proto-#{key}")
        proto_copy.add_attribute('class', "#{key}")
        definitions.add_element(proto_copy)
      }
    end
    sugbox = sugar.box

    sugbox[:x1] = -1*sugbox[:x1]
    sugbox[:x2] = -1*sugbox[:x2]
    sugbox[:y1] = -1*sugbox[:y1]
    sugbox[:y2] = -1*sugbox[:y2]
            
  	doc.root.add_attribute('viewBox', "#{sugbox[:x2] - padding} #{sugbox[:y2] - padding } #{sugbox.width + 2*padding} #{sugbox.height + 2*padding}")
  	  	  	
    if width == :auto
      doc.root.add_attribute('width', (sugbox.width + padding).to_s)
      doc.root.add_attribute('height', (sugbox.height + padding).to_s)
    elsif width && width.to_i < 10
      doc.root.add_attribute('width', ((sugbox.width + padding) * width).floor.to_s)
      doc.root.add_attribute('height', ((sugbox.height + padding) * width).floor.to_s)
    end
  	doc.root.add_attribute('preserveAspectRatio', 'xMinYMin')

  	sugar.underlays.each { |el|
  	  underlays.add_element(el)
  	}

  	sugar.overlays.each { |el|
  	  overlays.add_element(el)
  	}

  	
    return doc
  end

  def render_anomer(residue)
    return Element.new('svg:text') if scheme == 'oxford'

    linkage = residue.linkage_at_position
    return Element.new('svg:text') unless linkage

    xpos = nil
    ypos = nil
    
    
    delta_x = (linkage.position[:x1] - linkage.position[:x2]).abs

    if false && delta_x < 5
      xpos = -1 * (linkage.position[:x1] - 25 )
      if linkage.position[:y1] > linkage.position[:y2]
        ypos = residue.position[:y1] - 25
      else
        ypos = residue.position[:y2] + 25
      end
      ypos *= -1
    else
      xpos = -1 * (residue.position[:x1] - 25)
      if linkage.position[:y1] < linkage.position[:y2]
        ypos = -1 * (residue.position[:y2] - 25)
      else
        ypos = -1 * (residue.position[:y1] + 15)
      end
    end
  
    tan_x = (linkage.position[:x1] - linkage.position[:x2]).to_f
    tan_y = (linkage.position[:y1] - linkage.position[:y2]).to_f

    angle = 0
    
    if tan_x != 0
      angle = (180 / Math::PI ) * Math.atan( tan_y / tan_x )
    else
      if tan_y > 0
        angle = 90
      else
        angle = -90
      end
    end
    
    
    anomer = Element.new('svg:text',nil,{:raw => :all})
    anomer.add_attributes({ 'x' => xpos.to_s, 
                                    'y' => ypos.to_s, 
                                    'font-size'=>"#{font_size}",
                                    'font-family' => 'Helvetica,Arial,Sans',
                                    'text-anchor' => 'middle',
                                    'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                                    }
                      )
    if use_prototypes?
      anomer.add_attribute('transform',"rotate(#{angle},#{-1*linkage.position[:x2]},#{-1*residue.center[:y]})")
    end
    
    res_anomer = residue.anomer
    res_anomer = res_anomer.gsub(/b/,'&#946;')
    res_anomer = res_anomer.gsub(/a/,'&#945;')
    anomer.text= residue.anomer ? (res_anomer+linkage.get_position_for(residue).to_s) : ''

    linkage.label_callbacks.each { |callback|
      callback.call(anomer)
    }

    return anomer    
  end

  def render_substitution(parent,linkage)
    return Element.new('svg:text') if scheme == 'oxford'
    residue = linkage.get_paired_residue(parent)

    xpos = nil
    ypos = nil
    
    delta_x = (linkage.position[:x1] - linkage.position[:x2]).abs
    # Disable shifting the position for stub residues
    if false && delta_x < 5
      xpos = -1 * (residue.position[:x1] - font_size )
      if linkage.position[:y1] > linkage.position[:y2]
        ypos = -1 * (residue.position[:y1] - 25)
      else
        ypos = -1 * (residue.position[:y2] + 25)
      end
    else
      xpos = -1 * (residue.position[:x1] - 15 - (2 * font_size) )
      if linkage.position[:y1] < linkage.position[:y2]
        ypos = -1 * (residue.position[:y2] - 25)
      else
        ypos = -1 * (residue.position[:y1] + 15)
      end
    end
    subst = Element.new('svg:text',nil,{:raw => :all})
    
    tan_x = (linkage.position[:x1] - linkage.position[:x2]).to_f
    tan_y = (linkage.position[:y1] - linkage.position[:y2]).to_f

    angle = 0
    
    if tan_x != 0
      angle = (180 / Math::PI ) * Math.atan( tan_y / tan_x )
    else
      if tan_y > 0
        angle = 90
      else
        angle = -90
      end
    end

    subst.add_attributes({  'x' => xpos.to_s, 
                            'y' => ypos.to_s, 
                            'font-size'=>"#{font_size}",
                            'font-family' => 'Helvetica,Arial,Sans',
                            'text-anchor' => 'middle',
                            'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                          }
                      )

    if use_prototypes?
      subst.add_attribute('transform',"rotate(#{angle},#{-1*linkage.position[:x2]},#{-1*residue.center[:y]})")
    end
    linkage_position = linkage.get_position_for(parent)
    subst.text = " &#8594; #{linkage_position == 0 ? '?' : linkage_position}"

    linkage.label_callbacks.each { |callback|
      callback.call(subst)
    }

    return subst
  end


  # 
  # def render_substitution(parent,linkage)
  #   xpos = -75 - 1 * (linkage.position[:x1])
  #   #ypos = -25 - (linkage.position[:y1]-linkage.position[:y2])
  #   gradient = linkage.position[:y2] - linkage.position[:y1]
  #   if (gradient < 5 && gradient > -5 )
  #     gradient = 20
  #   end
  #   ypos =  - 1 * ( linkage.position[:y1] + (gradient / 2) )
  #   anomer = Element.new('svg:text')
  #   anomer.add_attributes({ 'x' => xpos, 
  #                                   'y' => ypos, 
  #                                   'font-size'=>'25',
  #                                   'style'=>'fill:#000000;stroke:#000000;stroke-width:1;'
  #                                   }
  #                     )
  #   anomer.text= linkage.get_position_for(parent)
  #   return anomer    
  # end

  def render_link(linkage)
    if (scheme == 'oxford' && linkage.is_unknown? )
      line = render_curvy_link(linkage)      
    else
      line = render_straight_link(linkage)
    end

    line.add_attribute('stroke-width','3')
    line.add_attribute('stroke','black')
    line.add_attribute('fill','none')
    if (scheme == 'oxford' && linkage.reducing_end_substituted_residue.anomer == 'a')
      line.add_attribute('stroke-dasharray', '6,6')
    end
    
    if linkage.labels.length > 0
      line.add_attribute('class', linkage.labels.join(" "))
    end
    linkage.callbacks.each { |callback|
      callback.call(line)
    }
    return line    
  end

  def render_curvy_link(linkage)
    line = Element.new('svg:path')
    center = linkage.center
    quad = {}
    quad[:x] = linkage.position[:x1] + 50
    quad[:y] = linkage.position[:y1] + 50
    p1 = "#{-1*linkage.position[:x1]},#{-1*linkage.position[:y1]}"
    p2 = "#{-1*quad[:x]},#{-1*quad[:y]}"
    p3 = "#{-1*center[:x]},#{-1*center[:y]}"
    p4 = "#{-1*linkage.position[:x2]},#{-1*linkage.position[:y2]}"
    line.add_attribute('d', "M#{p1} Q#{p2} #{p3} T#{p4}")
    return line
  end

  def render_straight_link(linkage)
    line = Element.new('svg:line')
    line.add_attribute('x1',(-1*linkage.position[:x1]).to_s)
    line.add_attribute('y1',(-1*linkage.position[:y1]).to_s)
    line.add_attribute('x2',(-1*linkage.position[:x2]).to_s)
    line.add_attribute('y2',(-1*linkage.position[:y2]).to_s)
    return line
  end
  
  def render_residue(res)

    res_id = res.name(:id)

    icon = nil

    if ( false && prototypes[res_id] != nil )
      icon = Element.new('svg:use')
      icon.add_attribute('xlink:href' , "##{sugar.name}-proto-#{res_id}")
    end

    if ( true || ! self.use_prototypes? )
      icon = Document.new(prototypes[res_id].to_s).root
    end
    
    if ( res.prototype != nil )
      icon = Document.new(res.prototype.to_s).root
    end
    
    x_pos = res.dimensions[:width] + res.position[:x1]
    y_pos = res.dimensions[:height] + res.position[:y1]

    
    icon.add_attribute('x',"#{-1*x_pos}")
    icon.add_attribute('y',"#{-1*y_pos}")
    icon.add_attribute('transform',"translate(#{-1*x_pos},#{-1*y_pos})")      
    
    icon.add_attribute('width',res.dimensions[:width].to_s)
    icon.add_attribute('height',res.dimensions[:height].to_s)

    
    if res.labels.length > 0 
      icon.add_attribute('class', res.labels.join(" "))
    end
    
    res.callbacks.each { |callback|
      self.my_instance_eval(icon,&callback)
    }
    
    return icon
  end
  
  attr_accessor :chain_background_width
  attr_accessor :chain_background_padding
  
  def render_chains(sugar,chains,chain_class)
    
    return unless chains
    
    chains_container = Element.new('svg:g')
    sugar.underlays << chains_container
    chains_container.add_attribute('class',chain_class)
        
    chains.each { |chain|
      chain_container = Element.new('svg:g')
      chain.reverse.each { |chain_el|
        render_chain_residue(chain_container,chain_el)
      }
      chains_container.add_element(chain_container)
    }
    
  end  

  def render_simplified_chains(sugar,chains,chain_class,colour=nil)
    chains_container = Element.new('svg:g')
    sugar.underlays << chains_container
    chains_container.add_attribute('class',chain_class)
        
    chains.each { |chain|
      chain_container = Element.new('svg:g')
      chain.reverse.each { |chain_el|
        render_simple_chain_residue(chain_container,chain_el,colour)
      }
      chains_container.add_element(chain_container)
    }
    
  end  

  
  def render_valid_decorations(sugar,decorations)

    return unless decorations
    
    decorations_container = Element.new('svg:g')
    decorations_container.add_attribute('class','sugar_decorations valid_sugar_decorations')

    sugar.underlays << decorations_container      
    decorations.each { |residue|
      render_decoration(decorations_container,residue,'#ccccff')
    }
  end

  def render_invalid_decorations(sugar,decorations)
    
    return unless decorations 
    
    decorations_container = Element.new('svg:g')
    decorations_container.add_attribute('class','sugar_decorations invalid_sugar_decorations')
    sugar.underlays << decorations_container      
    decorations.each { |residue|
      render_decoration(decorations_container,residue,'#ffdddd')
    }
  end
  
  def render_decoration(container_el, residue,colour)
    return unless residue
    residue.callbacks.push( callback_make_residue_background(container_el,residue,chain_background_width+chain_background_padding,colour,colour) )    
    linkage = residue.linkage_at_position

    return unless linkage
    linkage.callbacks.push( callback_make_linkage_background(container_el,residue.linkage_at_position,chain_background_width,colour,colour) )
  end

  def render_chain_residue(container_el,residue,colour=nil)
    render_chain_residue_node(container_el,residue,colour)
    render_chain_linkage(container_el,residue.linkage_at_position,colour)
  end
  
  def render_simple_chain_residue(container_el,residue,colour=nil)
    render_chain_residue(container_el,residue,colour)
    if residue.linkage_at_position
      residue.linkage_at_position.label_callbacks.push(callback_hide_element)
      residue.linkage_at_position.callbacks.push(callback_hide_element)
    end
  end
  
  def render_chain_residue_node(container_el,residue,colour='#ddffdd')
    return unless residue
    residue.callbacks.push( callback_make_residue_background(container_el,residue,chain_background_width+chain_background_padding,colour,colour) )
  end
  
  def render_chain_linkage(container_el,linkage,colour='#ddffdd')
    return unless linkage
    linkage.callbacks.push( callback_make_linkage_background(container_el,linkage,chain_background_width,colour,colour) )    
  end
  
  def render_text_residue_label(sugar,residue,label,position=nil)
    container = Element.new('svg:g')
    container.add_attribute('class','branch_point_label')
    sugar.overlays << container
    residue.callbacks.push( callback_make_object_badge(container,residue,label,0.5,(position || :top_right),'#9999ff'))
  end
  
  def callback_make_object_badge(container_element,sugar_object,label,node_ratio,corner,stroke_colour)
    lambda { |element|
    cx = sugar_object.position[:x1]
    cy = sugar_object.position[:y2]
    case corner
    when :top_left
      cx = sugar_object.position[:x2]
      cy = sugar_object.position[:y2]
    when :bottom_left
      cx = sugar_object.position[:x2]
      cy = sugar_object.position[:y1]
    when :bottom_right
      cx = sugar_object.position[:x1]
      cy = sugar_object.position[:y1]
    when :center
      cx = sugar_object.center[:x]
      cy = sugar_object.center[:y]
    end
    badge = Element.new('svg:g')

    badge_width = node_ratio * sugar_object.width.to_f
    
    back_circle_shape = Element.new('svg:circle')
    back_circle_shape.add_attributes({'cx' => "#{-1*cx}", 'cy' => "#{-1*cy}", 'r' =>  "#{badge_width / 2}", 'stroke' => stroke_colour, 'stroke-width' => '5', 'fill' => '#ffffff', 'fill-opacity' => '1', 'stroke-opacity' => '1' })
    badge.add_element(back_circle_shape)
    
    text = Element.new('svg:text')
    text.add_attributes({ 'x' => "#{-1*(cx)}", 'y' => "#{-1*(cy)}", 'text-anchor' => 'middle', 'dominant-baseline' => 'middle', 'width' => "#{badge_width}", 'font-size' => "#{badge_width - 15}", 'height' => "#{badge_width - 15}" })
    text.text = label
    badge.add_element(text)
    
    container_element.add_element(badge)    
    }
  end
  
  def callback_make_linkage_background(container_element,linkage,linkage_padding,fill_colour,stroke_colour)
    Proc.new { |element|
      x1 = -1*linkage.first_residue.center[:x]
      y1 = -1*linkage.first_residue.center[:y]
      x2 = -1*linkage.second_residue.center[:x]
      y2 = -1*linkage.second_residue.center[:y]
      link_width = (x2-x1).abs
      link_height = (y2-y1).abs
      link_length = Math.hypot(link_width,link_height)
      deltax = -1 * (linkage_padding * link_height / link_length).to_i
      deltay = (linkage_padding * link_width / link_length).to_i
      points = ""
      if y2 < y1
        points = "#{x1-deltax},#{y1+deltay} #{x2-deltax},#{y2+deltay} #{x2+deltax},#{y2-deltay} #{x1+deltax},#{y1-deltay}"
      else
        points = "#{x1+deltax},#{y1+deltay} #{x2+deltax},#{y2+deltay} #{x2-deltax},#{y2-deltay} #{x1-deltax},#{y1-deltay}"              
      end

      back = Element.new('svg:polygon')
      back.add_attributes({'points' => points, 'class' => 'sugar_chain_linkage_background sugar_chain_background', 'stroke'=>fill_colour,'fill'=>stroke_colour,'stroke-width'=>'1.0'})
      container_element.add_element(back)      
    }
  end
  
  def callback_make_residue_background(container_element,residue,radius,fill_colour,stroke_colour)
    Proc.new { |element|
      cx = -1*residue.center[:x]
      cy = -1*residue.center[:y]

      back = Element.new('svg:circle')
      back.add_attributes({'cx' => cx.to_s, 'cy' => cy.to_s, 'class' => 'sugar_chain_residue_background sugar_chain_background','r' => radius.to_s, 'fill'=> fill_colour,'stroke' => stroke_colour, 'stroke-width' => '1.0' })
      container_element.add_element(back)
    }
  end
  
  def callback_make_element_label(container_element,sugar_el,content,border_colour,draw_cross=false)
    lambda { |element|
      bad_linkage = Element.new('svg:g')
      bad_linkage.add_attributes({'id' => "label-#{sugar_el.object_id}" })
      
      x1 = -1*(sugar_el.center[:x] - 20)
      y1 = -1*(sugar_el.center[:y] - 20)
      x2 = -1*(sugar_el.center[:x] + 20)
      y2 = -1*(sugar_el.center[:y] + 20)
      x3 = -1*(sugar_el.center[:x] - 20)
      y3 = -1*(sugar_el.center[:y] + 20)
      x4 = -1*(sugar_el.center[:x] + 20)
      y4 = -1*(sugar_el.center[:y] - 20)

      if draw_cross
        cross = Element.new('svg:line')
        cross.add_attributes({'class' => 'bad_link', 'x1' => x1.to_s, 'x2' => x2.to_s, 'y1' => y1.to_s, 'y2' => y2.to_s, 'stroke'=>border_colour,'stroke-width'=>'5.0'})
        cross_inv = Element.new('svg:line')
        cross_inv.add_attributes({'class' => 'bad_link', 'x1' => x3.to_s, 'x2' => x4.to_s, 'y1' => y3.to_s, 'y2' => y4.to_s, 'stroke'=>border_colour,'stroke-width'=>'5.0'})
      end
      
      x1 = -1*(sugar_el.center[:x] + 110)
      y1 = -1*(sugar_el.center[:y] - 10)

      max_height = content.size * 30 + 25
      
      back_el = Element.new('svg:rect')
      back_el.add_attributes({'x' => x1.to_s, 'y' => y1.to_s, 'rx' => '10', 'ry' => '10', 'width' => '220', 'height' => max_height.to_s, 'stroke' => border_colour, 'stroke-width' => '5px', 'fill' => '#ffffff', 'fill-opacity' => '1', 'stroke-opacity' => '0.5' })
      back_circle = Element.new('svg:svg')
      
      cross_mark_height = content.size == 0 ? 90 : 58
      
      back_circle.add_attributes('viewBox' =>"0 0 90 #{cross_mark_height}", 'height' => cross_mark_height, 'width' => '90', 'x' => "#{-1*(sugar_el.center[:x]+45)}", 'y' => "#{-1*(sugar_el.center[:y]+45)}")
      back_circle_shape = Element.new('svg:circle')
      back_circle_shape.add_attributes({'cx' => '45', 'cy' => '45', 'r' => '40', 'stroke' => border_colour, 'stroke-width' => '5px', 'fill' => '#ffffff', 'fill-opacity' => '1', 'stroke-opacity' => '0.5' })
      back_circle.add_element(back_circle_shape)
      text = Element.new('svg:text')
      text.add_attributes({ 'x' => x1.to_s, 'y' => "#{y1+10}", 'width' => '210', 'font-size' => '30', 'height' => "#{max_height}" })
      content.each { |content_line|
        li = Element.new('svg:tspan')
        li.add_attributes({'x' => "#{x1+20}", 'dy' => '30' })
        li.text = content_line
        text.add_element(li)
      }
      bad_linkage.add_element(back_el) if content.size > 0
      bad_linkage.add_element(back_circle)        
      bad_linkage.add_element(text) if content.size > 0
      if draw_cross
        bad_linkage.add_element(cross)
        bad_linkage.add_element(cross_inv)
      end
      container_element.add_element(bad_linkage)
      
      drop_shadow = Element.new('svg:g')
      drop_shadow.add_attribute('filter','url(#drop-shadow)')
      shadow = Element.new('svg:use')
      shadow.add_attribute('xlink:href' , "#label-#{sugar_el.object_id}")
      drop_shadow.add_element(shadow)
      container_element.add_element(drop_shadow)
    }
  end
  
  def callback_hide_element
    CALLBACK_HIDE_ELEMENT
  end
  
  protected :render_sugar, :render_link, :render_residue
  
  def initialize()
    @scheme = "boston"
    @prototypes = Hash.new()
    @use_prototypes = true
    @padding = 0
    @font_size = 25
  end
end
