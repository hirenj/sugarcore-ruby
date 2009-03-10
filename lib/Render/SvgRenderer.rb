require 'DebugLog'
require 'Render/AbstractRenderer'

class SvgRenderer
  include DebugLog
  include AbstractRenderer
  
  DISPLAY_ELEMENT_NS = "http://penguins.mooh.org/research/glycan-display-0.1"
  SVG_ELEMENT_NS = "http://www.w3.org/2000/svg"
  XLINK_NS = "http://www.w3.org/1999/xlink"
  
  # attr_reader :min_y,:max_x,:max_y
  attr_accessor :font_size
  
  def use_prototypes?
    @use_prototypes
  end
    
  def dont_use_prototypes
    debug("Switching off prototypes")
    @use_prototypes = false
  end
  
  # def min_y=(min_y)
  #   if @min_y == nil
  #     @min_y = min_y
  #   else
  #     if min_y < @min_y
  #       @min_y = min_y
  #     end
  #   end
  # end
  # 
  # def max_y=(max_y)
  #   if @max_y == nil
  #     @max_y = max_y
  #   else
  #     if max_y > @max_y
  #       @max_y = max_y
  #     end
  #   end
  # end
  # 
  # def max_x=(max_x)
  #   if @max_x == nil
  #     @max_x = max_x
  #   else
  #     if max_x > @max_x
  #       @max_x = max_x
  #     end
  #   end
  # end
    
  def initialise_prototypes
    throw Exception.new("Sugar is not renderable") unless sugar.kind_of? Renderable
    nil_mono = Monosaccharide.Factory(sugar.root.class,'ecdb:nil')
    nil_mono.extend(Renderable::Residue)
    [nil_mono, sugar.residue_composition].flatten.each { |res|

      res_id = res.name(:id)

      anchors = Hash.new()

      if /text:(\w+)/.match(scheme)
        group = Element.new('svg:svg')
        group.add_attributes({ 'viewBox' => '0 0 100 100' })
#        group.add_element('svg:rect', { 'x' => '0', 'y' => '0', 'width' => '100', 'height' => '100', 'style' => 'fill:#ffffff;' })
        my_name = res.name($~[1].to_sym)        
        group.add_element('svg:text', { #'x' => '50', 
                                        #'y' => '45', 
                                        'font-family' => 'Helvetica, Arial, Sans-Serif',
                                        'font-size'=> my_name.size < 5 ? '28' : '24',
                                        'text-anchor' => 'middle',
                                        'transform' => 'translate(45,60)',
                                        'style'=>'fill:#0000ff;stroke:#000000;stroke-width:0;'
                                        }
                          ).text=my_name
        prototypes[res_id] = group
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

      else
        prototypes[res_id] = XPath.first(res.raw_data_node, "disp:icon[@scheme='#{scheme}']/svg:svg", { 'disp' => DISPLAY_ELEMENT_NS, 'svg' => SVG_ELEMENT_NS })
      end
      if prototypes[res_id] == nil
        prototypes[res_id] = prototypes[nil_mono.name(:id)]
      end
      prototypes[res_id].add_namespace('svg',SVG_ELEMENT_NS)
      
      prototypes[res_id].add_attribute('width', 100)
      prototypes[res_id].add_attribute('height', 100)
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
    	doc.root.add_attribute('width', width)
    	doc.root.add_attribute('height', height)  	  
	  end
  	doc.root.add_attribute('id', sugar.name)
  	doc.root.add_namespace('svg', SVG_ELEMENT_NS)
  	doc.root.add_namespace('xlink', XLINK_NS)
    
    definitions = doc.root.add_element('svg:defs')
    
  	drawing = doc.root.add_element('svg:g')

  	sugar.underlays.each { |el|
  	  drawing.add_element(el)
  	}


  	linkages = drawing.add_element('svg:g')
  	residues = drawing.add_element('svg:g')
  	labels = drawing.add_element('svg:g')

  	sugar.overlays.each { |el|
  	  drawing.add_element(el)
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
      doc.root.add_attribute('width', (sugbox.width + padding))
      doc.root.add_attribute('height', (sugbox.height + padding))
    elsif width && width < 10
      doc.root.add_attribute('width', ((sugbox.width + padding) * width).floor)
      doc.root.add_attribute('height', ((sugbox.height + padding) * width).floor)
    end
  	doc.root.add_attribute('preserveAspectRatio', 'xMinYMin')
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
    anomer.add_attributes({ 'x' => xpos, 
                                    'y' => ypos, 
                                    'font-size'=>"#{font_size}",
                                    'font-family' => 'Helvetica,Arial,Sans',
                                    'text-anchor' => 'middle',
                                    'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                                    }
                      )
    if use_prototypes?
      anomer.add_attribute('transform',"rotate(#{angle},#{-1*linkage.position[:x2]},#{-1*residue.centre[:y]})")
    end
    res_anomer = residue.anomer
    res_anomer = res_anomer.gsub(/b/,'&#946;')
    res_anomer = res_anomer.gsub(/a/,'&#945;')
    anomer.text= residue.anomer ? (res_anomer+linkage.get_position_for(residue).to_s) : ''
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

    subst.add_attributes({  'x' => xpos, 
                            'y' => ypos, 
                            'font-size'=>"#{font_size}",
                            'font-family' => 'Helvetica,Arial,Sans',
                            'text-anchor' => 'middle',
                            'style'=>'fill:#000000;stroke:#000000;stroke-width:0pt;'
                          }
                      )

    if use_prototypes?
      subst.add_attribute('transform',"rotate(#{angle},#{-1*linkage.position[:x2]},#{-1*residue.centre[:y]})")
    end
    linkage_position = linkage.get_position_for(parent)
    subst.text = " &#8594; #{linkage_position == 0 ? '?' : linkage_position}"
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

    line.add_attribute('stroke-width',3)
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
    centre = linkage.centre
    quad = {}
    quad[:x] = linkage.position[:x1] + 50
    quad[:y] = linkage.position[:y1] + 50
    p1 = "#{-1*linkage.position[:x1]},#{-1*linkage.position[:y1]}"
    p2 = "#{-1*quad[:x]},#{-1*quad[:y]}"
    p3 = "#{-1*centre[:x]},#{-1*centre[:y]}"
    p4 = "#{-1*linkage.position[:x2]},#{-1*linkage.position[:y2]}"
    line.add_attribute('d', "M#{p1} Q#{p2} #{p3} T#{p4}")
    return line
  end

  def render_straight_link(linkage)
    line = Element.new('svg:line')
    line.add_attribute('x1',-1*linkage.position[:x1])
    line.add_attribute('y1',-1*linkage.position[:y1])
    line.add_attribute('x2',-1*linkage.position[:x2])
    line.add_attribute('y2',-1*linkage.position[:y2])
    return line
  end
  
  def render_residue(res)

    res_id = res.name(:id)

    icon = nil

    if ( prototypes[res_id] != nil )
      icon = Element.new('svg:use')
      icon.add_attribute('xlink:href' , "##{sugar.name}-proto-#{res_id}")
    end

    if ( ! self.use_prototypes? )
      icon = Document.new(prototypes[res_id].to_s).root
    end
    
    if ( res.prototype != nil )
      icon = Document.new(res.prototype.to_s).root
    end
    
    x_pos = res.dimensions[:width] + res.position[:x1]
    y_pos = res.dimensions[:height] + res.position[:y1]

    
    #icon.add_attribute('transform',"translate(#{res.position[:x1]+100},#{res.position[:y1]+100}) rotate(180)")
    if ( self.use_prototypes? )
    icon.add_attribute('x',"#{-1*x_pos}")
    icon.add_attribute('y',"#{-1*y_pos}")
    else
      icon.add_attribute('transform',"translate(#{-1*x_pos},#{-1*y_pos})")      
    end
    # self.min_y = -res.dimensions[:height]-res.position[:y1]
    # self.max_x = -res.dimensions[:width]-res.position[:x2]
    # self.max_y = -res.dimensions[:height]-res.position[:y2]
    
    icon.add_attribute('width',res.dimensions[:width])
    icon.add_attribute('height',res.dimensions[:height])

    
    if res.labels.length > 0 
      icon.add_attribute('class', res.labels.join(" "))
    end
    
    res.callbacks.each { |callback|
      callback.call(icon)
    }
    
    return icon
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
