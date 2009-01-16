require 'DebugLog'
require 'Render/AbstractRenderer'

class HtmlRenderer
  include DebugLog
  include AbstractRenderer

  def min_y=(min_y)
    if @min_y == nil
      @min_y = min_y
    else
      if min_y < @min_y
        @min_y = min_y
      end
    end
  end

  def max_y=(max_y)
    if @max_y == nil
      @max_y = max_y
    else
      if max_y > @max_y
        @max_y = max_y
      end
    end
  end

  def max_x=(max_x)
    if @max_x == nil
      @max_x = max_x
    else
      if max_x > @max_x
        @max_x = max_x
      end
    end
  end
  
  def initialise_prototypes
  end
  
  def render(sugar)
    return render_sugar(sugar)
  end
  
  def render_sugar(sugar)
  	doc = Document.new
  	doc.add_element(Element.new('div'))
  	doc.root.add_attribute('id', sugar.name)

  	sugar.overlays.each { |el|
  	  drawing.add_element(el)
  	}

  	icons = Array.new()

    sugar.residue_composition.each { |res|

      icons << render_residue(res)

      res.children.each { |child|
        doc.root.add_element(render_link(child[:link]))
#        doc.root.add_element(render_substitution(res,child[:link]))
      }
      
      #labels.add_element(render_anomer(res))
    }
    
    icons.each { |ic|
      doc.root.add_element ic
    }

    sugbox = sugar.box

    sugbox[:x1] = -1*sugbox[:x1]
    sugbox[:x2] = -1*sugbox[:x2]
    sugbox[:y1] = -1*sugbox[:y1]
    sugbox[:y2] = -1*sugbox[:y2]
    
    doc.root.add_attribute('style', "position: relative; left: #{sugbox.width}px; top: #{-1 * @min_y}px;")
    
    return doc.to_s
  end

  def render_residue(res)

    icon = Element.new('div')
    icon.text = res.name(:ic)

    styledec = "min-height: 100px; min-width: 100px; border: solid black 1px; position: absolute; left: #{-res.position[:x1]}px; top: #{-res.position[:y1]}px"
    icon.add_attribute('style', styledec)
    icon.add_attribute('pos', "#{res.position[:x1]},#{res.position[:y1]}:#{res.position[:x2]},#{res.position[:y2]}")

    self.min_y = -res.position[:y1]
    self.max_x = -res.position[:x2]
    self.max_y = -res.position[:y2]
        
    if res.labels.length > 0 
      icon.add_attribute('class', res.labels.join(" "))
    end
    
    res.callbacks.each { |callback|
      callback.call(icon)
    }
    
    return icon
  end
  
  def render_link(linkage)
    line = Element.new('img')
    if linkage.position[:y1] > linkage.position[:y2]
      position = "position: absolute; left: #{100-1*linkage.position[:x2]}px; top: #{100-1*linkage.position[:y1]}px"
    else
      position = "position: absolute; left: #{100-1*linkage.position[:x2]}px; top: #{100-1*linkage.position[:y2]}px"
    end
    line.add_attribute('width', "#{linkage.position.width}px" )
    line.add_attribute('height', "#{linkage.position.height+1}px" )
    line.add_attribute('style',position)
    line.add_attribute('src','/line.png')
    line.add_attribute('pos', "#{linkage.position[:x1]},#{linkage.position[:y1]}:#{linkage.position[:x2]},#{linkage.position[:y2]}")
    if linkage.labels.length > 0
      line.add_attribute('class', linkage.labels.join(" "))
    end

    linkage.callbacks.each { |callback|
      callback.call(line)
    }

    return line    
  end
  
end